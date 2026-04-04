import 'package:dio/dio.dart';

class AuthInterceptor extends Interceptor {
  final String Function() getToken;

  AuthInterceptor({required this.getToken});

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = getToken();
    if (token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401) {
      // Token expired - will be handled by auth provider
    }
    handler.next(err);
  }
}
