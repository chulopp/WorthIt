"""
routers/dashboard.py
GET /v1/dashboard — Data summary untuk halaman utama WorthIt.
"""

from fastapi import APIRouter, Depends

from core.security import get_current_user
from models.response import DashboardResponse, DashboardData, RecentActivityItem
from utils.supabase_client import get_dashboard_data

router = APIRouter(prefix="/v1", tags=["Dashboard"])


@router.get(
    "/dashboard",
    response_model=DashboardResponse,
    summary="Data Dashboard",
    description="Ambil ringkasan budget, uang terselamatkan, dan aktivitas terbaru untuk halaman utama.",
)
async def get_dashboard(
    user_id: str = Depends(get_current_user),
):
    data    = get_dashboard_data(user_id)

    recent = [
        RecentActivityItem(
            product_name=item["product_name"],
            price=item["price"],
            decision=item["decision"],
            color=item["color"],
            timestamp=item["timestamp"],
        )
        for item in data["recent_activities"]
    ]

    return DashboardResponse(
        data=DashboardData(
            monthly_budget=data["monthly_budget"],
            budget_remaining=data["budget_remaining"],
            money_saved=data["money_saved"],
            recent_activities=recent,
        )
    )
