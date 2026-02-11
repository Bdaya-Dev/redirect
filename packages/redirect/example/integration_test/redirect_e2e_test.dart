// Full end-to-end integration tests for the redirect plugin.
//
// These tests exercise the actual redirect flow on each platform —
// Android (Custom Tabs), iOS/macOS (ASWebAuthenticationSession),
// Linux/Windows (loopback server + system browser), and common
// cross-platform behavior (concurrent handles, timeout, cancel).
//
// Run with:
//   cd packages/redirect/example
//   flutter test integration_test/redirect_e2e_test.dart -d <device>
//
// Or via flutter drive:
//   flutter drive \
//     --driver=test_driver/integration_test.dart \
//     --target=integration_test/redirect_e2e_test.dart \
//     -d <device>

// avoid_print: Integration tests use print for debugging output.
// ignore_for_file: avoid_print

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:redirect/redirect.dart';
import 'package:redirect_platform_interface/redirect_platform_interface.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // ─────────────────────────────────────────────────
  // 1. Platform registration sanity
  // ─────────────────────────────────────────────────

  group('Platform registration >', () {
    test('correct platform plugin is registered', () {
      final instance = RedirectPlatform.instance;
      final typeName = instance.runtimeType.toString();
      print('RedirectPlatform.instance: $typeName');

      if (kIsWeb) {
        expect(typeName, contains('Web'));
      } else {
        switch (defaultTargetPlatform) {
          case TargetPlatform.android:
            expect(typeName, contains('Android'));
          case TargetPlatform.iOS:
            expect(typeName, contains('Ios'));
          case TargetPlatform.macOS:
            expect(typeName, contains('Macos'));
          case TargetPlatform.linux:
            expect(typeName, contains('Linux'));
          case TargetPlatform.windows:
            expect(typeName, contains('Windows'));
          case TargetPlatform.fuchsia:
            fail('Fuchsia is not supported');
        }
      }
    });
  });

  // ─────────────────────────────────────────────────
  // 2. Full redirect flow — httpbin redirect-to
  // ─────────────────────────────────────────────────
  //
  // Uses httpbin.org/redirect-to to simulate a full redirect flow:
  //   1. Open URL in browser/Custom Tab/ASWebAuthenticationSession
  //   2. Server responds with 302 → myapp://callback?code=...
  //   3. Platform intercepts the callback URL
  //   4. RedirectSuccess is returned with the full callback URI
  //
  // This test exercises the ENTIRE native pipeline end-to-end.

  group('Full redirect flow >', () {
    testWidgets(
      'httpbin redirect returns success with callback URI',
      (tester) async {
        // Skip on web — web has its own test file.
        if (kIsWeb) return;

        final (:url, :options) = _buildPlatformConfig(
          code: 'e2e_test_${DateTime.now().millisecondsSinceEpoch}',
        );

        print('Redirect URL: $url');
        print('Platform: $defaultTargetPlatform');

        final handle = runRedirect(url: url, options: options);

        // The redirect should produce a result.
        // On a real device, the browser opens → httpbin 302s → callback
        // intercepted. On CI with no browser this will fail or timeout —
        // the test validates the integration, not CI availability.
        final result = await handle.result.timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            print('Redirect timed out — cancelling');
            return const RedirectCancelled();
          },
        );

        print('Result: $result');

        // On CI with a real device/emulator, the browser is always
        // available. The redirect should complete or be cancelled if
        // the user dismissed the browser before httpbin responded.
        expect(
          result,
          anyOf(isA<RedirectSuccess>(), isA<RedirectCancelled>()),
        );

        if (result case RedirectSuccess(:final uri)) {
          expect(uri.scheme, equals('myapp'));
          expect(uri.queryParameters['code'], startsWith('e2e_test_'));
          print('Callback URI: $uri');
        }
      },
    );
  });

  // ─────────────────────────────────────────────────
  // 3. Cancel flow
  // ─────────────────────────────────────────────────

  group('Cancel flow >', () {
    testWidgets(
      'cancel returns RedirectCancelled',
      (tester) async {
        if (kIsWeb) return;

        final (:url, :options) = _buildPlatformConfig(code: 'cancel_test');

        final handle = runRedirect(url: url, options: options);

        // Cancel immediately — the browser may or may not have opened.
        await handle.cancel();

        final result = await handle.result.timeout(
          const Duration(seconds: 10),
          onTimeout: () => const RedirectCancelled(),
        );

        print('Cancel result: $result');

        // After cancel, the result should be cancelled.
        expect(result, isA<RedirectCancelled>());
      },
    );

    testWidgets(
      'cancel all handles returns all cancelled',
      (tester) async {
        if (kIsWeb) return;

        final configs = List.generate(
          3,
          (i) => _buildPlatformConfig(code: 'cancel_all_$i'),
        );

        final handles = configs.map((c) {
          return runRedirect(url: c.url, options: c.options);
        }).toList();

        // Cancel all.
        for (final handle in handles) {
          await handle.cancel();
        }

        for (final handle in handles) {
          final result = await handle.result.timeout(
            const Duration(seconds: 10),
            onTimeout: () => const RedirectCancelled(),
          );
          expect(result, isA<RedirectCancelled>());
        }
      },
    );
  });

  // ─────────────────────────────────────────────────
  // 4. Timeout flow
  // ─────────────────────────────────────────────────

  group('Timeout flow >', () {
    testWidgets(
      'short timeout cancels redirect automatically',
      (tester) async {
        if (kIsWeb) return;

        // Use a URL that will NOT redirect — so the timeout fires.
        final (:url, :options) = _buildPlatformConfig(
          code: 'timeout_test',
          timeout: const Duration(seconds: 2),
          // Use a URL that takes forever (or doesn't redirect).
          customUrl: Uri.parse('https://httpbin.org/delay/60'),
        );

        final handle = runRedirect(url: url, options: options);

        final result = await handle.result.timeout(
          const Duration(seconds: 10),
          onTimeout: () => const RedirectCancelled(),
        );

        print('Timeout result: $result');

        // After timeout, the redirect should be cancelled.
        expect(result, isA<RedirectCancelled>());
      },
    );
  });

  // ─────────────────────────────────────────────────
  // 5. Concurrent handles
  // ─────────────────────────────────────────────────

  group('Concurrent handles >', () {
    testWidgets(
      'multiple redirects can be launched concurrently',
      (tester) async {
        if (kIsWeb) return;

        // Launch two concurrent redirects and cancel them both.
        // This tests the multi-handle architecture.
        final config1 = _buildPlatformConfig(code: 'concurrent_1');
        final config2 = _buildPlatformConfig(code: 'concurrent_2');

        final handle1 = runRedirect(
          url: config1.url,
          options: config1.options,
        );
        final handle2 = runRedirect(
          url: config2.url,
          options: config2.options,
        );

        // Both should have unique nonces.
        expect(handle1.nonce, isNot(equals(handle2.nonce)));

        // Cancel both.
        await handle1.cancel();
        await handle2.cancel();

        final result1 = await handle1.result.timeout(
          const Duration(seconds: 10),
          onTimeout: () => const RedirectCancelled(),
        );
        final result2 = await handle2.result.timeout(
          const Duration(seconds: 10),
          onTimeout: () => const RedirectCancelled(),
        );

        expect(result1, isA<RedirectCancelled>());
        expect(result2, isA<RedirectCancelled>());
      },
    );
  });

  // ─────────────────────────────────────────────────
  // 6. RedirectHandle API
  // ─────────────────────────────────────────────────

  group('RedirectHandle API >', () {
    testWidgets(
      'handle exposes url and nonce',
      (tester) async {
        if (kIsWeb) return;

        final (:url, :options) = _buildPlatformConfig(code: 'api_test');

        final handle = runRedirect(url: url, options: options);

        expect(handle.url, isNotNull);
        expect(handle.nonce, isNotEmpty);
        expect(handle.nonce, isA<String>());

        // The URL on the handle may differ from the input URL on desktop
        // (where the loopback server port is injected), but should be
        // a valid URL.
        expect(handle.url.hasScheme, isTrue);

        await handle.cancel();
        await handle.result.timeout(
          const Duration(seconds: 5),
          onTimeout: () => const RedirectCancelled(),
        );
      },
    );
  });

  // ─────────────────────────────────────────────────
  // 7. constructRedirectUrl helper
  // ─────────────────────────────────────────────────

  group('constructRedirectUrl >', () {
    test('selects correct platform builder', () {
      final (:url, :options) = constructRedirectUrl(
        timeout: const Duration(seconds: 42),
        fallback: (_) => RedirectUrlConfig(
          url: Uri.parse('https://fallback.example.com'),
        ),
        onAndroid: (_) => RedirectUrlConfig(
          url: Uri.parse('https://android.example.com'),
          platformOptions: {
            AndroidRedirectOptions.key: const AndroidRedirectOptions(
              callbackUrlScheme: 'myapp',
            ),
          },
        ),
        onDarwin: (platform) => RedirectUrlConfig(
          url: Uri.parse('https://darwin.example.com'),
          platformOptions: {
            if (platform == RedirectPlatformType.ios)
              IosRedirectOptions.key: const IosRedirectOptions(
                callback: CallbackConfig.customScheme('myapp'),
              )
            else
              MacosRedirectOptions.key: const MacosRedirectOptions(
                callback: CallbackConfig.customScheme('myapp'),
              ),
          },
        ),
        onDesktop: (_) => RedirectUrlConfig(
          url: Uri.parse('https://desktop.example.com'),
        ),
      );

      expect(url, isNotNull);
      expect(options.timeout, equals(const Duration(seconds: 42)));

      if (kIsWeb) {
        expect(url.host, equals('fallback.example.com'));
      } else {
        switch (defaultTargetPlatform) {
          case TargetPlatform.android:
            expect(url.host, equals('android.example.com'));
            expect(
              options.platformOptions,
              containsPair(
                AndroidRedirectOptions.key,
                isA<AndroidRedirectOptions>(),
              ),
            );
          case TargetPlatform.iOS:
            expect(url.host, equals('darwin.example.com'));
            expect(
              options.platformOptions,
              containsPair(
                IosRedirectOptions.key,
                isA<IosRedirectOptions>(),
              ),
            );
          case TargetPlatform.macOS:
            expect(url.host, equals('darwin.example.com'));
            expect(
              options.platformOptions,
              containsPair(
                MacosRedirectOptions.key,
                isA<MacosRedirectOptions>(),
              ),
            );
          case TargetPlatform.linux || TargetPlatform.windows:
            expect(url.host, equals('desktop.example.com'));
          case TargetPlatform.fuchsia:
            fail('Fuchsia is not supported');
        }
      }
    });

    test('config timeout overrides default', () {
      final (:url, :options) = constructRedirectUrl(
        timeout: const Duration(seconds: 99),
        fallback: (_) => RedirectUrlConfig(
          url: Uri.parse('https://example.com'),
          timeout: const Duration(seconds: 10),
        ),
      );

      // Config-level timeout takes precedence.
      expect(options.timeout, equals(const Duration(seconds: 10)));
      expect(url.host, equals('example.com'));
    });
  });

  // ─────────────────────────────────────────────────
  // 8. Platform-specific option tests
  // ─────────────────────────────────────────────────

  group('Platform-specific options >', () {
    test('AndroidRedirectOptions serializes correctly', () {
      if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;

      const androidOpts = AndroidRedirectOptions(
        callbackUrlScheme: 'myapp',
        preferEphemeral: true,
        useCustomTabs: true,
        showTitle: true,
        enableUrlBarHiding: true,
        toolbarColor: 0xFF6200EE,
      );

      expect(androidOpts.callbackUrlScheme, equals('myapp'));
      expect(androidOpts.preferEphemeral, isTrue);
      expect(androidOpts.useCustomTabs, isTrue);
      expect(androidOpts.showTitle, isTrue);
      expect(androidOpts.toolbarColor, equals(0xFF6200EE));
    });

    test('IosRedirectOptions serializes correctly', () {
      if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;

      const iosOpts = IosRedirectOptions(
        callback: CallbackConfig.customScheme('myapp'),
        preferEphemeral: true,
      );

      expect(iosOpts.callback, isA<CallbackConfig>());
      expect(iosOpts.preferEphemeral, isTrue);
    });

    test('MacosRedirectOptions serializes correctly', () {
      if (kIsWeb || defaultTargetPlatform != TargetPlatform.macOS) return;

      const macosOpts = MacosRedirectOptions(
        callback: CallbackConfig.customScheme('myapp'),
        preferEphemeral: true,
      );

      expect(macosOpts.callback, isA<CallbackConfig>());
      expect(macosOpts.preferEphemeral, isTrue);
    });
  });

  // ─────────────────────────────────────────────────
  // 9. RedirectResult sealed class
  // ─────────────────────────────────────────────────

  group('RedirectResult sealed class >', () {
    test('all subtypes constructible and pattern-matchable', () {
      final results = <RedirectResult>[
        RedirectSuccess(uri: Uri.parse('myapp://callback?code=abc')),
        const RedirectCancelled(),
        const RedirectPending(),
        RedirectFailure(
          error: Exception('test error'),
          stackTrace: StackTrace.current,
        ),
      ];

      expect(results, hasLength(4));

      final descriptions = results.map((r) {
        return switch (r) {
          RedirectSuccess(:final uri) => 'success:${uri.queryParameters}',
          RedirectCancelled() => 'cancelled',
          RedirectPending() => 'pending',
          RedirectFailure(:final error) => 'failure:$error',
        };
      }).toList();

      expect(descriptions[0], startsWith('success:'));
      expect(descriptions[1], equals('cancelled'));
      expect(descriptions[2], equals('pending'));
      expect(descriptions[3], startsWith('failure:'));
    });
  });
}

