"""
routers/shopping.py
Monthly shopping list endpoints for the Bottom Sheet UI.
"""

from __future__ import annotations

from datetime import datetime, timedelta, timezone
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from fastapi import APIRouter, Depends, HTTPException

from core.security import get_current_user
from models.shopping import AddItemRequest, MonthlyListResponse, ShoppingItemResponse
from utils.supabase_client import _safe_execute, get_product, get_supabase, get_user, latest_prices_by_product

router = APIRouter(prefix="/v1/shopping-list", tags=["Shopping List"])


def _current_period_month() -> str:
    try:
        jakarta_tz = ZoneInfo("Asia/Jakarta")
    except ZoneInfoNotFoundError:
        jakarta_tz = timezone(timedelta(hours=7))
    return datetime.now(jakarta_tz).strftime("%Y-%m")


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


def _fetch_monthly_list(user_id: str, period_month: str) -> dict | None:
    sb = get_supabase()
    res = _safe_execute(sb.table("monthly_shopping_lists")
        .select("*")
        .eq("user_id", user_id)
        .eq("period_month", period_month)
        .limit(1))
    return res.data[0] if res.data else None


def _is_unique_violation(exc: Exception) -> bool:
    message = str(exc).lower()
    return "duplicate" in message or "unique" in message or "23505" in message


def _get_or_create_current_list(user_id: str) -> dict:
    period_month = _current_period_month()
    existing = _fetch_monthly_list(user_id, period_month)
    if existing:
        return existing

    sb = get_supabase()
    try:
        inserted = _safe_execute(sb.table("monthly_shopping_lists")
            .insert({"user_id": user_id, "period_month": period_month}))
        if inserted.data:
            return inserted.data[0]
    except Exception as exc:
        if not _is_unique_violation(exc):
            raise

    existing = _fetch_monthly_list(user_id, period_month)
    if existing:
        return existing

    raise HTTPException(
        status_code=500,
        detail={
            "code": "SHOPPING_LIST_CREATE_FAILED",
            "message": "Gagal membuat daftar belanja bulan ini.",
            "suggestion": "Coba lagi dalam beberapa saat.",
        },
    )



def _build_monthly_response(monthly_list: dict) -> MonthlyListResponse:
    sb = get_supabase()
    items_res = _safe_execute(sb.table("shopping_list_items")
        .select("id, product_id, quantity, is_bought, created_at, products(id, name, image_url, category)")
        .eq("list_id", monthly_list["id"])
        .order("created_at", desc=False))

    rows = items_res.data or []
    product_ids = list({row["product_id"] for row in rows if row.get("product_id")})
    latest_prices = latest_prices_by_product(product_ids)

    items: list[ShoppingItemResponse] = []
    total_estimated_price = 0.0

    for row in rows:
        product = row.get("products") or row.get("product") or {}
        product_id = row.get("product_id") or product.get("id")
        current_price = latest_prices.get(product_id, 0.0)
        quantity = int(row.get("quantity") or 1)
        total_estimated_price += current_price * quantity

        items.append(ShoppingItemResponse(
            id=row["id"],
            product_id=product_id,
            product_name=product.get("name", "Produk Tidak Diketahui"),
            image_url=product.get("image_url"),
            category=product.get("category", ""),
            current_price=current_price,
            quantity=quantity,
            is_bought=bool(row.get("is_bought") or False),
        ))

    return MonthlyListResponse(
        list_id=monthly_list["id"],
        period_month=monthly_list["period_month"],
        total_budget=int(monthly_list.get("total_budget") or 0),
        total_estimated_price=total_estimated_price,
        items=items,
    )


@router.get(
    "/current",
    response_model=MonthlyListResponse,
    summary="Current Monthly Shopping List",
    description="Ambil atau buat otomatis daftar belanja aktif untuk bulan berjalan.",
)
async def get_current_shopping_list(
    user_id: str = Depends(get_current_user),
):
    user_id = _ensure_existing_user(user_id)
    monthly_list = _get_or_create_current_list(user_id)
    return _build_monthly_response(monthly_list)


