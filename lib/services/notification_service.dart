import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/notification_model.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final ValueNotifier<List<NotificationModel>> notifications = ValueNotifier([
    NotificationModel(
      title: "notif_price_drop_title",
      message: "notif_price_drop_desc",
      dateTime: "09 May 2026 • 08:00",
      type: NotificationType.priceAlert,
      payload: "item_beras_123",
      isUnread: true,
    ),
    NotificationModel(
      title: "notif_shopping_reminder_title",
      message: "notif_shopping_reminder_desc",
      dateTime: "08 May 2026 • 19:30",
      type: NotificationType.reminder,
      isUnread: true,
    ),
    NotificationModel(
      title: "notif_budget_warning_title",
      message: "notif_budget_warning_desc",
      dateTime: "05 May 2026 • 14:15",
      type: NotificationType.budgetAlert,
      isUnread: false,
    ),
    NotificationModel(
      title: "notif_promo_title",
      message: "notif_promo_desc",
      dateTime: "01 May 2026 • 10:00",
      type: NotificationType.system,
      payload: "promo_weekend",
      isUnread: false,
    ),
  ]);

  Future<void> init() async {
    await checkEndOfMonthReminders();
  }

  void addNotification(NotificationModel notification) {
    final current = List<NotificationModel>.from(notifications.value);
    current.insert(0, notification);
    notifications.value = current;
  }

  void markAllAsRead() {
    final current = List<NotificationModel>.from(notifications.value);
    for (var n in current) {
      n.isUnread = false;
    }
    notifications.value = current;
  }

  Future<void> checkEndOfMonthReminders() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    // Get the last day of the current month
    final lastDayOfMonth = DateTime(now.year, now.month + 1, 0);
    
    final daysUntilEnd = lastDayOfMonth.day - now.day;

    if (daysUntilEnd == 1 || daysUntilEnd == 3) {
      final String todayKey = "eom_reminder_${now.year}_${now.month}_${now.day}";
      final bool alreadySent = prefs.getBool(todayKey) ?? false;

      if (!alreadySent) {
        addNotification(
          NotificationModel(
            title: "Pengingat Akhir Bulan",
            message: "Sudah mau akhir bulan! Jangan lupa cek barang belanjaan yang belum terbeli ya.",
            dateTime: "${now.day.toString().padLeft(2, '0')} ${_getMonthName(now.month)} ${now.year} • ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}",
            type: NotificationType.reminder,
            isUnread: true,
          )
        );

        await prefs.setBool(todayKey, true);
      }
    }
  }

  String _getMonthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }
}
