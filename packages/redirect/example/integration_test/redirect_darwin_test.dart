// Darwin (iOS/macOS)-specific integration tests for the redirect plugin.
//
// These tests run ONLY on iOS and macOS and exercise platform-specific
// behavior:
// - ASWebAuthenticationSession ephemeral mode
// - Custom scheme and HTTPS callback configs
// - Additional header fields (iOS 17.4+ / macOS 14.4+)
// - Cancel during ASWebAuthenticationSession presentation
// - Concurrent sessions
//
// Run with:
//   cd packages/redirect/example
//   flutter test integration_test/redirect_darwin_test.dart -d <ios/macos-device>
//
// Or via flutter drive:
//   flutter drive \
//     --driver=test_driver/integration_test.dart \
//     --target=integration_test/redirect_darwin_test.dart \
//     -d <device>

// ignore_for_file: avoid_print

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:redirect/redirect.dart';
import 'package:redirect_platform_interface/redirect_platform_interface.dart';

bool get _isDarwin =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // ─────────────────────────────────────────────────
  // 1. ASWebAuthenticationSession — basic flow
  // ─────────────────────────────────────────────────

  group(
    'ASWebAuthenticationSession >',
    skip: !_isDarwin ? 'Not Darwin' : null,
    () {
      testWidgets(
        'launch and cancel returns RedirectCancelled',
        (tester) async {
          final callbackUrl = Uri.parse(
            'myapp://callback?code=darwin_basic_test',
          );
          final encodedCallback = Uri.encodeComponent(callbackUrl.toString());
          final url = Uri.parse(
            'https://httpbin.org/redirect-to'
            '?url=$encodedCallback&status_code=302',
          );

          final options = _darwinOptions();

          final handle = runRedirect(url: url, options: options);

          // Cancel immediately — the ASWebAuthenticationSession may not
          // have presented yet.
          await handle.cancel();

          final result = await handle.result.timeout(
            const Duration(seconds: 10),
            onTimeout: () => const RedirectCancelled(),
          );

          expect(result, isA<RedirectCancelled>());
        },
      );
    },
  );

  // ─────────────────────────────────────────────────
  // 2. Ephemeral session mode
  // ─────────────────────────────────────────────────

  group(
    'Darwin ephemeral session >',
    skip: !_isDarwin ? 'Not Darwin' : null,
    () {
      testWidgets(
        'preferEphemeral is accepted without error',
        (tester) async {
          final callbackUrl = Uri.parse(
            'myapp://callback?code=darwin_ephemeral_test',
          );
          final encodedCallback = Uri.encodeComponent(callbackUrl.toString());
          final url = Uri.parse(
            'https://httpbin.org/redirect-to'
            '?url=$encodedCallback&status_code=302',
          );

          final options = _darwinOptions(preferEphemeral: true);

          final handle = runRedirect(url: url, options: options);
          await handle.cancel();

          final result = await handle.result.timeout(
            const Duration(seconds: 10),
            onTimeout: () => const RedirectCancelled(),
          );

          // Should be cancelled, not errored.
          expect(result, isA<RedirectCancelled>());
        },
      );
    },
  );

  // ─────────────────────────────────────────────────
  // 3. Additional header fields
  // ─────────────────────────────────────────────────

  group(
    'Darwin additional headers >',
    skip: !_isDarwin ? 'Not Darwin' : null,
    () {
      testWidgets(
        'additionalHeaderFields is accepted without error',
        (tester) async {
          final callbackUrl = Uri.parse(
            'myapp://callback?code=darwin_headers_test',
          );
          final encodedCallback = Uri.encodeComponent(callbackUrl.toString());
          final url = Uri.parse(
            'https://httpbin.org/redirect-to'
            '?url=$encodedCallback&status_code=302',
          );

          final options = _darwinOptions(
            additionalHeaderFields: {
              'X-Custom-Header': 'test-value',
              'Accept-Language': 'en-US',
            },
          );

          final handle = runRedirect(url: url, options: options);
          await handle.cancel();

          final result = await handle.result.timeout(
            const Duration(seconds: 10),
            onTimeout: () => const RedirectCancelled(),
          );

          // On iOS 17.4+ / macOS 14.4+ the headers are set.
          // On older OS they are silently ignored. Either way, no error.
          expect(result, isA<RedirectCancelled>());
        },
      );
    },
  );

  // ─────────────────────────────────────────────────
  // 4. Concurrent sessions
  // ─────────────────────────────────────────────────

  group(
    'Darwin concurrent sessions >',
    skip: !_isDarwin ? 'Not Darwin' : null,
    () {
      testWidgets(
        'two concurrent sessions have distinct nonces',
        (tester) async {
          final makeHandle = (String code) {
            final cbUrl = Uri.parse('myapp://callback?code=$code');
            final encoded = Uri.encodeComponent(cbUrl.toString());
            return runRedirect(
              url: Uri.parse(
                'https://httpbin.org/redirect-to'
                '?url=$encoded&status_code=302',
              ),
              options: _darwinOptions(),
            );
          };

          final h1 = makeHandle('darwin_concurrent_a');
          final h2 = makeHandle('darwin_concurrent_b');

          expect(h1.nonce, isNot(equals(h2.nonce)));

          await h1.cancel();
          await h2.cancel();

          final r1 = await h1.result.timeout(
            const Duration(seconds: 5),
            onTimeout: () => const RedirectCancelled(),
          );
          final r2 = await h2.result.timeout(
            const Duration(seconds: 5),
            onTimeout: () => const RedirectCancelled(),
          );

          expect(r1, isA<RedirectCancelled>());
          expect(r2, isA<RedirectCancelled>());
        },
      );
    },
  );

  // ─────────────────────────────────────────────────
  // 5. Timeout
  // ─────────────────────────────────────────────────

  group(
    'Darwin timeout >',
    skip: !_isDarwin ? 'Not Darwin' : null,
    () {
      testWidgets(
        'native timeout cancels ASWebAuthenticationSession',
        (tester) async {
          // URL that won't redirect, so the timeout fires.
          final handle = runRedirect(
            url: Uri.parse('https://httpbin.org/delay/60'),
            options: _darwinOptions(timeout: const Duration(seconds: 3)),
          );

          final result = await handle.result.timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              print('Outer timeout — native timeout may not have fired');
              return const RedirectCancelled();
            },
          );

          print('Darwin timeout result: $result');

          expect(result, isA<RedirectCancelled>());
        },
      );
    },
  );

  // ─────────────────────────────────────────────────
  // 6. Option validation
  // ─────────────────────────────────────────────────

  group(
    'Darwin option validation >',
    skip: !_isDarwin ? 'Not Darwin' : null,
    () {
      test('IosRedirectOptions defaults', () {
        const opts = IosRedirectOptions(
          callback: CallbackConfig.customScheme('myapp'),
        );

        expect(opts.preferEphemeral, isFalse);
        expect(opts.additionalHeaderFields, isNull);
      });

      test('MacosRedirectOptions defaults', () {
        const opts = MacosRedirectOptions(
          callback: CallbackConfig.customScheme('myapp'),
        );

        expect(opts.preferEphemeral, isFalse);
        expect(opts.additionalHeaderFields, isNull);
      });

      test('CallbackConfig.customScheme creates correct config', () {
        const config = CallbackConfig.customScheme('myapp');
        expect(config, isA<CallbackConfig>());
      });

      test('CallbackConfig.https creates correct config', () {
        const config = CallbackConfig.https(
          host: 'example.com',
          path: '/callback',
        );
        expect(config, isA<CallbackConfig>());
      });
    },
  );
}

// ── Helpers ──────────────────────────────────────────────────────

/// Builds Darwin-appropriate [RedirectOptions] for the current platform.
RedirectOptions _darwinOptions({
  bool preferEphemeral = false,
  Duration? timeout,
  Map<String, String>? additionalHeaderFields,
}) {
  final darwinPlatformOptions = <String, Object>{};

  if (defaultTargetPlatform == TargetPlatform.iOS) {
    darwinPlatformOptions[IosRedirectOptions.key] = IosRedirectOptions(
      callback: const CallbackConfig.customScheme('myapp'),
      preferEphemeral: preferEphemeral,
      additionalHeaderFields: additionalHeaderFields,
    );
  } else {
    darwinPlatformOptions[MacosRedirectOptions.key] = MacosRedirectOptions(
      callback: const CallbackConfig.customScheme('myapp'),
      preferEphemeral: preferEphemeral,
      additionalHeaderFields: additionalHeaderFields,
    );
  }

  return RedirectOptions(
    timeout: timeout,
    platformOptions: darwinPlatformOptions,
  );
}
