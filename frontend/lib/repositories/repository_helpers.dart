import 'package:dio/dio.dart';

import '../models/api/api_models.dart';

JsonMap responseMap(Response<dynamic> response) {
  final data = response.data;
  if (data is Map<String, dynamic>) return data;
  if (data is Map) return Map<String, dynamic>.from(data);
  return <String, dynamic>{};
}

JsonMap responseDataMap(Response<dynamic> response) {
  final map = responseMap(response);
  final data = map['data'];
  if (data is Map<String, dynamic>) return data;
  if (data is Map) return Map<String, dynamic>.from(data);
  return <String, dynamic>{};
}

List<JsonMap> responseDataList(Response<dynamic> response) {
  final map = responseMap(response);
  final data = map['data'];
  if (data is! List) return <JsonMap>[];
  return data
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList(growable: false);
}
