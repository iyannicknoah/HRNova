import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../constants/app_constants.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  final Dio _dio = Dio(BaseOptions(
    baseUrl: AppConstants.backendBaseUrl,
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 120),
    headers: {'Content-Type': 'application/json'},
  ));

  Future<String?> _getToken() async {
    return FirebaseAuth.instance.currentUser?.getIdToken();
  }

  Options _authOptions(String? token) => Options(
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

  /// Retries a request when it fails with a connection error — the dev
  /// backend restarts on every file save (`node --watch`), which briefly
  /// drops connections for a few hundred milliseconds. A request that lands
  /// in that window would otherwise surface as "cannot reach the server"
  /// even though the server is actually up a moment later. Only retries
  /// connectionError (refused/reset) — never timeouts or HTTP error
  /// responses, since those aren't transient in the same way.
  Future<Response> _withRetry(Future<Response> Function() request) async {
    const maxAttempts = 3;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        return await request();
      } on DioException catch (e) {
        final isLastAttempt = attempt == maxAttempts;
        if (e.type != DioExceptionType.connectionError || isLastAttempt) {
          throw _mapError(e);
        }
        await Future.delayed(Duration(milliseconds: 400 * attempt));
      }
    }
    // Unreachable — the loop always returns or throws.
    throw Exception('Something went wrong.');
  }

  Future<Response> get(String path, {Map<String, dynamic>? params}) async {
    final token = await _getToken();
    return _withRetry(() => _dio.get(path,
        queryParameters: params, options: _authOptions(token)));
  }

  Future<Response> post(String path, {dynamic data}) async {
    final token = await _getToken();
    return _withRetry(
        () => _dio.post(path, data: data, options: _authOptions(token)));
  }

  Future<Response> put(String path, {dynamic data}) async {
    final token = await _getToken();
    return _withRetry(
        () => _dio.put(path, data: data, options: _authOptions(token)));
  }

  Future<Response> delete(String path, {dynamic data}) async {
    final token = await _getToken();
    return _withRetry(
        () => _dio.delete(path, data: data, options: _authOptions(token)));
  }

  Future<List<int>> getBytes(String path, {Map<String, dynamic>? params}) async {
    final token = await _getToken();
    final response = await _withRetry(() => _dio.get<List<int>>(
          path,
          queryParameters: params,
          options: Options(
            responseType: ResponseType.bytes,
            headers: {
              if (token != null) 'Authorization': 'Bearer $token',
            },
          ),
        ));
    return response.data as List<int>? ?? [];
  }

  Future<Response> postMultipart(String path, FormData formData) async {
    final token = await _getToken();
    return _withRetry(() => _dio.post(
          path,
          data: formData,
          options: Options(headers: {
            if (token != null) 'Authorization': 'Bearer $token',
            'Content-Type': 'multipart/form-data',
          }),
        ));
  }

  Exception _mapError(DioException e) {
    final statusCode = e.response?.statusCode;
    final serverMsg = e.response?.data?['error'] as String?;

    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return Exception(
          'Connection timed out. Please check your network and try again.');
    }
    if (e.type == DioExceptionType.connectionError) {
      return Exception(
          'Cannot reach the server. Make sure the backend is running.');
    }
    if (statusCode == 401) {
      return Exception('Session expired. Please sign in again.');
    }
    if (statusCode == 403) {
      return Exception("You don't have permission to do that.");
    }
    if (statusCode == 404) {
      return Exception('Resource not found.');
    }
    if (statusCode != null && statusCode >= 500) {
      return Exception(serverMsg ?? 'Server error. Please try again.');
    }
    return Exception(serverMsg ?? e.message ?? 'Something went wrong.');
  }
}
