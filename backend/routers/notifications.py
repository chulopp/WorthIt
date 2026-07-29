"""
routers/notifications.py
Endpoint riwayat notifikasi user dari database Supabase.
"""

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel

from core.security import get_current_user
from utils.supabase_client import (
    create_notification,
    get_user_notifications,
    mark_notifications_as_read,
)

router = APIRouter(prefix="/v1/notifications", tags=["Notifications"])


class NotificationCreateRequest(BaseModel):
    title: str
    body: str = ""
    type: str = "INFO"
    payload: dict | None = None


class MarkReadRequest(BaseModel):
    notification_ids: list[str] | None = None


@router.get(
    "",
    summary="Get 20 Latest Notifications",
    description="Ambil maksimal 20 notifikasi terbaru untuk user yang sedang login.",
)
async def get_my_notifications(
    limit: int = Query(20, ge=1, le=50),
    user_id: str = Depends(get_current_user),
):
    items = get_user_notifications(user_id, limit=limit)
    return {
        "status": "success",
        "data": items,
    }


@router.post(
    "",
    summary="Create System / Alert Notification",
    description="Simpan notifikasi baru untuk user yang sedang login.",
)
async def post_notification(
    body: NotificationCreateRequest,
    user_id: str = Depends(get_current_user),
):
    notif = create_notification(
        user_id=user_id,
        title=body.title,
        body=body.body,
        notif_type=body.type,
        payload=body.payload,
    )
    if not notif:
        raise HTTPException(
            status_code=500,
            detail={"code": "NOTIF_CREATE_FAILED", "message": "Gagal menyimpan notifikasi."},
        )
    return {
        "status": "success",
        "data": notif,
    }


@router.post(
    "/mark-read",
    summary="Mark Notifications as Read",
    description="Tandai notifikasi sebagai sudah dibaca.",
)
async def mark_read(
    body: MarkReadRequest,
    user_id: str = Depends(get_current_user),
):
    mark_notifications_as_read(user_id, body.notification_ids)
    return {
        "status": "success",
        "message": "Notifikasi berhasil ditandai sudah dibaca.",
    }
