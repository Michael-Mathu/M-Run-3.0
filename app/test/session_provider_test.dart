import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mwendo_app/core/network/api_client.dart';
import 'package:mwendo_app/core/network/session_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Regression coverage for SEC-9: Session._errMessage previously returned
// null for any DioException it didn't specifically recognize (timeouts,
// connection errors, unexpected error bodies) -- and auth_page.dart treats
// a null return as "login succeeded" and dismisses the auth sheet. A
// network outage during login looked identical to a successful one.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Dio dioThatAlwaysThrows(DioExceptionType type) {
    final dio = Dio(BaseOptions(baseUrl: 'http://example.invalid'));
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        handler.reject(DioException(requestOptions: options, type: type));
      },
    ));
    return dio;
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('login() never returns null on a connection error (previously did)', () async {
    final container = ProviderContainer(overrides: [
      apiClientProvider.overrideWithValue(ApiClient(dioThatAlwaysThrows(DioExceptionType.connectionError))),
    ]);
    addTearDown(container.dispose);

    final err = await container.read(sessionProvider.notifier).login('a@b.com', 'password123');

    expect(err, isNotNull);
    expect(container.read(sessionProvider).isAnonymous, isTrue,
        reason: 'a failed login must not leave the session looking signed-in');
  });

  test('login() never returns null on a connection timeout (previously did)', () async {
    final container = ProviderContainer(overrides: [
      apiClientProvider.overrideWithValue(ApiClient(dioThatAlwaysThrows(DioExceptionType.connectionTimeout))),
    ]);
    addTearDown(container.dispose);

    final err = await container.read(sessionProvider.notifier).login('a@b.com', 'password123');

    expect(err, isNotNull);
    expect(container.read(sessionProvider).isAnonymous, isTrue);
  });

  test('login() never returns null on an unrecognized 500 response (previously did)', () async {
    final dio = Dio(BaseOptions(baseUrl: 'http://example.invalid'));
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        handler.reject(DioException(
          requestOptions: options,
          type: DioExceptionType.badResponse,
          response: Response(requestOptions: options, statusCode: 500, data: 'internal error'),
        ));
      },
    ));
    final container = ProviderContainer(overrides: [
      apiClientProvider.overrideWithValue(ApiClient(dio)),
    ]);
    addTearDown(container.dispose);

    final err = await container.read(sessionProvider.notifier).login('a@b.com', 'password123');

    expect(err, isNotNull);
  });

  test('login() still returns the specific message for a recognized 401 with no error body', () async {
    final dio = Dio(BaseOptions(baseUrl: 'http://example.invalid'));
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        handler.reject(DioException(
          requestOptions: options,
          type: DioExceptionType.badResponse,
          response: Response(requestOptions: options, statusCode: 401),
        ));
      },
    ));
    final container = ProviderContainer(overrides: [
      apiClientProvider.overrideWithValue(ApiClient(dio)),
    ]);
    addTearDown(container.dispose);

    final err = await container.read(sessionProvider.notifier).login('a@b.com', 'password123');
    expect(err, 'Invalid email or password');
  });

  test('login() prefers a server-supplied {"error": ...} body over the generic 401 message', () async {
    final dio = Dio(BaseOptions(baseUrl: 'http://example.invalid'));
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        handler.reject(DioException(
          requestOptions: options,
          type: DioExceptionType.badResponse,
          response: Response(requestOptions: options, statusCode: 401, data: {'error': 'invalid'}),
        ));
      },
    ));
    final container = ProviderContainer(overrides: [
      apiClientProvider.overrideWithValue(ApiClient(dio)),
    ]);
    addTearDown(container.dispose);

    final err = await container.read(sessionProvider.notifier).login('a@b.com', 'password123');
    expect(err, 'invalid');
  });
}
