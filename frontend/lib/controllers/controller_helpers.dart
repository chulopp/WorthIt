import '../services/api_client.dart';

String apiErrorMessage(ApiException? error) {
  return error?.message ?? 'Terjadi kesalahan. Coba lagi.';
}

String unexpectedErrorMessage(Object error) {
  if (error is ApiException) return error.message;
  return 'Terjadi kesalahan yang tidak diketahui.';
}
