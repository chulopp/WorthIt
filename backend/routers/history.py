"""
routers/history.py
Scan and purchase history endpoints.
"""

from __future__ import annotations

from collections import OrderedDict
from datetime import datetime
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query

from core.security import get_current_user
from models.history import (
    MonthlyPurchaseGroup,
    MonthlyPurchaseHistoryResponse,
    PurchaseCreate,
    PurchaseItemResponse,
    PurchaseResponse,
    ScanHistoryItemResponse,
    ScanHistoryResponse,
)
from utils.supabase_client import _safe_execute, get_product, get_supabase, get_user

router = APIRouter(prefix="/v1/history", tags=["History"])

INDONESIAN_MONTHS = {
    1: "Januari",
    2: "Februari",
    3: "Maret",
    4: "April",
    5: "Mei",
    6: "Juni",
    7: "Juli",
    8: "Agustus",
    9: "September",
    10: "Oktober",
    11: "November",
    12: "Desember",
}


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


def _parse_datetime(value: str | None) -> datetime:
    if not value:
        return datetime.utcnow()
    return datetime.fromisoformat(value.replace("Z", "+00:00"))


def _month_label(value: str | None) -> str:
    dt = _parse_datetime(value)
    return f"{INDONESIAN_MONTHS.get(dt.month, dt.strftime('%B'))} {dt.year}"


def _product_from_join(row: dict) -> dict:
    return row.get("products") or row.get("product") or {}


def _fallback_scan_analysis(row: dict, product: dict) -> dict:
    return {
        "product_id": row.get("product_id"),
        "image_url": product.get("image_url"),
        "score": row.get("scan_result_score"),
        "decision": row.get("decision"),
        "product_name": product.get("name", "Produk Tidak Diketahui"),
        "scanned_price": row.get("scanned_price"),
        "normal_price": row.get("normal_price"),
        "category": product.get("category", "Lainnya"),
        "urgency": row.get("urgency"),
        "weight_gram": row.get("weight_gram"),
        "explanations": [],
        "metrics": {},
        "tier": {},
    }


def _scan_item(row: dict) -> ScanHistoryItemResponse:
    product = _product_from_join(row)
    analysis = row.get("analysis_snapshot") or _fallback_scan_analysis(row, product)
    return ScanHistoryItemResponse(
        id=row["id"],
        product_id=row.get("product_id"),
        product_name=product.get("name", "Produk Tidak Diketahui"),
        image_url=product.get("image_url"),
        category=product.get("category"),
        scanned_at=row.get("created_at", ""),
        score=row.get("scan_result_score"),
        decision=row.get("decision"),
        scanned_price=row.get("scanned_price"),
        normal_price=row.get("normal_price"),
        analysis=analysis,
    )


def _purchase_item(row: dict) -> PurchaseItemResponse:
    product = _product_from_join(row)
    purchased_price = int(row.get("purchased_price") or 0)
    quantity = int(row.get("quantity") or 1)
    return PurchaseItemResponse(
        id=row["id"],
        product_id=row["product_id"],
        product_name=product.get("name", "Produk Tidak Diketahui"),
        image_url=product.get("image_url"),
        category=product.get("category"),
        purchased_price=purchased_price,
        quantity=quantity,
        total_price=purchased_price * quantity,
        purchased_at=row.get("purchased_at", ""),
    )


@router.get(
    "/scans",
    response_model=ScanHistoryResponse,
    summary="Scan History",
    description="Ambil riwayat scan user beserta snapshot hasil analisis untuk Bottom Sheet.",
)
async def get_scan_history(
    product_id: Optional[str] = Query(default=None, description="Filter riwayat scan untuk produk tertentu."),
    user_id: str = Depends(get_current_user),
):
    user_id = _ensure_existing_user(user_id)
    sb = get_supabase()

    query = sb.table("scan_history") \
        .select(
            "id, product_id, decision, scanned_price, normal_price, scan_result_score, "
            "created_at, urgency, weight_gram, analysis_snapshot, "
            "products(id, name, image_url, category)"
        ) \
        .eq("user_id", user_id) \
        .order("created_at", desc=True)
    if product_id:
        query = query.eq("product_id", product_id)

    res = _safe_execute(query)
    return ScanHistoryResponse(data=[_scan_item(row) for row in (res.data or [])])


@router.post(
    "/purchases",
    response_model=PurchaseResponse,
    status_code=201,
    summary="Create Purchase History",
    description="Catat barang yang benar-benar dibeli user.",
)
async def create_purchase_history(
    body: PurchaseCreate,
    user_id: str = Depends(get_current_user),
):
    user_id = _ensure_existing_user(user_id)
    product = get_product(body.product_id)
    if not product:
        raise HTTPException(
            status_code=404,
            detail={
                "code": "PRODUCT_NOT_FOUND",
                "message": "Produk tidak ditemukan.",
                "suggestion": "Pastikan product_id berasal dari tabel products.",
            },
        )

    sb = get_supabase()
    inserted = _safe_execute(sb.table("purchase_history")
        .insert({
            "user_id": user_id,
            "product_id": body.product_id,
            "purchased_price": body.purchased_price,
            "quantity": body.quantity,
        }))
    row = inserted.data[0] if inserted.data else {}
    row["products"] = product

    return PurchaseResponse(data=_purchase_item(row))


@router.get(
    "/purchases",
    response_model=MonthlyPurchaseHistoryResponse,
    summary="Monthly Purchase History",
    description="Ambil riwayat barang yang benar-benar dibeli, dikelompokkan per bulan.",
)
async def get_purchase_history(
    user_id: str = Depends(get_current_user),
):
    user_id = _ensure_existing_user(user_id)
    sb = get_supabase()

    res = _safe_execute(sb.table("purchase_history")
        .select("id, product_id, purchased_price, quantity, purchased_at, products(id, name, image_url, category)")
        .eq("user_id", user_id)
        .order("purchased_at", desc=True))

    groups: OrderedDict[str, list[PurchaseItemResponse]] = OrderedDict()
    for row in res.data or []:
        label = _month_label(row.get("purchased_at"))
        groups.setdefault(label, []).append(_purchase_item(row))

    data = [
        MonthlyPurchaseGroup(
            month=month,
            total_actual_spending=sum(item.total_price for item in items),
            items=items,
        )
        for month, items in groups.items()
    ]
    return MonthlyPurchaseHistoryResponse(data=data)
