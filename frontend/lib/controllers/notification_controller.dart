import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/notification_model.dart';
import '../services/notification_service.dart';

final notificationControllerProvider =
    AsyncNotifierProvider<NotificationController, List<NotificationModel>>(
      NotificationController.new,
    );

class NotificationController extends AsyncNotifier<List<NotificationModel>> {
  @override
  FutureOr<List<NotificationModel>> build() async {
    final service = NotificationService();

    void listener() {
      state = AsyncValue.data(service.notifications.value);
    }

    service.notifications.addListener(listener);
    ref.onDispose(() {
      service.notifications.removeListener(listener);
    });

    // Simulate initial loading time
    await Future.delayed(const Duration(milliseconds: 800));

    return service.notifications.value;
  }
}
