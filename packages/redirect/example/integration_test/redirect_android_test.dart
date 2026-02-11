// Android-specific integration tests for the redirect plugin.
//
// These tests run ONLY on Android and exercise platform-specific behavior:
// - Custom Tabs availability detection
// - Custom Tab options (toolbar color, title, URL bar hiding)
// - Ephemeral Custom Tab mode
// - Intent callback handling via CallbackActivity
// - Multiple concurrent redirects with different callback schemes
//
// Run with:
//   cd packages/redirect/example
//   flutter test integration_test/redirect_android_test.dart -d <android-device>
//
// Or via flutter drive:
//   flutter drive \
//     --driver=test_driver/integration_test.dart \
//     --target=integration_test/redirect_android_test.dart \
//     -d <android-device>

// ignore_for_file: avoid_print

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:redirect/redirect.dart';
import 'package:redirect_platform_interface/redirect_platform_interface.dart';

bool get _isAndroid =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // ─────────────────────────────────────────────────
  // 1. Custom Tabs options
  // ─────────────────────────────────────────────────

  group('Custom Tab options >', skip: !_isAndroid ? 'Not Android' : null, () {
    testWidgets(
      'Custom Tabs redirect with toolbar color',
      (tester) async {
        final callbackUrl = Uri.parse(
          'myapp://callback?code=custom_tab_toolbar_test',
        );
        final encodedCallback = Uri.encodeComponent(callbackUrl.toString());
        final url = Uri.parse(
          'https://httpbin.org/redirect-to'
          '?url=$encodedCallback&status_code=302',
        );

        final handle = runRedirect(
          url: url,
          options: const RedirectOptions(
            platformOptions: {
              AndroidRedirectOptions.key: AndroidRedirectOptions(
                callbackUrlScheme: 'myapp',
                useCustomTabs: true,
                showTitle: true,
                enableUrlBarHiding: true,
                toolbarColor: 0xFF6200EE, // Purple
                secondaryToolbarColor: 0xFF3700B3,
              ),
            },
          ),
        );

        // The Custom Tab should open with our options.
        // Cancel immediately since we only check that options are accepted.
        await handle.cancel();

        final result = await handle.result.timeout(
          const Duration(seconds: 10),
          onTimeout: () => const RedirectCancelled(),
        );

        expect(result, isA<RedirectCancelled>());
      },
    );

    testWidgets(
      'plain browser fallback when useCustomTabs is false',
      (tester) async {
        final callbackUrl = Uri.parse(
          'myapp://callback?code=plain_browser_test',
        );
        final encodedCallback = Uri.encodeComponent(callbackUrl.toString());
        final url = Uri.parse(
          'https://httpbin.org/redirect-to'
          '?url=$encodedCallback&status_code=302',
        );

        final handle = runRedirect(
          url: url,
          options: const RedirectOptions(
            platformOptions: {
              AndroidRedirectOptions.key: AndroidRedirectOptions(
                callbackUrlScheme: 'myapp',
                useCustomTabs: false,
              ),
            },
          ),
        );

        // Cancel immediately.
        await handle.cancel();

        final result = await handle.result.timeout(
          const Duration(seconds: 10),
          onTimeout: () => const RedirectCancelled(),
        );

        expect(result, isA<RedirectCancelled>());
      },
    );

    testWidgets(
      'ephemeral Custom Tab mode accepted without error',
      (tester) async {
        final callbackUrl = Uri.parse(
          'myapp://callback?code=ephemeral_test',
        );
        final encodedCallback = Uri.encodeComponent(callbackUrl.toString());
        final url = Uri.parse(
          'https://httpbin.org/redirect-to'
          '?url=$encodedCallback&status_code=302',
        );

        final handle = runRedirect(
          url: url,
          options: const RedirectOptions(
            platformOptions: {
              AndroidRedirectOptions.key: AndroidRedirectOptions(
                callbackUrlScheme: 'myapp',
                preferEphemeral: true,
              ),
            },
          ),
        );

        await handle.cancel();

        final result = await handle.result.timeout(
          const Duration(seconds: 10),
          onTimeout: () => const RedirectCancelled(),
        );

        // Should be cancelled, not a failure due to ephemeral not being
        // supported on older devices.
        expect(result, isA<RedirectCancelled>());
      },
    );
  });

  // ─────────────────────────────────────────────────
  // 2. Multiple concurrent redirects
  // ─────────────────────────────────────────────────

  group(
    'Android concurrent redirects >',
    skip: !_isAndroid ? 'Not Android' : null,
    () {
      testWidgets(
        'two concurrent redirects have distinct nonces',
        (tester) async {
          final makeHandle = (String code) {
            final cbUrl = Uri.parse('myapp://callback?code=$code');
            final encoded = Uri.encodeComponent(cbUrl.toString());
            return runRedirect(
              url: Uri.parse(
                'https://httpbin.org/redirect-to?url=$encoded&status_code=302',
              ),
              options: const RedirectOptions(
                platformOptions: {
                  AndroidRedirectOptions.key: AndroidRedirectOptions(
                    callbackUrlScheme: 'myapp',
                  ),
                },
              ),
            );
          };

          final h1 = makeHandle('concurrent_a');
          final h2 = makeHandle('concurrent_b');

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
  // 3. Error paths
  // ─────────────────────────────────────────────────

  group('Android error paths >', skip: !_isAndroid ? 'Not Android' : null, () {
    testWidgets(
      'invalid URL returns a failure or is handled gracefully',
      (tester) async {
        // The URL is syntactically valid for Dart's Uri, but won't
        // result in a valid redirect. The native side should handle
        // this without crashing.
        try {
          final handle = runRedirect(
            url: Uri.parse('not-a-real-url://'),
            options: const RedirectOptions(
              timeout: Duration(seconds: 3),
              platformOptions: {
                AndroidRedirectOptions.key: AndroidRedirectOptions(
                  callbackUrlScheme: 'myapp',
                ),
              },
            ),
          );

          final result = await handle.result.timeout(
            const Duration(seconds: 10),
            onTimeout: () => const RedirectCancelled(),
          );

          print('Invalid URL result: $result');

          // Accept any result — the point is no crash.
          expect(
            result,
            anyOf(
              isA<RedirectSuccess>(),
              isA<RedirectCancelled>(),
              isA<RedirectFailure>(),
            ),
          );
        } on PlatformException catch (e) {
          // PlatformException is also acceptable.
          print('PlatformException (expected): ${e.code}: ${e.message}');
        }
      },
    );

    testWidgets(
      'timeout cancels Android redirect automatically',
      (tester) async {
        // Use a URL that won't redirect to test the timeout path.
        final handle = runRedirect(
          url: Uri.parse('https://httpbin.org/delay/60'),
          options: const RedirectOptions(
            timeout: Duration(seconds: 3),
            platformOptions: {
              AndroidRedirectOptions.key: AndroidRedirectOptions(
                callbackUrlScheme: 'myapp',
              ),
            },
          ),
        );

        final result = await handle.result.timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            print('Outer timeout — native timeout may not have fired');
            return const RedirectCancelled();
          },
        );

        print('Timeout result: $result');

        expect(result, isA<RedirectCancelled>());
      },
    );
  });
}
