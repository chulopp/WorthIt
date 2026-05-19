import 'dart:io';

import '../models/api/api_models.dart';
import '../services/api_client.dart';
import '../utils/image_compression.dart';
import 'repository_helpers.dart';

class ScannerRepository {
  ScannerRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient.instance;

  final ApiClient _apiClient;

  Future<ApiResult<ScanResultModel>> uploadReceipt(File image) {
    return _apiClient.run(() async {
      final uploadBytes = await compressedScanImageFileForUpload(image);
      final response = await _apiClient.uploadBytes(
        '/v1/scan',
        fieldName: 'file',
        fileBytes: uploadBytes,
        fileName: image.uri.pathSegments.isEmpty
            ? 'worthit_scan.jpg'
            : image.uri.pathSegments.last,
      );
      return ScanResultModel.fromJson(responseDataMap(response));
    });
  }

  Future<ApiResult<AnalyzeResponseModel>> analyzeProduct(
    AnalyzeRequestModel payload,
  ) {
    return _apiClient.run(() async {
      final response = await _apiClient.post(
        '/v1/analyze',
        data: payload.toJson(),
      );
      return AnalyzeResponseModel.fromJson(responseDataMap(response));
    });
  }
}
