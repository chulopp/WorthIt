import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/notification_generator.dart';
import '../models/notification_model.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final ValueNotifier<List<NotificationModel>> notifications = ValueNotifier(
    <NotificationModel>[],
  );

  Future<void> init() async {
    await checkEndOfMonthReminders();
  }

  void loadMockNotifications({
    bool replace = false,
    String lastMonthName = 'February',
    String twoMonthsAgoName = 'January',
  }) {
    final mocks = NotificationGenerator.mockNotifications(
      lastMonthName: lastMonthName,
      twoMonthsAgoName: twoMonthsAgoName,
    );
    notifications.value = replace
        ? mocks
        : <NotificationModel>[...notifications.value, ...mocks];
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

  Future<void> checkEndOfMonthReminders({int uncheckedItemCount = 1}) async {
    if (uncheckedItemCount <= 0) return;

    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final firstDayOfNextMonth = DateTime(now.year, now.month + 1, 1);
    final daysUntilReset = firstDayOfNextMonth.difference(today).inDays;

    if (daysUntilReset < 1 || daysUntilReset > 3) return;

    final todayKey = 'eom_reminder_${now.year}_${now.month}_${now.day}';
    if (prefs.getBool(todayKey) ?? false) return;

    addNotification(
      NotificationGenerator.shoppingListReminder(
        uncheckedItemCount: uncheckedItemCount,
        daysUntilReset: daysUntilReset,
        createdAt: now,
      ),
    );

    await prefs.setBool(todayKey, true);
  }

  void notifyOverBudget({
    required num totalSpending,
    required num monthlyBudget,
  }) {
    if (monthlyBudget <= 0 || totalSpending < monthlyBudget) return;
    addNotification(
      NotificationGenerator.overBudget(
        totalSpending: totalSpending,
        monthlyBudget: monthlyBudget,
      ),
    );
  }

  void notifyProSubscriptionExpiring({required int daysLeft}) {
    if (daysLeft != 7 && daysLeft != 3 && daysLeft != 1) return;
    addNotification(
      NotificationGenerator.proSubscriptionExpiring(daysLeft: daysLeft),
    );
  }

  void notifyPdfDownloadSuccess() {
    addNotification(NotificationGenerator.pdfDownloadSuccess());
  }

  void notifyFavoritePriceDrop({
    required String productName,
    required num dropPercent,
  }) {
    if (dropPercent <= 0) return;
    addNotification(
      NotificationGenerator.favoritePriceDrop(
        productName: productName,
        dropPercent: dropPercent,
      ),
    );
  }

  void notifyMonthlySpendingComparison({
    required String lastMonthName,
    required String twoMonthsAgoName,
    required num lastMonthTotal,
    required num twoMonthsAgoTotal,
  }) {
    addNotification(
      NotificationGenerator.monthlySpendingComparison(
        lastMonthName: lastMonthName,
        twoMonthsAgoName: twoMonthsAgoName,
        lastMonthTotal: lastMonthTotal,
        twoMonthsAgoTotal: twoMonthsAgoTotal,
      ),
    );
  }
}
