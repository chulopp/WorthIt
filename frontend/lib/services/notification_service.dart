import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
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


  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    // 1. Initialize local notifications settings
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    try {
      await _localNotifications.initialize(initializationSettings);
    } catch (_) {}

    // 2. Request permission (Android 13+)
    await requestNotificationPermission();

    // 3. Check for EOM reminders
    await checkEndOfMonthReminders();
  }

  Future<void> requestNotificationPermission() async {
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }
  }

  Future<void> showLocalNotification(String title, String body) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'worthit_alerts',
      'WorthIt Alerts',
      channelDescription: 'System warnings and shopping list notifications from WorthIt',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      await _localNotifications.show(
        DateTime.now().millisecond,
        title,
        body,
        platformDetails,
      );
    } catch (_) {}
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

    // Translate before triggering actual system notification
    final translatedTitle = notification.title.tr(namedArgs: notification.titleArgs);
    final translatedMessage = notification.message.tr(namedArgs: notification.messageArgs);
    showLocalNotification(translatedTitle, translatedMessage);
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
