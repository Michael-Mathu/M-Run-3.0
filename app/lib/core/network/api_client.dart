import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Base URL for the backend. Override at build/run time via
/// --dart-define=API_BASE_URL=https://api.mwendo.app
const String kApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:8080',
);

/// Whether the online features (account sign-in, cloud sync, leaderboard) are
/// offered. The default [kApiBaseUrl] is a local development server, so a
/// release build only shows them when a real backend was supplied with
/// --dart-define=API_BASE_URL=... . Without it the app is fully offline:
/// nothing about the user leaves the phone, and the store build has no
/// sign-in screen that cannot work.
const bool kBackendEnabled = bool.hasEnvironment('API_BASE_URL') || kDebugMode;

/// Thin Dio wrapper that attaches the stored auth token and reads/writes it.
class ApiClient {
  final Dio dio;

  ApiClient(this.dio);

  static const _tokenKey = 'auth_token';

  Future<String?> get token async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<void> setToken(String? token) async {
    final prefs = await SharedPreferences.getInstance();
    if (token == null) {
      await prefs.remove(_tokenKey);
    } else {
      await prefs.setString(_tokenKey, token);
    }
  }

  Future<void> clearToken() => setToken(null);
}

final apiClientProvider = Provider<ApiClient>((ref) {
  final dio = Dio(BaseOptions(
    baseUrl: kApiBaseUrl,
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 8),
  ));
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) async {
      final token = await SharedPreferences.getInstance()
          .then((p) => p.getString(ApiClient._tokenKey));
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      handler.next(options);
    },
  ));
  return ApiClient(dio);
});
