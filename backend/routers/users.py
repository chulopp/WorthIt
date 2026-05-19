"""
routers/users.py
Endpoint user profile/settings yang dibutuhkan frontend.
"""

from fastapi import APIRouter, Depends, HTTPException

from core.security import get_current_user
from models.users import BudgetUpdateRequest, BudgetUpdateResponse
from utils.supabase_client import delete_user_account, get_user, update_user_monthly_budget

router = APIRouter(prefix="/v1/users", tags=["Users"])


@router.patch(
    "/me/budget",
    response_model=BudgetUpdateResponse,
    summary="Update Monthly Budget",
    description="Update kolom monthly_budget user yang sedang login.",
)
async def update_my_budget(
    body: BudgetUpdateRequest,
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

    user = update_user_monthly_budget(user_id, body.new_budget)
    if not user:
        raise HTTPException(
            status_code=500,
            detail={
                "code": "BUDGET_UPDATE_FAILED",
                "message": "Gagal memperbarui monthly_budget.",
                "suggestion": "Coba lagi dalam beberapa saat.",
            },
        )

    return BudgetUpdateResponse(
        user_id=user["id"],
        monthly_budget=int(user["monthly_budget"] or 0),
    )


@router.delete(
    "/me",
    summary="Delete Current Account",
    description="Hapus data aplikasi user lalu hapus Supabase Auth user dengan service role.",
)
async def delete_my_account(
    user_id: str = Depends(get_current_user),
):
    if not get_user(user_id):
        raise HTTPException(
            status_code=404,
            detail={
                "code": "USER_NOT_FOUND",
                "message": "User tidak ditemukan.",
                "suggestion": "Login ulang dengan Google lalu coba lagi.",
            },
        )

    try:
        delete_user_account(user_id)
    except Exception as exc:
        raise HTTPException(
            status_code=502,
            detail={
                "code": "ACCOUNT_DELETE_FAILED",
                "message": "Gagal menghapus akun dari Supabase Auth.",
                "suggestion": "Pastikan SUPABASE_SERVICE_ROLE_KEY tersedia di backend dan coba lagi.",
            },
        ) from exc

    return {"status": "success", "data": {"deleted": True}}