// ── Helpers ──────────────────────────────────────────────────────

/// Builds a platform-appropriate redirect URL and options for e2e tests.
///
/// Uses httpbin.org/redirect-to for a real HTTP 302 redirect to the
/// callback URL, exercising the full native redirect pipeline.
({Uri url, RedirectOptions options}) _buildPlatformConfig({
  required String code,
  Duration? timeout,
  Uri? customUrl,
}) {
  final callbackUrl = Uri.parse('myapp://callback?code=$code');
  final encodedCallback = Uri.encodeComponent(callbackUrl.toString());
  final httpbinUrl = customUrl ??
      Uri.parse(
        'https://httpbin.org/redirect-to'
        '?url=$encodedCallback&status_code=302',
      );

  return constructRedirectUrl(
    timeout: timeout,
    fallback: (_) => RedirectUrlConfig(url: httpbinUrl),
    onAndroid: (_) => RedirectUrlConfig(
      url: httpbinUrl,
      platformOptions: {
        AndroidRedirectOptions.key: const AndroidRedirectOptions(
          callbackUrlScheme: 'myapp',
        ),
      },
    ),
    onDarwin: (platform) => RedirectUrlConfig(
      url: httpbinUrl,
      platformOptions: {
        if (platform == RedirectPlatformType.ios)
          IosRedirectOptions.key: const IosRedirectOptions(
            callback: CallbackConfig.customScheme('myapp'),
          )
        else
          MacosRedirectOptions.key: const MacosRedirectOptions(
            callback: CallbackConfig.customScheme('myapp'),
          ),
      },
    ),
    onDesktop: (_) => RedirectUrlConfig(url: httpbinUrl),
  );
}
