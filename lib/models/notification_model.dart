import 'package:flutter/material.dart';

enum NotificationType { priceAlert, budgetAlert, reminder, system }

class NotificationModel {
  final String title;
  final String message;
  final String dateTime;
  final NotificationType type;
  final String? payload;
  bool isUnread;

  NotificationModel({
    required this.title,
    required this.message,
    required this.dateTime,
    required this.type,
    this.payload,
    this.isUnread = false,
  });

  IconData get icon {
    switch (type) {
      case NotificationType.priceAlert:
        return Icons.trending_down;
      case NotificationType.budgetAlert:
        return Icons.warning_amber_rounded;
      case NotificationType.reminder:
        return Icons.shopping_cart;
      case NotificationType.system:
        return Icons.campaign;
    }
  }

  Color get iconColor {
    switch (type) {
      case NotificationType.priceAlert:
        return const Color(0xFFC9E88A);
      case NotificationType.budgetAlert:
        return Colors.orange;
      case NotificationType.reminder:
        return const Color(0xFFC9E88A);
      case NotificationType.system:
        return Colors.blue;
    }
  }
}
