#!/usr/bin/env python3
"""
backend/scripts/daily_notification_cron.py
Daily Background Task for WorthIt System Notifications.

Menjalankan pengecekan harian untuk:
1. Notifikasi Pro Expiry (PRO_EXPIRING): Menagih pengguna yang berlangganan Pro saat H-7, H-3, dan H-1.
2. Notifikasi Rekap Perbandingan Bulanan (SPENDING_COMPARE): Dijalankan setiap tanggal 1 bulan baru
   untuk membandingkan total pengeluaran bulan lalu vs 2 bulan lalu.
"""

from __future__ import annotations

import logging
import sys
from datetime import datetime, timezone
from pathlib import Path

# Add backend directory to sys.path
backend_dir = Path(__file__).resolve().parent.parent
if str(backend_dir) not in sys.path:
    sys.path.insert(0, str(backend_dir))

from utils.supabase_client import (
    _safe_execute,
    create_notification,
    get_supabase,
)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(name)s: %(message)s",
)
LOGGER = logging.getLogger("daily_notification_cron")

MONTH_NAMES = [
    "", "Januari", "Februari", "Maret", "April", "Mei", "Juni",
    "Juli", "Agustus", "September", "Oktober", "November", "Desember"
]


def check_pro_expiring_notifications() -> int:
    """Cek user Pro yang berjarak 7, 3, atau 1 hari dari `pro_expires_at`."""
    LOGGER.info("Memeriksa status langganan Pro user...")
    sb = get_supabase()

    today = datetime.now(timezone.utc).date()
    notif_count = 0

    try:
        users_res = _safe_execute(
            sb.table("users")
            .select("id, pro_expires_at")
            .eq("subscription_tier", "PRO")
            .not_.is_("pro_expires_at", "null")
        )
        pro_users = users_res.data or []
    except Exception as exc:
        LOGGER.error("Gagal mengambil data user Pro: %s", exc)
        return 0

    for user in pro_users:
        user_id = user.get("id")
        exp_str = user.get("pro_expires_at")
        if not user_id or not exp_str:
            continue

        try:
            exp_date = datetime.fromisoformat(exp_str.replace("Z", "+00:00")).date()
        except Exception:
            continue

        days_left = (exp_date - today).days

        if days_left in (7, 3, 1):
            today_str = today.isoformat()
            # Anti-spam: hindari duplikasi notifikasi untuk H-X yang sama hari ini
            existing = _safe_execute(
                sb.table("notifications")
                .select("id")
                .eq("user_id", user_id)
                .eq("type", "PRO_EXPIRING")
                .gte("created_at", f"{today_str}T00:00:00Z")
                .limit(1)
            )
            if existing.data:
                continue

            created = create_notification(
                user_id=user_id,
                title="notifications.pro_expiring.title",
                body="notifications.pro_expiring.desc",
                notif_type="PRO_EXPIRING",
                payload={"days": str(days_left)},
            )
            if created:
                notif_count += 1
                LOGGER.info("Dibuat notifikasi PRO_EXPIRING H-%d untuk user %s", days_left, user_id)

    return notif_count


