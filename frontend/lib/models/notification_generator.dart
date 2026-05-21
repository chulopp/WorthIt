import 'notification_model.dart';

class NotificationGenerator {
  const NotificationGenerator._();

  static NotificationModel shoppingListReminder({
    required int uncheckedItemCount,
    required int daysUntilReset,
    DateTime? createdAt,
  }) {
    return NotificationModel(
      title: 'notifications.shopping_list.title',
      message: 'notifications.shopping_list.desc',
      messageArgs: {
        'count': uncheckedItemCount.toString(),
        'days': daysUntilReset.toString(),
      },
      dateTime: _formatTimestamp(createdAt),
      type: NotificationType.shoppingListReminder,
      isUnread: true,
    );
  }

  static NotificationModel overBudget({
    required num totalSpending,
    required num monthlyBudget,
    DateTime? createdAt,
  }) {
    return NotificationModel(
      title: 'notifications.over_budget.title',
      message: 'notifications.over_budget.desc',
      messageArgs: {
        'spent': _formatCurrency(totalSpending),
        'budget': _formatCurrency(monthlyBudget),
      },
      dateTime: _formatTimestamp(createdAt),
      type: NotificationType.overBudget,
      isUnread: true,
    );
  }

  static NotificationModel proSubscriptionExpiring({
    required int daysLeft,
    DateTime? createdAt,
  }) {
    return NotificationModel(
      title: 'notifications.pro_expiring.title',
      message: 'notifications.pro_expiring.desc',
      messageArgs: {'days': daysLeft.toString()},
      dateTime: _formatTimestamp(createdAt),
      type: NotificationType.proSubscriptionExpiring,
      isUnread: true,
    );
  }

  static NotificationModel pdfDownloadSuccess({DateTime? createdAt}) {
    return NotificationModel(
      title: 'notifications.pdf_success.title',
      message: 'notifications.pdf_success.desc',
      dateTime: _formatTimestamp(createdAt),
      type: NotificationType.pdfDownloadSuccess,
      isUnread: true,
    );
  }

  static NotificationModel favoritePriceDrop({
    required String productName,
    required num dropPercent,
    DateTime? createdAt,
  }) {
    return NotificationModel(
      title: 'notifications.favorite_price_drop.title',
      message: 'notifications.favorite_price_drop.desc',
      messageArgs: {
        'product': productName,
        'percent': _formatPercent(dropPercent),
      },
      dateTime: _formatTimestamp(createdAt),
      type: NotificationType.favoritePriceDrop,
      payload: productName,
      isUnread: true,
    );
  }

  static NotificationModel monthlySpendingComparison({
    required String lastMonthName,
    required String twoMonthsAgoName,
    required num lastMonthTotal,
    required num twoMonthsAgoTotal,
    DateTime? createdAt,
  }) {
    final isSaving = lastMonthTotal <= twoMonthsAgoTotal;
    final difference = (lastMonthTotal - twoMonthsAgoTotal).abs();
    return NotificationModel(
      title: isSaving
          ? 'notifications.monthly_comparison.saving_title'
          : 'notifications.monthly_comparison.overspent_title',
      message: isSaving
          ? 'notifications.monthly_comparison.saving_desc'
          : 'notifications.monthly_comparison.overspent_desc',
      messageArgs: {
        'lastMonth': lastMonthName,
        'twoMonthsAgo': twoMonthsAgoName,
        'lastTotal': _formatCurrency(lastMonthTotal),
        'previousTotal': _formatCurrency(twoMonthsAgoTotal),
        'difference': _formatCurrency(difference),
      },
      dateTime: _formatTimestamp(createdAt),
      type: NotificationType.monthlySpendingComparison,
      isUnread: true,
    );
  }

  static List<NotificationModel> mockNotifications({
    DateTime? now,
    String lastMonthName = 'February',
    String twoMonthsAgoName = 'January',
  }) {
    final base = now ?? DateTime.now();
    return <NotificationModel>[
      shoppingListReminder(
        uncheckedItemCount: 4,
        daysUntilReset: 3,
        createdAt: base.subtract(const Duration(minutes: 8)),
      ),
      overBudget(
        totalSpending: 1265000,
        monthlyBudget: 1200000,
        createdAt: base.subtract(const Duration(hours: 1)),
      ),
      proSubscriptionExpiring(
        daysLeft: 7,
        createdAt: base.subtract(const Duration(hours: 3)),
      ),
      pdfDownloadSuccess(createdAt: base.subtract(const Duration(hours: 5))),
      favoritePriceDrop(
        productName: 'Indomie Goreng',
        dropPercent: 12,
        createdAt: base.subtract(const Duration(days: 1, hours: 2)),
      ),
      monthlySpendingComparison(
        lastMonthName: lastMonthName,
        twoMonthsAgoName: twoMonthsAgoName,
        lastMonthTotal: 980000,
        twoMonthsAgoTotal: 1250000,
        createdAt: base.subtract(const Duration(days: 2)),
      ),
      monthlySpendingComparison(
        lastMonthName: lastMonthName,
        twoMonthsAgoName: twoMonthsAgoName,
        lastMonthTotal: 1375000,
        twoMonthsAgoTotal: 1120000,
        createdAt: base.subtract(const Duration(days: 3)),
      ),
    ];
  }

  static String _formatTimestamp(DateTime? value) {
    final date = value ?? DateTime.now();
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  static String _formatCurrency(num value) {
    final amount = value.round().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < amount.length; i++) {
      if (i > 0 && (amount.length - i) % 3 == 0) buffer.write('.');
      buffer.write(amount[i]);
    }
    return 'Rp $buffer';
  }

  static String _formatPercent(num value) {
    return value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(1);
  }
}
