import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/notification_model.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final ValueNotifier<List<NotificationModel>> notifications =
      ValueNotifier(<NotificationModel>[]);

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
    for (final notification in current) {
      notification.isUnread = false;
    }
    notifications.value = current;
  }

  Future<void> checkEndOfMonthReminders() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final lastDayOfMonth = DateTime(now.year, now.month + 1, 0);
    final daysUntilEnd = lastDayOfMonth.day - now.day;

    if (daysUntilEnd != 1 && daysUntilEnd != 3) return;

    final todayKey = 'eom_reminder_${now.year}_${now.month}_${now.day}';
    if (prefs.getBool(todayKey) ?? false) return;

    addNotification(
      NotificationModel(
        title: 'Pengingat Akhir Bulan',
        message:
            'Sudah mau akhir bulan! Jangan lupa cek barang belanjaan yang belum terbeli ya.',
        dateTime:
            '${now.day.toString().padLeft(2, '0')} ${_getMonthName(now.month)} ${now.year} '
            '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
        type: NotificationType.reminder,
        isUnread: true,
      ),
    );

    await prefs.setBool(todayKey, true);
  }

  String _getMonthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    return months[month - 1];
  }
}
