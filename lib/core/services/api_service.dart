import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_constants.dart';

class ApiService {
  final Dio _dio;

  ApiService()
      : _dio = Dio(
          BaseOptions(
            baseUrl: AppConstants.backendBaseUrl,
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 10),
          ),
        ) {
    // Add interceptor to auto-inject Firebase ID token
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          try {
            final user = FirebaseAuth.instance.currentUser;
            if (user != null) {
              final token = await user.getIdToken().timeout(const Duration(seconds: 3));
              options.headers['Authorization'] = 'Bearer $token';
            }
          } catch (e) {
            // Log or ignore token fetch error for anonymous/non-authed requests
          }
          return handler.next(options);
        },
      ),
    );
  }

  // Common request wrappers
  Future<Response> get(String path, {Map<String, dynamic>? queryParameters}) async {
    try {
      return await _dio.get(path, queryParameters: queryParameters);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Response> post(String path, {dynamic data, Map<String, dynamic>? queryParameters}) async {
    try {
      return await _dio.post(path, data: data, queryParameters: queryParameters);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Response> put(String path, {dynamic data, Map<String, dynamic>? queryParameters}) async {
    try {
      return await _dio.put(path, data: data, queryParameters: queryParameters);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Response> delete(String path, {dynamic data, Map<String, dynamic>? queryParameters}) async {
    try {
      return await _dio.delete(path, data: data, queryParameters: queryParameters);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  // Convenience method for setting claims
  Future<bool> setUserClaims(String uid, String role, String companyId) async {
    try {
      final response = await post(
        '/api/auth/set-claims',
        data: {
          'uid': uid,
          'role': role,
          'companyId': companyId,
        },
      );
      return response.data != null && response.data['success'] == true;
    } catch (e) {
      return false;
    }
  }

  // Helper to handle and map DioErrors to user-friendly messages
  Exception _handleDioError(DioException error) {
    String message = 'An unexpected error occurred. Please try again.';
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      message = 'Connection timed out. Please check your internet connection.';
    } else if (error.type == DioExceptionType.badResponse) {
      final responseData = error.response?.data;
      if (responseData is Map && responseData.containsKey('error')) {
        message = responseData['error'].toString();
      } else if (error.response?.statusMessage != null) {
        message = error.response!.statusMessage!;
      } else {
        message = 'Server error (${error.response?.statusCode}).';
      }
    } else if (error.type == DioExceptionType.connectionError) {
      message = 'Failed to connect to the backend server. Please verify it is running.';
    }
    return Exception(message);
  }
}

final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService();
});