def check_monthly_spending_comparison() -> int:
    """
    Dijalankan setiap tanggal 1 bulan baru untuk menghitung pengeluaran bulan lalu vs 2 bulan lalu.
    """
    now = datetime.now(timezone.utc)
    # Jika bukan tanggal 1, skip (atau bisa di-force jika testing)
    if now.day != 1:
        LOGGER.info("Hari ini tanggal %d (bukan tanggal 1), lewati rekap bulanan.", now.day)
        return 0

    LOGGER.info("Tanggal 1 terdeteksi! Memproses rekap pengeluaran bulanan...")
    sb = get_supabase()
    notif_count = 0

    # Bulan M-1 dan M-2
    curr_year, curr_month = now.year, now.month
    if curr_month == 1:
        m1_year, m1_month = curr_year - 1, 12
        m2_year, m2_month = curr_year - 1, 11
    elif curr_month == 2:
        m1_year, m1_month = curr_year, 1
        m2_year, m2_month = curr_year - 1, 12
    else:
        m1_year, m1_month = curr_year, curr_month - 1
        m2_year, m2_month = curr_year, curr_month - 2

    m1_name = MONTH_NAMES[m1_month]
    m2_name = MONTH_NAMES[m2_month]

    # Ambil semua user aktif
    try:
        users_res = _safe_execute(sb.table("users").select("id"))
        users = users_res.data or []
    except Exception as exc:
        LOGGER.error("Gagal mengambil data users: %s", exc)
        return 0

    for user in users:
        user_id = user.get("id")
        if not user_id:
            continue

        # Hitung pengeluaran M-1
        try:
            start_m1 = datetime(m1_year, m1_month, 1, tzinfo=timezone.utc).isoformat()
            if m1_month == 12:
                end_m1 = datetime(m1_year + 1, 1, 1, tzinfo=timezone.utc).isoformat()
            else:
                end_m1 = datetime(m1_year, m1_month + 1, 1, tzinfo=timezone.utc).isoformat()

            res1 = _safe_execute(
                sb.table("purchase_history")
                .select("purchased_price, quantity")
                .eq("user_id", user_id)
                .gte("purchased_at", start_m1)
                .lt("purchased_at", end_m1)
            )
            spent_m1 = sum(float(r.get("purchased_price") or 0) * float(r.get("quantity") or 1) for r in (res1.data or []))
        except Exception:
            spent_m1 = 0.0

        # Hitung pengeluaran M-2
        try:
            start_m2 = datetime(m2_year, m2_month, 1, tzinfo=timezone.utc).isoformat()
            if m2_month == 12:
                end_m2 = datetime(m2_year + 1, 1, 1, tzinfo=timezone.utc).isoformat()
            else:
                end_m2 = datetime(m2_year, m2_month + 1, 1, tzinfo=timezone.utc).isoformat()

            res2 = _safe_execute(
                sb.table("purchase_history")
                .select("purchased_price, quantity")
                .eq("user_id", user_id)
                .gte("purchased_at", start_m2)
                .lt("purchased_at", end_m2)
            )
            spent_m2 = sum(float(r.get("purchased_price") or 0) * float(r.get("quantity") or 1) for r in (res2.data or []))
        except Exception:
            spent_m2 = 0.0

        # Jika kedua bulan 0, skip
        if spent_m1 == 0 and spent_m2 == 0:
            continue

        is_saving = spent_m1 <= spent_m2
        diff = abs(spent_m1 - spent_m2)

        title_key = (
            "notifications.monthly_comparison.saving_title"
            if is_saving
            else "notifications.monthly_comparison.overspent_title"
        )
        desc_key = (
            "notifications.monthly_comparison.saving_desc"
            if is_saving
            else "notifications.monthly_comparison.overspent_desc"
        )

        today_str = now.strftime("%Y-%m-%d")
        existing = _safe_execute(
            sb.table("notifications")
            .select("id")
            .eq("user_id", user_id)
            .eq("type", "SPENDING_COMPARE")
            .gte("created_at", f"{today_str}T00:00:00Z")
            .limit(1)
        )
        if existing.data:
            continue

        created = create_notification(
            user_id=user_id,
            title=title_key,
            body=desc_key,
            notif_type="SPENDING_COMPARE",
            payload={
                "lastMonth": m1_name,
                "twoMonthsAgo": m2_name,
                "lastTotal": str(int(spent_m1)),
                "previousTotal": str(int(spent_m2)),
                "difference": str(int(diff)),
            },
        )
        if created:
            notif_count += 1
            LOGGER.info("Dibuat notifikasi SPENDING_COMPARE untuk user %s", user_id)

    return notif_count


def main():
    LOGGER.info("=== Menjalankan Daily Notification Cron Script ===")
    pro_count = check_pro_expiring_notifications()
    compare_count = check_monthly_spending_comparison()
    LOGGER.info("=== Cron Selesai. Total Notifikasi Dibuat: Pro Expiring=%d, Rekap Bulanan=%d ===", pro_count, compare_count)


if __name__ == "__main__":
    main()
