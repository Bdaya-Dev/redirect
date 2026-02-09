import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:redirect/redirect.dart';
import 'package:redirect_platform_interface/redirect_platform_interface.dart'
    as platform;

class MockRedirectPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements platform.RedirectPlatform {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockRedirectPlatform mockPlatform;

  setUpAll(() {
    registerFallbackValue(Uri());
    registerFallbackValue(const RedirectOptions());
  });

  setUp(() {
    mockPlatform = MockRedirectPlatform();
    platform.RedirectPlatform.instance = mockPlatform;
  });

  group('runRedirect', () {
    final testUrl = Uri.parse('https://auth.example.com/authorize');
    const callbackScheme = 'myapp';
    final successUri = Uri.parse('myapp://callback?code=abc123');

    test('delegates to platform instance', () async {
      when(
        () => mockPlatform.run(
          url: any(named: 'url'),
          callbackUrlScheme: any(named: 'callbackUrlScheme'),
          options: any(named: 'options'),
        ),
      ).thenReturn(RedirectHandle(
        url: testUrl,
        callbackUrlScheme: callbackScheme,
        result: Future.value(RedirectSuccess(uri: successUri)),
        cancel: () async {},
      ));

      final handle = runRedirect(
        url: testUrl,
        callbackUrlScheme: callbackScheme,
      );
      final result = await handle.result;

      expect(result, isA<RedirectSuccess>());
      expect((result as RedirectSuccess).uri, equals(successUri));

      verify(
        () => mockPlatform.run(
          url: testUrl,
          callbackUrlScheme: callbackScheme,
          options: any(named: 'options'),
        ),
      ).called(1);
    });

    test('passes options to platform', () async {
      when(
        () => mockPlatform.run(
          url: any(named: 'url'),
          callbackUrlScheme: any(named: 'callbackUrlScheme'),
          options: any(named: 'options'),
        ),
      ).thenReturn(RedirectHandle(
        url: testUrl,
        callbackUrlScheme: callbackScheme,
        result: Future.value(const RedirectCancelled()),
        cancel: () async {},
      ));

      const options = RedirectOptions(
        timeout: Duration(seconds: 30),
        preferEphemeral: true,
      );

      runRedirect(
        url: testUrl,
        callbackUrlScheme: callbackScheme,
        options: options,
      );

      verify(
        () => mockPlatform.run(
          url: testUrl,
          callbackUrlScheme: callbackScheme,
          options: options,
        ),
      ).called(1);
    });

    test('returns RedirectCancelled from platform', () async {
      when(
        () => mockPlatform.run(
          url: any(named: 'url'),
          callbackUrlScheme: any(named: 'callbackUrlScheme'),
          options: any(named: 'options'),
        ),
      ).thenReturn(RedirectHandle(
        url: testUrl,
        callbackUrlScheme: callbackScheme,
        result: Future.value(const RedirectCancelled()),
        cancel: () async {},
      ));

      final handle = runRedirect(
        url: testUrl,
        callbackUrlScheme: callbackScheme,
      );
      final result = await handle.result;

      expect(result, isA<RedirectCancelled>());
    });

    test('returns RedirectFailure from platform', () async {
      final error = Exception('Network error');
      when(
        () => mockPlatform.run(
          url: any(named: 'url'),
          callbackUrlScheme: any(named: 'callbackUrlScheme'),
          options: any(named: 'options'),
        ),
      ).thenReturn(RedirectHandle(
        url: testUrl,
        callbackUrlScheme: callbackScheme,
        result: Future.value(RedirectFailure(error: error)),
        cancel: () async {},
      ));

      final handle = runRedirect(
        url: testUrl,
        callbackUrlScheme: callbackScheme,
      );
      final result = await handle.result;

      expect(result, isA<RedirectFailure>());
      expect((result as RedirectFailure).error, equals(error));
    });

    test('returns RedirectPending from platform', () async {
      when(
        () => mockPlatform.run(
          url: any(named: 'url'),
          callbackUrlScheme: any(named: 'callbackUrlScheme'),
          options: any(named: 'options'),
        ),
      ).thenReturn(RedirectHandle(
        url: testUrl,
        callbackUrlScheme: callbackScheme,
        result: Future.value(const RedirectPending()),
        cancel: () async {},
      ));

      final handle = runRedirect(
        url: testUrl,
        callbackUrlScheme: callbackScheme,
      );
      final result = await handle.result;

      expect(result, isA<RedirectPending>());
    });
  });
}
