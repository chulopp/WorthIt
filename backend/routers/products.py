"""
routers/products.py
Product endpoints, including image upload to Supabase Storage.
"""

from fastapi import APIRouter, Depends, File, HTTPException, Query, UploadFile
from typing import Optional

from core.categories import OFFICIAL_CATEGORIES
from core.security import get_current_user
from models.products import (
    ProductDetailData,
    ProductDetailResponse,
    ProductPricePoint,
    ProductSearchResponse,
    ProductSummary,
)
from models.response import (
    PriceHistoryItem,
    ProductImageData,
    ProductImageResponse,
    ProductPriceHistoryResponse,
)
from utils.supabase_client import (
    get_product,
    get_product_price_history,
    get_user,
    latest_prices_by_product,
    list_products,
    search_products,
    upload_product_image,
)

router = APIRouter(prefix="/v1/products", tags=["Products"])

ALLOWED_IMAGE_TYPES = {"image/jpeg", "image/png", "image/webp", "image/gif"}
MAX_IMAGE_BYTES = 5 * 1024 * 1024


def _product_summaries(products: list[dict]) -> list[ProductSummary]:
    latest_prices = latest_prices_by_product([product["id"] for product in products])
    return [
        ProductSummary(
            id=product["id"],
            name=product["name"],
            image_url=product.get("image_url"),
            category=product.get("category"),
            brand=product.get("brand"),
            current_price=latest_prices.get(product["id"]),
        )
        for product in products
    ]


def _validate_category(category: str | None) -> str | None:
    if not category:
        return None
    if category not in OFFICIAL_CATEGORIES:
        raise HTTPException(
            status_code=422,
            detail={
                "code": "INVALID_CATEGORY",
                "message": "Kategori tidak tersedia.",
                "suggestion": "Gunakan salah satu dari 7 kategori resmi WorthIt.",
            },
        )
    return category


