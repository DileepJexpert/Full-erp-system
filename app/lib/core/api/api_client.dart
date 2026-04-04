import 'package:dio/dio.dart';
import 'auth_interceptor.dart';
import '../../config/constants.dart';

class ApiClient {
  late final Dio dio;

  ApiClient({required String Function() getToken}) {
    dio = Dio(BaseOptions(
      baseUrl: AppConstants.apiBaseUrl,
      connectTimeout: AppConstants.apiTimeout,
      receiveTimeout: AppConstants.apiTimeout,
      headers: {'Content-Type': 'application/json'},
    ));
    dio.interceptors.add(AuthInterceptor(getToken: getToken));
    dio.interceptors.add(LogInterceptor(requestBody: true, responseBody: true));
  }

  Future<Response<T>> get<T>(String path, {Map<String, dynamic>? queryParameters}) {
    return dio.get<T>(path, queryParameters: queryParameters);
  }

  Future<Response<T>> post<T>(String path, {dynamic data}) {
    return dio.post<T>(path, data: data);
  }

  Future<Response<T>> put<T>(String path, {dynamic data}) {
    return dio.put<T>(path, data: data);
  }

  Future<Response<T>> patch<T>(String path, {dynamic data}) {
    return dio.patch<T>(path, data: data);
  }

  Future<Response<T>> delete<T>(String path) {
    return dio.delete<T>(path);
  }
}
