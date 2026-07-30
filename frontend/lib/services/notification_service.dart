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

  final Set<String> _shownNotifKeys = {};

  String _safeTranslate(String textOrKey, Map<String, String> args) {
    if (textOrKey.isEmpty) return '';

    String result = textOrKey;
    try {
      result = textOrKey.tr(namedArgs: args);
    } catch (_) {}

    if (result.contains('notifications.') || result == textOrKey) {
      switch (textOrKey) {
        case 'notifications.shopping_list.title':
          return 'Daftar belanjamu hampir reset';
        case 'notifications.shopping_list.desc':
          final count = args['count'] ?? '1';
          final days = args['days'] ?? '3';
          return 'Masih ada $count item yang belum dicentang. Selesaikan dalam $days hari sebelum daftar bulan ini otomatis direset.';
        case 'notifications.over_budget.title':
          return 'Anggaran bulan ini sudah tersentuh';
        case 'notifications.over_budget.desc':
          final spent = args['spent'] ?? '0';
          final budget = args['budget'] ?? '0';
          return 'Pengeluaranmu sudah $spent, sementara batasmu $budget. Yuk tahan dulu belanja impulsif dan prioritaskan kebutuhan utama.';
        case 'notifications.pro_expiring.title':
          return 'Masa aktif PRO hampir habis';
        case 'notifications.pro_expiring.desc':
          final days = args['days'] ?? '7';
          return 'Benefit PRO kamu tinggal $days hari lagi. Perpanjang agar ekspor PDF dan insight premium tetap siap dipakai.';
        case 'notifications.pdf_success.title':
          return 'Laporan PDF berhasil dibuat';
        case 'notifications.pdf_success.desc':
          return 'Riwayat belanja bulan ini sudah siap. Kamu bisa menyimpan atau membagikannya untuk evaluasi pengeluaran.';
        case 'notifications.favorite_price_drop.title':
          return 'Barang favoritmu sedang turun harga';
        case 'notifications.favorite_price_drop.desc':
          final prod = args['product'] ?? 'Barang favorit';
          final pct = args['percent'] ?? '5';
          return '$prod turun sekitar $pct% bulan ini. Momen bagus untuk cek stok sebelum harga bergerak lagi.';
        case 'notifications.monthly_comparison.saving_title':
          return 'Kamu lebih hemat bulan lalu';
        case 'notifications.monthly_comparison.saving_desc':
          final m1 = args['lastMonth'] ?? 'bulan lalu';
          final t1 = args['lastTotal'] ?? 'Rp 0';
          final diff = args['difference'] ?? 'Rp 0';
          final m2 = args['twoMonthsAgo'] ?? 'dua bulan lalu';
          final t2 = args['previousTotal'] ?? 'Rp 0';
          return 'Pengeluaran $m1 sebesar $t1, turun $diff dibanding $m2 ($t2). Ritmenya sudah bagus, pertahankan.';
        case 'notifications.monthly_comparison.overspent_title':
          return 'Pengeluaran bulan lalu naik';
        case 'notifications.monthly_comparison.overspent_desc':
          final m1 = args['lastMonth'] ?? 'bulan lalu';
          final t1 = args['lastTotal'] ?? 'Rp 0';
          final diff = args['difference'] ?? 'Rp 0';
          final m2 = args['twoMonthsAgo'] ?? 'dua bulan lalu';
          final t2 = args['previousTotal'] ?? 'Rp 0';
          return 'Pengeluaran $m1 mencapai $t1, naik $diff dari $m2 ($t2). Kita rapikan prioritas bulan ini pelan-pelan.';
      }

      if (result.startsWith('notifications.')) {
        return textOrKey.split('.').last.replaceAll('_', ' ');
      }
    }

    return result;
  }

  void triggerSystemNotification(NotificationModel notification, {String? notifId}) {
    final key = notifId ?? '${notification.title}_${notification.dateTime}';
    if (_shownNotifKeys.contains(key)) return;
    _shownNotifKeys.add(key);

    final translatedTitle = _safeTranslate(notification.title, notification.titleArgs);
    final translatedMessage = _safeTranslate(notification.message, notification.messageArgs);
    showLocalNotification(translatedTitle, translatedMessage);
  }

  void addNotification(NotificationModel notification) {
    final current = List<NotificationModel>.from(notifications.value);
    current.insert(0, notification);
    notifications.value = current;

    triggerSystemNotification(notification);
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
