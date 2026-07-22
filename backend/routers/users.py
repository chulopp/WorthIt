"""
routers/users.py
Endpoint user profile/settings yang dibutuhkan frontend.
"""

from fastapi import APIRouter, Depends, HTTPException

from core.security import get_current_user
from models.users import (
    BudgetUpdateRequest,
    BudgetUpdateResponse,
    SubscriptionUpgradeResponse,
    UsernameUpdateRequest,
    UserProfileResponse,
)
from utils.supabase_client import (
    delete_user_account,
    get_user,
    update_user_monthly_budget,
    update_user_display_name,
    update_user_subscription_tier,
)

router = APIRouter(prefix="/v1/users", tags=["Users"])


@router.get(
    "/me",
    response_model=UserProfileResponse,
    summary="Get Current User Profile",
    description="Ambil profil user yang sedang login, termasuk display_name.",
)
async def get_my_profile(
    user_id: str = Depends(get_current_user),
):
    user = get_user(user_id)
    if not user:
        raise HTTPException(
            status_code=404,
            detail={
                "code": "USER_NOT_FOUND",
                "message": "User tidak ditemukan.",
                "suggestion": "Login ulang dengan Google lalu coba lagi.",
            },
        )

    return UserProfileResponse(
        user_id=user_id,
        email=user.get("email") or "",
        display_name=user.get("display_name") or user.get("full_name") or "",
        monthly_budget=int(user.get("monthly_budget") or 0),
        subscription_tier=(user.get("subscription_tier") or "FREE").upper(),
    )


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


@router.patch(
    "/me/username",
    summary="Update Display Name",
    description="Update display_name (username kustom) user yang sedang login.",
)
async def update_my_username(
    body: UsernameUpdateRequest,
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

    display_name = body.display_name.strip()
    if not display_name:
        raise HTTPException(
            status_code=422,
            detail={
                "code": "INVALID_DISPLAY_NAME",
                "message": "Display name tidak boleh kosong.",
                "suggestion": "Isi nama tampilan yang valid.",
            },
        )

    updated = update_user_display_name(user_id, display_name)
    return {
        "status": "success",
        "data": {
            "user_id": user_id,
            "display_name": display_name,
        },
    }


@router.post(
    "/me/upgrade",
    response_model=SubscriptionUpgradeResponse,
    summary="Upgrade to Pro",
    description="Upgrade subscription_tier user ke PRO di database.",
)
async def upgrade_to_pro(
    user_id: str = Depends(get_current_user),
):
    user = get_user(user_id)
    if not user:
        raise HTTPException(
            status_code=404,
            detail={
                "code": "USER_NOT_FOUND",
                "message": "User tidak ditemukan.",
                "suggestion": "Login ulang dengan Google lalu coba lagi.",
            },
        )

    updated = update_user_subscription_tier(user_id, "PRO")
    if not updated:
        raise HTTPException(
            status_code=500,
            detail={
                "code": "UPGRADE_FAILED",
                "message": "Gagal mengupgrade subscription.",
                "suggestion": "Coba lagi dalam beberapa saat.",
            },
        )

    return SubscriptionUpgradeResponse(
        user_id=user_id,
        subscription_tier="PRO",
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
