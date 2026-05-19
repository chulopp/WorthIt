"""
routers/tracker.py
GET /v1/tracker — Data portfolio / pengeluaran per kategori bulan ini.
"""

from fastapi import APIRouter, Depends, Query
from typing import Optional
from datetime import datetime, timezone

from core.security import get_current_user
from models.response import TrackerResponse, TrackerData, CategorySpend, TrackerItem
from utils.supabase_client import get_tracker_data

router = APIRouter(prefix="/v1", tags=["Tracker"])


@router.get(
    "/tracker",
    response_model=TrackerResponse,
    summary="Data Portfolio Belanja",
    description="Ambil ringkasan pengeluaran per kategori untuk bulan tertentu (default: bulan ini).",
)
async def get_tracker(
    month: Optional[str] = Query(
        default=None,
        description="Format YYYY-MM. Contoh: 2026-05. Default: bulan ini.",
        pattern=r"^\d{4}-\d{2}$",
    ),
    user_id: str = Depends(get_current_user),
):
    # Default ke bulan ini jika tidak ada parameter
    if not month:
        now   = datetime.now(timezone.utc)
        month = f"{now.year}-{now.month:02d}"

    data = get_tracker_data(user_id, month)

    by_category = [
        CategorySpend(
            category=c["category"],
            amount=c["amount"],
            percentage=c["percentage"],
        )
        for c in data["by_category"]
    ]

    items = [
        TrackerItem(
            product_name=i["product_name"],
            price_paid=i["price_paid"],
            date=i["date"],
            decision_score=i.get("decision_score"),
            action_taken=i["action_taken"],
        )
        for i in data["items"]
    ]

    return TrackerResponse(
        data=TrackerData(
            total_spent=data["total_spent"],
            total_items=data["total_items"],
            avg_per_item=data["avg_per_item"],
            by_category=by_category,
            items=items,
        )
    )
