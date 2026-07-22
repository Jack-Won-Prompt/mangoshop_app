import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'config.dart';

/// 토큰 저장소 (Sanctum personal access token)
final tokenStorageProvider = Provider((_) => const FlutterSecureStorage());

class ApiException implements Exception {
  final String message;
  final int? status;
  final Map<String, dynamic>? errors;
  ApiException(this.message, {this.status, this.errors});

  /// 첫 번째 필드 검증 오류 메시지
  String get firstError {
    if (errors != null && errors!.isNotEmpty) {
      final v = errors!.values.first;
      if (v is List && v.isNotEmpty) return v.first.toString();
    }
    return message;
  }

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient(this._storage) {
    _dio = Dio(BaseOptions(
      baseUrl: AppConfig.apiBase,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      headers: {'Accept': 'application/json'},
      // 4xx 도 예외로 던지지 않고 우리가 처리
      validateStatus: (s) => s != null && s < 500,
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: _tokenKey);
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
    ));
  }

  static const _tokenKey = 'auth_token';
  final FlutterSecureStorage _storage;
  late final Dio _dio;

  Future<String?> get token => _storage.read(key: _tokenKey);
  Future<void> saveToken(String token) => _storage.write(key: _tokenKey, value: token);
  Future<void> clearToken() => _storage.delete(key: _tokenKey);

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _request(() => _dio.get(path, queryParameters: query));

  Future<dynamic> post(String path, {dynamic data}) =>
      _request(() => _dio.post(path, data: data));

  Future<dynamic> put(String path, {dynamic data}) =>
      _request(() => _dio.put(path, data: data));

  Future<dynamic> delete(String path, {dynamic data}) =>
      _request(() => _dio.delete(path, data: data));

  Future<dynamic> _request(Future<Response> Function() run) async {
    try {
      final res = await run();
      final code = res.statusCode ?? 0;
      if (code >= 200 && code < 300) return res.data;

      final data = res.data;
      String msg = '요청을 처리할 수 없습니다.';
      Map<String, dynamic>? errors;
      if (data is Map) {
        msg = (data['message'] ?? msg).toString();
        if (data['errors'] is Map) errors = Map<String, dynamic>.from(data['errors']);
      }
      throw ApiException(msg, status: code, errors: errors);
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw ApiException(
        e.type == DioExceptionType.connectionError || e.type == DioExceptionType.connectionTimeout
            ? '서버에 연결할 수 없습니다. 네트워크를 확인해주세요.'
            : '네트워크 오류가 발생했습니다.',
      );
    }
  }
}

final apiProvider = Provider<ApiClient>((ref) {
  return ApiClient(ref.read(tokenStorageProvider));
});
