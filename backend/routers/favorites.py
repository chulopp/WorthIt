"""
routers/favorites.py
Endpoints untuk produk favorit user.
"""

from fastapi import APIRouter, Depends, HTTPException

from core.security import get_current_user
from models.favorites import (
    FavoriteCreate,
    FavoriteDeleteResponse,
    FavoriteItemResponse,
    FavoriteListResponse,
    FavoriteResponse,
)
from utils.supabase_client import (
    add_favorite_product,
    get_product_price_history,
    get_user,
    list_favorite_products,
    remove_favorite_product,
)

router = APIRouter(prefix="/v1/favorites", tags=["Favorites"])


def _favorite_item(favorite: dict) -> FavoriteItemResponse:
    history = get_product_price_history(favorite["id"])
    return FavoriteItemResponse(
        favorite_id=favorite["favorite_id"],
        product_id=favorite["id"],
        product_name=favorite.get("name", ""),
        image_url=favorite.get("image_url"),
        category=favorite.get("category"),
        current_price=(
            int(round(float(history[-1].get("price") or 0))) if history else None
        ),
        favorited_at=favorite.get("favorited_at"),
    )


def _ensure_existing_user(user_id: str) -> str:
    if not get_user(user_id):
        raise HTTPException(
            status_code=404,
            detail={
                "code": "USER_NOT_FOUND",
                "message": "User tidak ditemukan.",
                "suggestion": "Login ulang dengan Google lalu kirim Authorization: Bearer <Supabase JWT>.",
            },
        )
    return user_id


@router.get(
    "",
    response_model=FavoriteListResponse,
    summary="List Favorites",
    description="Mengembalikan daftar produk favorit milik user.",
)
async def get_favorites(
    user_id: str = Depends(get_current_user),
):
    user_id = _ensure_existing_user(user_id)
    favorites = list_favorite_products(user_id)
    return FavoriteListResponse(
        data=[_favorite_item(favorite) for favorite in favorites]
    )


@router.post(
    "",
    response_model=FavoriteResponse,
    status_code=201,
    summary="Add Favorite",
    description="Menambahkan produk ke favorit user.",
)
async def add_favorite(
    body: FavoriteCreate,
    user_id: str = Depends(get_current_user),
):
    user_id = _ensure_existing_user(user_id)

    try:
        favorite = add_favorite_product(user_id=user_id, product_id=body.product_id)
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
        if str(exc) == "FAVORITE_ALREADY_EXISTS":
            raise HTTPException(
                status_code=409,
                detail={
                    "code": "FAVORITE_ALREADY_EXISTS",
                    "message": "Produk sudah ada di favorit.",
                    "suggestion": "Gunakan endpoint GET /v1/favorites untuk melihat daftar favorit.",
                },
            ) from exc
        raise

    return FavoriteResponse(data=_favorite_item(favorite))


@router.delete(
    "/{product_id}",
    response_model=FavoriteDeleteResponse,
    summary="Remove Favorite",
    description="Menghapus produk dari favorit user.",
)
async def delete_favorite(
    product_id: str,
    user_id: str = Depends(get_current_user),
):
    user_id = _ensure_existing_user(user_id)
    deleted = remove_favorite_product(user_id=user_id, product_id=product_id)
    if not deleted:
        raise HTTPException(
            status_code=404,
            detail={
                "code": "FAVORITE_NOT_FOUND",
                "message": "Produk tidak ditemukan di daftar favorit user.",
                "suggestion": "Pastikan product_id sudah pernah ditambahkan ke favorit.",
            },
        )

    return FavoriteDeleteResponse(product_id=product_id)