@router.post(
    "/current/items",
    response_model=MonthlyListResponse,
    summary="Add Item To Current Monthly Shopping List",
    description="Tambah produk ke daftar belanja bulan ini atau increment quantity jika sudah ada.",
)
async def add_current_shopping_list_item(
    body: AddItemRequest,
    user_id: str = Depends(get_current_user),
):
    user_id = _ensure_existing_user(user_id)

    if not get_product(body.product_id):
        raise HTTPException(
            status_code=404,
            detail={
                "code": "PRODUCT_NOT_FOUND",
                "message": "Produk tidak ditemukan.",
                "suggestion": "Pastikan product_id berasal dari tabel products.",
            },
        )

    monthly_list = _get_or_create_current_list(user_id)
    sb = get_supabase()

    existing = _safe_execute(sb.table("shopping_list_items")
        .select("id, quantity")
        .eq("list_id", monthly_list["id"])
        .eq("product_id", body.product_id)
        .limit(1))

    if existing.data:
        item = existing.data[0]
        new_quantity = int(item.get("quantity") or 0) + body.quantity
        _safe_execute(sb.table("shopping_list_items")
            .update({"quantity": new_quantity})
            .eq("id", item["id"])
            .eq("list_id", monthly_list["id"]))
    else:
        try:
            _safe_execute(sb.table("shopping_list_items")
                .insert({
                    "list_id": monthly_list["id"],
                    "product_id": body.product_id,
                    "quantity": body.quantity,
                }))
        except Exception as exc:
            if not _is_unique_violation(exc):
                raise
            existing_after_conflict = _safe_execute(sb.table("shopping_list_items")
                .select("id, quantity")
                .eq("list_id", monthly_list["id"])
                .eq("product_id", body.product_id)
                .limit(1))
            if not existing_after_conflict.data:
                raise
            item = existing_after_conflict.data[0]
            new_quantity = int(item.get("quantity") or 0) + body.quantity
            _safe_execute(sb.table("shopping_list_items")
                .update({"quantity": new_quantity})
                .eq("id", item["id"])
                .eq("list_id", monthly_list["id"]))

    return _build_monthly_response(monthly_list)


@router.patch(
    "/current/items/{item_id}/toggle",
    response_model=MonthlyListResponse,
    summary="Toggle Shopping List Item Bought Status",
    description="Ubah status checklist is_bought untuk item daftar belanja bulan ini.",
)
async def toggle_current_shopping_list_item(
    item_id: str,
    user_id: str = Depends(get_current_user),
):
    user_id = _ensure_existing_user(user_id)
    monthly_list = _get_or_create_current_list(user_id)
    sb = get_supabase()

    existing = _safe_execute(sb.table("shopping_list_items")
        .select("id, is_bought")
        .eq("id", item_id)
        .eq("list_id", monthly_list["id"])
        .limit(1))
    if not existing.data:
        raise HTTPException(
            status_code=404,
            detail={
                "code": "SHOPPING_LIST_ITEM_NOT_FOUND",
                "message": "Item tidak ditemukan di daftar belanja bulan ini.",
                "suggestion": "Refresh daftar belanja lalu coba lagi.",
            },
        )

    current = bool(existing.data[0].get("is_bought") or False)
    _safe_execute(sb.table("shopping_list_items")
        .update({"is_bought": not current})
        .eq("id", item_id)
        .eq("list_id", monthly_list["id"]))

    return _build_monthly_response(monthly_list)


@router.delete(
    "/current/items/{item_id}",
    response_model=MonthlyListResponse,
    summary="Delete Item From Current Monthly Shopping List",
    description="Hapus satu item spesifik dari daftar belanja bulan ini.",
)
async def delete_current_shopping_list_item(
    item_id: str,
    user_id: str = Depends(get_current_user),
):
    user_id = _ensure_existing_user(user_id)
    monthly_list = _get_or_create_current_list(user_id)
    sb = get_supabase()

    existing = _safe_execute(sb.table("shopping_list_items")
        .select("id")
        .eq("id", item_id)
        .eq("list_id", monthly_list["id"])
        .limit(1))
    if not existing.data:
        raise HTTPException(
            status_code=404,
            detail={
                "code": "SHOPPING_LIST_ITEM_NOT_FOUND",
                "message": "Item tidak ditemukan di daftar belanja bulan ini.",
                "suggestion": "Refresh daftar belanja lalu coba lagi.",
            },
        )

    _safe_execute(sb.table("shopping_list_items")
        .delete()
        .eq("id", item_id)
        .eq("list_id", monthly_list["id"]))

    return _build_monthly_response(monthly_list)


@router.delete(
    "/current/items",
    response_model=MonthlyListResponse,
    summary="Clear Current Monthly Shopping List",
    description="Hapus semua item dari daftar belanja bulan ini.",
)
async def clear_current_shopping_list_items(
    user_id: str = Depends(get_current_user),
):
    user_id = _ensure_existing_user(user_id)
    monthly_list = _get_or_create_current_list(user_id)
    sb = get_supabase()

    _safe_execute(sb.table("shopping_list_items")
        .delete()
        .eq("list_id", monthly_list["id"]))

    return _build_monthly_response(monthly_list)
