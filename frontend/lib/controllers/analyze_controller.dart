import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/api/api_models.dart';
import 'controller_helpers.dart';
import 'controller_state.dart';
import 'repository_providers.dart';

final analyzeControllerProvider =
    NotifierProvider<AnalyzeController, AnalyzeState>(AnalyzeController.new);

class AnalyzeController extends Notifier<AnalyzeState> {
  @override
  AnalyzeState build() {
    return const AnalyzeState();
  }

  Future<void> scanReceipt(File image) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final result = await ref
          .read(scannerRepositoryProvider)
          .uploadReceipt(image);
      if (result.isFailure) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: apiErrorMessage(result.error),
        );
        return;
      }

      final scan = result.requireData;
      state = state.copyWith(
        isLoading: false,
        errorMessage: null,
        scanResult: scan,
        dbProductId: scan.dbProductId,
        scannedPrice: scan.scannedPrice.toDouble(),
        weightGram: scan.weightGram.toDouble(),
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: unexpectedErrorMessage(error),
      );
    }
  }

  void setUrgency(int level) {
    state = state.copyWith(urgency: level.clamp(1, 3).toInt());
  }

  void setManualScan({
    required String productId,
    required double scannedPrice,
    required double weightGram,
  }) {
    state = state.copyWith(
      errorMessage: null,
      dbProductId: productId,
      scannedPrice: scannedPrice,
      weightGram: weightGram,
      data: null,
      purchase: null,
    );
  }

  Future<void> analyzeProduct() async {
    final productId = state.dbProductId;
    final scannedPrice = state.scannedPrice;
    final weightGram = state.weightGram;

    if (productId == null ||
        productId.isEmpty ||
        scannedPrice == null ||
        scannedPrice <= 0 ||
        weightGram == null ||
        weightGram <= 0) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Data hasil scan belum lengkap untuk dianalisis.',
      );
      return;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final result = await ref
          .read(scannerRepositoryProvider)
          .analyzeProduct(
            AnalyzeRequestModel(
              dbProductId: productId,
              scannedPrice: scannedPrice,
              weightGram: weightGram,
              urgency: state.urgency,
            ),
          );
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

  Future<void> buyProduct({int quantity = 1}) async {
    final analysis = state.data;
    if (analysis == null) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Belum ada hasil analisis untuk dicatat sebagai beli.',
      );
      return;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final result = await ref
          .read(historyRepositoryProvider)
          .createPurchase(
            productId: analysis.productId,
            purchasedPrice: analysis.scannedPrice.round(),
            quantity: quantity,
          );
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
        purchase: result.requireData,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: unexpectedErrorMessage(error),
      );
    }
  }
}
