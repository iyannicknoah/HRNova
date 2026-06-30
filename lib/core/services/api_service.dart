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
    receiveTimeout: const Duration(seconds: 30),
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

  Future<Response> get(String path, {Map<String, dynamic>? params}) async {
    final token = await _getToken();
    try {
      return await _dio.get(path,
          queryParameters: params, options: _authOptions(token));
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<Response> post(String path, {dynamic data}) async {
    final token = await _getToken();
    try {
      return await _dio.post(path, data: data, options: _authOptions(token));
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<Response> put(String path, {dynamic data}) async {
    final token = await _getToken();
    try {
      return await _dio.put(path, data: data, options: _authOptions(token));
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<Response> delete(String path) async {
    final token = await _getToken();
    try {
      return await _dio.delete(path, options: _authOptions(token));
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<Response> postMultipart(String path, FormData formData) async {
    final token = await _getToken();
    try {
      return await _dio.post(
        path,
        data: formData,
        options: Options(headers: {
          if (token != null) 'Authorization': 'Bearer $token',
          'Content-Type': 'multipart/form-data',
        }),
      );
    } on DioException catch (e) {
      throw _mapError(e);
    }
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
