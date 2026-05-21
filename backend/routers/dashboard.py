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
            product_id=item.get("product_id"),
            product_name=item["product_name"],
            price=item["price"],
            decision=item["decision"],
            color=item["color"],
            timestamp=item["timestamp"],
            image_url=item.get("image_url"),
            category=item.get("category"),
            unit_label=item.get("unit_label"),
        )
        for item in data["recent_activities"]
    ]

    return DashboardResponse(
        data=DashboardData(
            monthly_budget=data["monthly_budget"],
            budget_remaining=data["budget_remaining"],
            money_saved=data["money_saved"],
            recent_activities=recent,
            daily_expenses=data.get("daily_expenses", []),
            expense_points=data.get("expense_points", []),
            market_insight=data.get("market_insight", ""),
            market_insight_key=data.get("market_insight_key"),
            market_insight_params=data.get("market_insight_params", {}),
        )
    )