@router.get(
    "",
    response_model=ProductSearchResponse,
    summary="List Products",
    description="List katalog produk tanpa keyword dummy, opsional difilter kategori.",
)
async def list_product_catalog(
    category: Optional[str] = Query(default=None, description="Salah satu dari 7 kategori resmi."),
    limit: int = Query(default=30, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
):
    products = list_products(
        category=_validate_category(category),
        limit=limit,
        offset=offset,
    )
    return ProductSearchResponse(data=_product_summaries(products))


@router.get(
    "/search",
    response_model=ProductSearchResponse,
    summary="Search Products",
    description="Cari produk berdasarkan nama untuk Bottom Sheet/search bar.",
)
async def search_product_catalog(
    keyword: Optional[str] = Query(default=None, min_length=1, description="String pencarian produk."),
    q: Optional[str] = Query(default=None, min_length=1, include_in_schema=False),
    category: Optional[str] = Query(default=None, description="Salah satu dari 7 kategori resmi."),
    limit: int = Query(default=20, ge=1, le=100),
):
    search_keyword = keyword or q
    if not search_keyword:
        raise HTTPException(
            status_code=422,
            detail={
                "code": "INVALID_INPUT",
                "message": "Query parameter keyword wajib diisi.",
                "suggestion": "Gunakan /v1/products/search?keyword=nama_produk.",
            },
        )

    products = search_products(
        q=search_keyword,
        category=_validate_category(category),
        limit=limit,
    )
    return ProductSearchResponse(data=_product_summaries(products))


@router.get(
    "/{product_id}",
    response_model=ProductDetailResponse,
    summary="Product Detail",
    description="Ambil detail produk beserta riwayat harga untuk line chart Bottom Sheet.",
)
async def get_product_detail(product_id: str):
    product = get_product(product_id)
    if not product:
        raise HTTPException(
            status_code=404,
            detail={
                "code": "PRODUCT_NOT_FOUND",
                "message": "Produk tidak ditemukan.",
                "suggestion": "Pastikan product_id berasal dari tabel products.",
            },
        )
    history = get_product_price_history(product_id)
    return ProductDetailResponse(
        data=ProductDetailData(
            id=product["id"],
            name=product["name"],
            image_url=product.get("image_url"),
            category=product.get("category"),
            brand=product.get("brand"),
            base_weight_gram=float(product.get("base_weight_gram") or 0),
            history=[
                ProductPricePoint(
                    month=str(item.get("recorded_at", "")),
                    price=int(round(float(item.get("price") or 0))),
                )
                for item in history
            ],
        )
    )


@router.get(
    "/{product_id}/price-history",
    response_model=ProductPriceHistoryResponse,
    summary="Product Price History",
    description="Ambil riwayat harga produk, diurutkan berdasarkan recorded_at ascending.",
)
async def get_product_history(
    product_id: str,
    user_id: str = Depends(get_current_user),
):
    if not get_product(product_id):
        raise HTTPException(
            status_code=404,
            detail={
                "code": "PRODUCT_NOT_FOUND",
                "message": "Produk tidak ditemukan.",
                "suggestion": "Pastikan product_id berasal dari tabel products.",
            },
        )

    history = get_product_price_history(product_id)
    return ProductPriceHistoryResponse(data=[PriceHistoryItem(**item) for item in history])


@router.post(
    "/{product_id}/image",
    response_model=ProductImageResponse,
    summary="Upload Product Image",
    description=(
        "Upload gambar produk ke Supabase Storage, lalu simpan public URL "
        "ke kolom products.image_url."
    ),
)
async def upload_image(
    product_id: str,
    file: UploadFile = File(..., description="Image file: JPG, PNG, WebP, or GIF. Max 5 MB."),
    user_id: str = Depends(get_current_user),
):
    if not get_user(user_id):
        raise HTTPException(
            status_code=404,
            detail={
                "code": "USER_NOT_FOUND",
                "message": "User tidak ditemukan.",
                "suggestion": "Login ulang dengan Google lalu kirim Authorization: Bearer <Supabase JWT>.",
            },
        )

    content_type = file.content_type or ""
    if content_type not in ALLOWED_IMAGE_TYPES:
        raise HTTPException(
            status_code=400,
            detail={
                "code": "INVALID_INPUT",
                "message": "File harus berupa gambar JPG, PNG, WebP, atau GIF.",
                "suggestion": "Upload file gambar dengan Content-Type image/jpeg, image/png, image/webp, atau image/gif.",
            },
        )

    content = await file.read()
    if not content:
        raise HTTPException(
            status_code=400,
            detail={
                "code": "INVALID_INPUT",
                "message": "File gambar kosong.",
                "suggestion": "Pilih file gambar yang valid.",
            },
        )

    if len(content) > MAX_IMAGE_BYTES:
        raise HTTPException(
            status_code=413,
            detail={
                "code": "FILE_TOO_LARGE",
                "message": "Ukuran gambar melebihi 5 MB.",
                "suggestion": "Kompres gambar atau upload file yang lebih kecil.",
            },
        )

    try:
        data = upload_product_image(
            product_id=product_id,
            filename=file.filename or "product-image",
            content=content,
            content_type=content_type,
        )
    except ValueError as exc:
        if str(exc) == "PRODUCT_NOT_FOUND":
            raise HTTPException(
                status_code=404,
                detail={
                    "code": "PRODUCT_NOT_FOUND",
                    "message": "Produk tidak ditemukan.",
                    "suggestion": "Pastikan product_id berasal dari tabel products.",
                },
            ) from exc
        raise
    except RuntimeError as exc:
        message = str(exc)
        if message.startswith("PRODUCT_IMAGE_URL_COLUMN_MISSING"):
            raise HTTPException(
                status_code=422,
                detail={
                    "code": "SCHEMA_MISSING_COLUMN",
                    "message": "Kolom products.image_url belum tersedia.",
                    "suggestion": "Jalankan ALTER TABLE products ADD COLUMN image_url TEXT; lalu coba lagi.",
                },
            ) from exc
        if message.startswith("STORAGE_UPLOAD_FAILED"):
            raise HTTPException(
                status_code=502,
                detail={
                    "code": "STORAGE_UPLOAD_FAILED",
                    "message": "Gagal upload gambar ke Supabase Storage.",
                    "suggestion": "Pastikan bucket PRODUCT_IMAGES_BUCKET/product-images sudah ada dan policy upload mengizinkan service key.",
                },
            ) from exc
        if message.startswith("STORAGE_BUCKET_UNAVAILABLE"):
            raise HTTPException(
                status_code=502,
                detail={
                    "code": "STORAGE_BUCKET_UNAVAILABLE",
                    "message": "Bucket Supabase Storage tidak tersedia dan tidak bisa dibuat otomatis.",
                    "suggestion": "Buat bucket public bernama product-images di Supabase Storage atau gunakan service-role key untuk backend.",
                },
            ) from exc
        raise

    return ProductImageResponse(data=ProductImageData(**data))
