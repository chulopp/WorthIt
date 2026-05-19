import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/api/api_models.dart';
import 'controller_helpers.dart';
import 'controller_state.dart';
import 'repository_providers.dart';

final trackerControllerProvider =
    NotifierProvider<TrackerController, BaseControllerState<TrackerModel>>(
      TrackerController.new,
    );

class TrackerController extends Notifier<BaseControllerState<TrackerModel>> {
  @override
  BaseControllerState<TrackerModel> build() {
    return const BaseControllerState<TrackerModel>();
  }

  Future<void> fetchTracker({String? month}) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final result = await ref
          .read(trackerRepositoryProvider)
          .getTracker(month: month);
      if (result.isFailure) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: apiErrorMessage(result.error),
        );
        return;
      }

      state = state.copyWith(
        isLoading: false,
        errorMessage: null,
        data: result.requireData,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: unexpectedErrorMessage(error),
      );
    }
  }
}
