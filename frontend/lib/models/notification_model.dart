import 'package:flutter/material.dart';

enum NotificationType {
  shoppingListReminder,
  overBudget,
  proSubscriptionExpiring,
  pdfDownloadSuccess,
  favoritePriceDrop,
  monthlySpendingComparison,
}

class NotificationModel {
  final String title;
  final String message;
  final Map<String, String> titleArgs;
  final Map<String, String> messageArgs;
  final String dateTime;
  final NotificationType type;
  final String? payload;
  bool isUnread;

  NotificationModel({
    required this.title,
    required this.message,
    this.titleArgs = const <String, String>{},
    this.messageArgs = const <String, String>{},
    required this.dateTime,
    required this.type,
    this.payload,
    this.isUnread = false,
  });

  IconData get icon {
    switch (type) {
      case NotificationType.shoppingListReminder:
        return Icons.format_list_bulleted_rounded;
      case NotificationType.overBudget:
        return Icons.warning_amber_rounded;
      case NotificationType.proSubscriptionExpiring:
        return Icons.workspace_premium_rounded;
      case NotificationType.pdfDownloadSuccess:
        return Icons.picture_as_pdf_rounded;
      case NotificationType.favoritePriceDrop:
        return Icons.trending_down_rounded;
      case NotificationType.monthlySpendingComparison:
        return Icons.account_balance_wallet_rounded;
    }
  }

  Color get iconColor {
    switch (type) {
      case NotificationType.shoppingListReminder:
        return const Color(0xFFC9E88A);
      case NotificationType.overBudget:
        return const Color(0xFFF59E0B);
      case NotificationType.proSubscriptionExpiring:
        return const Color(0xFFFACC15);
      case NotificationType.pdfDownloadSuccess:
        return const Color(0xFF3B82F6);
      case NotificationType.favoritePriceDrop:
        return const Color(0xFF22C55E);
      case NotificationType.monthlySpendingComparison:
        return const Color(0xFF304423);
    }
  }
}
