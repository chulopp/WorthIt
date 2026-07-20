import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/notification_model.dart';
import '../services/notification_service.dart';

final notificationControllerProvider =
    AsyncNotifierProvider<NotificationController, List<NotificationModel>>(
      NotificationController.new,
    );

class NotificationController extends AsyncNotifier<List<NotificationModel>> {
  @override
  FutureOr<List<NotificationModel>> build() async {
    return fetchNotifications();
  }

  Future<List<NotificationModel>> fetchNotifications() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      final service = NotificationService();
      return service.notifications.value;
    }

    try {
      final res = await Supabase.instance.client
          .from('notifications')
          .select('id, title, body, type, is_read, created_at')
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .limit(20);

      final list = (res as List).map<NotificationModel>((map) {
        final title = map['title']?.toString() ?? 'Notifikasi';
        final body = map['body']?.toString() ?? '';
        final createdAtStr = map['created_at']?.toString() ?? '';
        final isRead = map['is_read'] == true;
        final rawType = map['type']?.toString();

        DateTime? dt = DateTime.tryParse(createdAtStr)?.toLocal();
        String formattedTime = dt != null
            ? '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}'
            : 'Baru saja';

        NotificationType notifType = NotificationType.shoppingListReminder;
        if (rawType != null) {
          switch (rawType.toUpperCase()) {
            case 'OVER_BUDGET':
              notifType = NotificationType.overBudget;
              break;
            case 'PRO_EXPIRING':
              notifType = NotificationType.proSubscriptionExpiring;
              break;
            case 'PDF_DOWNLOAD':
              notifType = NotificationType.pdfDownloadSuccess;
              break;
            case 'PRICE_DROP':
              notifType = NotificationType.favoritePriceDrop;
              break;
            case 'SPENDING_COMPARE':
              notifType = NotificationType.monthlySpendingComparison;
              break;
          }
        }

        return NotificationModel(
          title: title,
          message: body,
          dateTime: formattedTime,
          isUnread: !isRead,
          type: notifType,
        );
      }).toList();

      if (list.isNotEmpty) {
        return list;
      }
    } catch (_) {}

    final service = NotificationService();
    return List<NotificationModel>.from(service.notifications.value);
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => fetchNotifications());
  }

  Future<void> markAllAsRead() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      try {
        await Supabase.instance.client
            .from('notifications')
            .update({'is_read': true})
            .eq('user_id', user.id);
      } catch (_) {}
    }
    await refresh();
  }
}
