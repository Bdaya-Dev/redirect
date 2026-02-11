import 'dart:async';

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
    final successUri = Uri.parse('myapp://callback?code=abc123');

    test('delegates to platform instance', () async {
      when(
        () => mockPlatform.run(
          url: any(named: 'url'),
          options: any(named: 'options'),
        ),
      ).thenReturn(
        RedirectHandle(
          url: testUrl,
          result: Future.value(RedirectSuccess(uri: successUri)),
          cancel: () async {},
        ),
      );

      final handle = runRedirect(url: testUrl);
      final result = await handle.result;

      expect(result, isA<RedirectSuccess>());
      expect((result as RedirectSuccess).uri, equals(successUri));

      verify(
        () => mockPlatform.run(
          url: testUrl,
          options: any(named: 'options'),
        ),
      ).called(1);
    });

    test('passes options to platform', () async {
      when(
        () => mockPlatform.run(
          url: any(named: 'url'),
          options: any(named: 'options'),
        ),
      ).thenReturn(
        RedirectHandle(
          url: testUrl,
          result: Future.value(const RedirectCancelled()),
          cancel: () async {},
        ),
      );

      const options = RedirectOptions(
        timeout: Duration(seconds: 30),
      );

      runRedirect(url: testUrl, options: options);

      verify(
        () => mockPlatform.run(
          url: testUrl,
          options: options,
        ),
      ).called(1);
    });

    test('returns RedirectCancelled from platform', () async {
      when(
        () => mockPlatform.run(
          url: any(named: 'url'),
          options: any(named: 'options'),
        ),
      ).thenReturn(
        RedirectHandle(
          url: testUrl,
          result: Future.value(const RedirectCancelled()),
          cancel: () async {},
        ),
      );

      final handle = runRedirect(url: testUrl);
      final result = await handle.result;

      expect(result, isA<RedirectCancelled>());
    });

    test('returns RedirectFailure from platform', () async {
      final error = Exception('Network error');
      when(
        () => mockPlatform.run(
          url: any(named: 'url'),
          options: any(named: 'options'),
        ),
      ).thenReturn(
        RedirectHandle(
          url: testUrl,
          result: Future.value(RedirectFailure(error: error)),
          cancel: () async {},
        ),
      );

      final handle = runRedirect(url: testUrl);
      final result = await handle.result;

      expect(result, isA<RedirectFailure>());
      expect((result as RedirectFailure).error, equals(error));
    });

    test('returns RedirectPending from platform', () async {
      when(
        () => mockPlatform.run(
          url: any(named: 'url'),
          options: any(named: 'options'),
        ),
      ).thenReturn(
        RedirectHandle(
          url: testUrl,
          result: Future.value(const RedirectPending()),
          cancel: () async {},
        ),
      );

      final handle = runRedirect(url: testUrl);
      final result = await handle.result;

      expect(result, isA<RedirectPending>());
    });

    test('multiple concurrent handles each resolve independently', () async {
      var callCount = 0;

      when(
        () => mockPlatform.run(
          url: any(named: 'url'),
          options: any(named: 'options'),
        ),
      ).thenAnswer((_) {
        callCount++;
        final code = 'code_$callCount';
        return RedirectHandle(
          url: testUrl,
          result: Future.value(
            RedirectSuccess(
              uri: Uri.parse('myapp://callback?code=$code'),
            ),
          ),
          cancel: () async {},
        );
      });

      final handle1 = runRedirect(url: testUrl);
      final handle2 = runRedirect(url: testUrl);
      final handle3 = runRedirect(url: testUrl);

      final results = await Future.wait([
        handle1.result,
        handle2.result,
        handle3.result,
      ]);

      expect(results, hasLength(3));
      expect(results[0], isA<RedirectSuccess>());
      expect(results[1], isA<RedirectSuccess>());
      expect(results[2], isA<RedirectSuccess>());

      // Each handle should have a distinct code
      final codes = results
          .whereType<RedirectSuccess>()
          .map((r) => r.uri.queryParameters['code'])
          .toSet();
      expect(codes, hasLength(3));

      verify(
        () => mockPlatform.run(
          url: any(named: 'url'),
          options: any(named: 'options'),
        ),
      ).called(3);
    });

    test('cancelling one handle does not affect another', () async {
      final cancelled = <int>{};

      when(
        () => mockPlatform.run(
          url: any(named: 'url'),
          options: any(named: 'options'),
        ),
      ).thenAnswer((_) {
        final completer = Completer<RedirectResult>();
        final handleIndex = cancelled.length + 1;

        return RedirectHandle(
          url: testUrl,
          result: completer.future,
          cancel: () async {
            cancelled.add(handleIndex);
            if (!completer.isCompleted) {
              completer.complete(const RedirectCancelled());
            }
          },
        );
      });

      final handle1 = runRedirect(url: testUrl);
      final handle2 = runRedirect(url: testUrl);

      // Cancel only handle1
      await handle1.cancel();

      final result1 = await handle1.result;
      expect(result1, isA<RedirectCancelled>());
      expect(cancelled, contains(1));
      expect(cancelled, isNot(contains(2)));

      // handle2 should still be active — cancel it for cleanup
      await handle2.cancel();
      final result2 = await handle2.result;
      expect(result2, isA<RedirectCancelled>());
    });

    test('handles with different platform options work concurrently', () async {
      when(
        () => mockPlatform.run(
          url: any(named: 'url'),
          options: any(named: 'options'),
        ),
      ).thenAnswer((invocation) {
        return RedirectHandle(
          url: testUrl,
          result: Future.value(
            RedirectSuccess(uri: successUri),
          ),
          cancel: () async {},
        );
      });

      final handleA = runRedirect(url: testUrl);
      final handleB = runRedirect(url: testUrl);

      final resultA = await handleA.result;
      final resultB = await handleB.result;

      expect(resultA, isA<RedirectSuccess>());
      expect(resultB, isA<RedirectSuccess>());
    });

    test('web platform options can be passed', () async {
      when(
        () => mockPlatform.run(
          url: any(named: 'url'),
          options: any(named: 'options'),
        ),
      ).thenReturn(
        RedirectHandle(
          url: testUrl,
          result: Future.value(RedirectSuccess(uri: successUri)),
          cancel: () async {},
        ),
      );

      final handle = runRedirect(
        url: testUrl,
        options: const RedirectOptions(
          platformOptions: {
            WebRedirectOptions.key: WebRedirectOptions(
              mode: WebRedirectMode.iframe,
              popupOptions: PopupOptions(
                width: 400,
                height: 600,
              ),
            ),
          },
        ),
      );

      final result = await handle.result;
      expect(result, isA<RedirectSuccess>());

      verify(
        () => mockPlatform.run(
          url: testUrl,
          options: any(named: 'options'),
        ),
      ).called(1);
    });
  });

  group('RedirectHandle', () {
    test('exposes all constructor parameters', () {
      final handle = RedirectHandle(
        url: Uri.parse('https://example.com/auth'),
        options: const RedirectOptions(
          timeout: Duration(seconds: 30),
        ),
        result: Future.value(const RedirectCancelled()),
        cancel: () async {},
      );

      expect(handle.url, equals(Uri.parse('https://example.com/auth')));
      expect(handle.options.timeout, equals(const Duration(seconds: 30)));
    });

    test('auto-generates a unique nonce', () {
      final handle1 = RedirectHandle(
        url: Uri.parse('https://example.com/auth'),
        result: Future.value(const RedirectCancelled()),
        cancel: () async {},
      );
      final handle2 = RedirectHandle(
        url: Uri.parse('https://example.com/auth'),
        result: Future.value(const RedirectCancelled()),
        cancel: () async {},
      );

      expect(handle1.nonce, isNotEmpty);
      expect(handle2.nonce, isNotEmpty);
      expect(handle1.nonce, isNot(equals(handle2.nonce)));
    });

    test('accepts an explicit nonce', () {
      final handle = RedirectHandle(
        url: Uri.parse('https://example.com/auth'),
        nonce: 'my-custom-nonce',
        result: Future.value(const RedirectCancelled()),
        cancel: () async {},
      );

      expect(handle.nonce, equals('my-custom-nonce'));
    });

    test('cancel completes result with RedirectCancelled', () async {
      final completer = Completer<RedirectResult>();

      final handle = RedirectHandle(
        url: Uri.parse('https://example.com/auth'),
        result: completer.future,
        cancel: () async {
          if (!completer.isCompleted) {
            completer.complete(const RedirectCancelled());
          }
        },
      );

      await handle.cancel();
      final result = await handle.result;
      expect(result, isA<RedirectCancelled>());
    });

    test('double-cancel is idempotent', () async {
      var cancelCount = 0;
      final completer = Completer<RedirectResult>();

      final handle = RedirectHandle(
        url: Uri.parse('https://example.com/auth'),
        result: completer.future,
        cancel: () async {
          cancelCount++;
          if (!completer.isCompleted) {
            completer.complete(const RedirectCancelled());
          }
        },
      );

      await handle.cancel();
      await handle.cancel();
      await handle.cancel();

      final result = await handle.result;
      expect(result, isA<RedirectCancelled>());
      expect(cancelCount, equals(3)); // cancel() called 3 times
    });
  });

  group('constructRedirectUrl', () {
    tearDown(() {
      debugRedirectPlatformTypeOverride = null;
    });

    final fallbackUrl = Uri.parse('https://example.com/fallback');
    final androidUrl = Uri.parse('https://example.com/android');
    final iosUrl = Uri.parse('https://example.com/ios');
    final macosUrl = Uri.parse('https://example.com/macos');
    final darwinUrl = Uri.parse('https://example.com/darwin');
    final linuxUrl = Uri.parse('https://example.com/linux');
    final windowsUrl = Uri.parse('https://example.com/windows');
    final desktopUrl = Uri.parse('https://example.com/desktop');
    final webUrl = Uri.parse('https://example.com/web');
    final mobileUrl = Uri.parse('https://example.com/mobile');

    test('uses fallback when no platform-specific builder is provided', () {
      debugRedirectPlatformTypeOverride = RedirectPlatformType.android;

      final (:url, :options) = constructRedirectUrl(
        fallback: (_) => RedirectUrlConfig(url: fallbackUrl),
      );

      expect(url, equals(fallbackUrl));
      expect(options.platformOptions, isEmpty);
    });

    group('Android resolution: onAndroid > onMobile > fallback', () {
      setUp(() {
        debugRedirectPlatformTypeOverride = RedirectPlatformType.android;
      });

      test('uses onAndroid when provided', () {
        final (:url, options: _) = constructRedirectUrl(
          fallback: (_) => RedirectUrlConfig(url: fallbackUrl),
          onAndroid: (_) => RedirectUrlConfig(url: androidUrl),
          onMobile: (_) => RedirectUrlConfig(url: mobileUrl),
        );

        expect(url, equals(androidUrl));
      });

      test('falls back to onMobile', () {
        final (:url, options: _) = constructRedirectUrl(
          fallback: (_) => RedirectUrlConfig(url: fallbackUrl),
          onMobile: (_) => RedirectUrlConfig(url: mobileUrl),
        );

        expect(url, equals(mobileUrl));
      });

      test('falls back to fallback', () {
        final (:url, options: _) = constructRedirectUrl(
          fallback: (_) => RedirectUrlConfig(url: fallbackUrl),
        );

        expect(url, equals(fallbackUrl));
      });
    });

    group('iOS resolution: onIos > onDarwin > onMobile > fallback', () {
      setUp(() {
        debugRedirectPlatformTypeOverride = RedirectPlatformType.ios;
      });

      test('uses onIos when provided', () {
        final (:url, options: _) = constructRedirectUrl(
          fallback: (_) => RedirectUrlConfig(url: fallbackUrl),
          onIos: (_) => RedirectUrlConfig(url: iosUrl),
          onDarwin: (_) => RedirectUrlConfig(url: darwinUrl),
          onMobile: (_) => RedirectUrlConfig(url: mobileUrl),
        );

        expect(url, equals(iosUrl));
      });

      test('falls back to onDarwin', () {
        final (:url, options: _) = constructRedirectUrl(
          fallback: (_) => RedirectUrlConfig(url: fallbackUrl),
          onDarwin: (_) => RedirectUrlConfig(url: darwinUrl),
          onMobile: (_) => RedirectUrlConfig(url: mobileUrl),
        );

        expect(url, equals(darwinUrl));
      });

      test('falls back to onMobile', () {
        final (:url, options: _) = constructRedirectUrl(
          fallback: (_) => RedirectUrlConfig(url: fallbackUrl),
          onMobile: (_) => RedirectUrlConfig(url: mobileUrl),
        );

        expect(url, equals(mobileUrl));
      });

      test('falls back to fallback', () {
        final (:url, options: _) = constructRedirectUrl(
          fallback: (_) => RedirectUrlConfig(url: fallbackUrl),
        );

        expect(url, equals(fallbackUrl));
      });
    });

    group('macOS resolution: onMacos > onDarwin > fallback', () {
      setUp(() {
        debugRedirectPlatformTypeOverride = RedirectPlatformType.macos;
      });

      test('uses onMacos when provided', () {
        final (:url, options: _) = constructRedirectUrl(
          fallback: (_) => RedirectUrlConfig(url: fallbackUrl),
          onMacos: (_) => RedirectUrlConfig(url: macosUrl),
          onDarwin: (_) => RedirectUrlConfig(url: darwinUrl),
        );

        expect(url, equals(macosUrl));
      });

      test('falls back to onDarwin', () {
        final (:url, options: _) = constructRedirectUrl(
          fallback: (_) => RedirectUrlConfig(url: fallbackUrl),
          onDarwin: (_) => RedirectUrlConfig(url: darwinUrl),
        );

        expect(url, equals(darwinUrl));
      });

      test('does not fall back to onMobile', () {
        final (:url, options: _) = constructRedirectUrl(
          fallback: (_) => RedirectUrlConfig(url: fallbackUrl),
          onMobile: (_) => RedirectUrlConfig(url: mobileUrl),
        );

        expect(url, equals(fallbackUrl));
      });
    });

    group('Linux resolution: onLinux > onDesktop > fallback', () {
      setUp(() {
        debugRedirectPlatformTypeOverride = RedirectPlatformType.linux;
      });

      test('uses onLinux when provided', () {
        final (:url, options: _) = constructRedirectUrl(
          fallback: (_) => RedirectUrlConfig(url: fallbackUrl),
          onLinux: (_) => RedirectUrlConfig(url: linuxUrl),
          onDesktop: (_) => RedirectUrlConfig(url: desktopUrl),
        );

        expect(url, equals(linuxUrl));
      });

      test('falls back to onDesktop', () {
        final (:url, options: _) = constructRedirectUrl(
          fallback: (_) => RedirectUrlConfig(url: fallbackUrl),
          onDesktop: (_) => RedirectUrlConfig(url: desktopUrl),
        );

        expect(url, equals(desktopUrl));
      });
    });

    group('Windows resolution: onWindows > onDesktop > fallback', () {
      setUp(() {
        debugRedirectPlatformTypeOverride = RedirectPlatformType.windows;
      });

      test('uses onWindows when provided', () {
        final (:url, options: _) = constructRedirectUrl(
          fallback: (_) => RedirectUrlConfig(url: fallbackUrl),
          onWindows: (_) => RedirectUrlConfig(url: windowsUrl),
          onDesktop: (_) => RedirectUrlConfig(url: desktopUrl),
        );

        expect(url, equals(windowsUrl));
      });

      test('falls back to onDesktop', () {
        final (:url, options: _) = constructRedirectUrl(
          fallback: (_) => RedirectUrlConfig(url: fallbackUrl),
          onDesktop: (_) => RedirectUrlConfig(url: desktopUrl),
        );

        expect(url, equals(desktopUrl));
      });
    });

    group('Web resolution: onWeb > fallback', () {
      setUp(() {
        debugRedirectPlatformTypeOverride = RedirectPlatformType.web;
      });

      test('uses onWeb when provided', () {
        final (:url, options: _) = constructRedirectUrl(
          fallback: (_) => RedirectUrlConfig(url: fallbackUrl),
          onWeb: (_) => RedirectUrlConfig(url: webUrl),
        );

        expect(url, equals(webUrl));
      });

      test('falls back to fallback', () {
        final (:url, options: _) = constructRedirectUrl(
          fallback: (_) => RedirectUrlConfig(url: fallbackUrl),
        );

        expect(url, equals(fallbackUrl));
      });
    });

    test('passes the correct platform type to the builder', () {
      debugRedirectPlatformTypeOverride = RedirectPlatformType.ios;
      RedirectPlatformType? received;

      constructRedirectUrl(
        fallback: (platform) {
          received = platform;
          return RedirectUrlConfig(url: fallbackUrl);
        },
      );

      expect(received, equals(RedirectPlatformType.ios));
    });

    test('onDarwin receives the specific platform (ios vs macos)', () {
      final received = <RedirectPlatformType>[];

      for (final p in [RedirectPlatformType.ios, RedirectPlatformType.macos]) {
        debugRedirectPlatformTypeOverride = p;
        constructRedirectUrl(
          fallback: (_) => RedirectUrlConfig(url: fallbackUrl),
          onDarwin: (platform) {
            received.add(platform);
            return RedirectUrlConfig(url: darwinUrl);
          },
        );
      }

      expect(received, [RedirectPlatformType.ios, RedirectPlatformType.macos]);
    });

    test('onDesktop receives the specific platform (linux vs windows)', () {
      final received = <RedirectPlatformType>[];

      for (final p in [
        RedirectPlatformType.linux,
        RedirectPlatformType.windows,
      ]) {
        debugRedirectPlatformTypeOverride = p;
        constructRedirectUrl(
          fallback: (_) => RedirectUrlConfig(url: fallbackUrl),
          onDesktop: (platform) {
            received.add(platform);
            return RedirectUrlConfig(url: desktopUrl);
          },
        );
      }

      expect(
        received,
        [RedirectPlatformType.linux, RedirectPlatformType.windows],
      );
    });

    test('onMobile receives the specific platform (android vs ios)', () {
      final received = <RedirectPlatformType>[];

      for (final p in [
        RedirectPlatformType.android,
        RedirectPlatformType.ios,
      ]) {
        debugRedirectPlatformTypeOverride = p;
        constructRedirectUrl(
          fallback: (_) => RedirectUrlConfig(url: fallbackUrl),
          onMobile: (platform) {
            received.add(platform);
            return RedirectUrlConfig(url: mobileUrl);
          },
        );
      }

      expect(
        received,
        [RedirectPlatformType.android, RedirectPlatformType.ios],
      );
    });

    test('applies timeout from top-level params', () {
      debugRedirectPlatformTypeOverride = RedirectPlatformType.android;

      final (:url, :options) = constructRedirectUrl(
        fallback: (_) => RedirectUrlConfig(url: fallbackUrl),
        timeout: const Duration(minutes: 5),
      );

      expect(options.timeout, equals(const Duration(minutes: 5)));
    });

    test('config timeout overrides top-level default', () {
      debugRedirectPlatformTypeOverride = RedirectPlatformType.android;

      final (:url, :options) = constructRedirectUrl(
        fallback: (_) => RedirectUrlConfig(
          url: fallbackUrl,
          timeout: const Duration(seconds: 30),
        ),
        timeout: const Duration(minutes: 5),
      );

      // Config timeout wins over top-level timeout
      expect(options.timeout, equals(const Duration(seconds: 30)));
    });

    test('defaults to no timeout', () {
      debugRedirectPlatformTypeOverride = RedirectPlatformType.android;

      final (:url, :options) = constructRedirectUrl(
        fallback: (_) => RedirectUrlConfig(url: fallbackUrl),
      );

      expect(options.timeout, isNull);
    });

    test('includes platform options from the config', () {
      debugRedirectPlatformTypeOverride = RedirectPlatformType.android;

      const androidOptions = AndroidRedirectOptions(
        callbackUrlScheme: 'myapp',
        showTitle: true,
      );

      final (:url, :options) = constructRedirectUrl(
        fallback: (_) => RedirectUrlConfig(url: fallbackUrl),
        onAndroid: (_) => RedirectUrlConfig(
          url: androidUrl,
          platformOptions: {AndroidRedirectOptions.key: androidOptions},
        ),
      );

      expect(
        options.getPlatformOption<AndroidRedirectOptions>(
          AndroidRedirectOptions.key,
        ),
        equals(androidOptions),
      );
    });

    test('config with empty platformOptions returns empty map', () {
      debugRedirectPlatformTypeOverride = RedirectPlatformType.web;

      final (:url, :options) = constructRedirectUrl(
        fallback: (_) => RedirectUrlConfig(url: fallbackUrl),
      );

      expect(options.platformOptions, isEmpty);
    });
  });
}
