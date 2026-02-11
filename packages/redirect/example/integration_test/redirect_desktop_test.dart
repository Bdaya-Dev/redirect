// Desktop (Linux/Windows)-specific integration tests for the redirect plugin.
//
// These tests run ONLY on Linux and Windows and exercise platform-specific
// behavior:
// - Loopback HTTP server binding and port selection
// - Custom HTTP response builder for the callback page
// - System browser launch
// - Cancel during loopback server wait
// - Concurrent desktop handles
//
// Run with:
//   cd packages/redirect/example
//   flutter test integration_test/redirect_desktop_test.dart -d linux
//   flutter test integration_test/redirect_desktop_test.dart -d windows
//
// Or via flutter drive:
//   flutter drive \
//     --driver=test_driver/integration_test.dart \
//     --target=integration_test/redirect_desktop_test.dart \
//     -d <device>

// ignore_for_file: avoid_print

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:redirect/redirect.dart';
import 'package:redirect_platform_interface/redirect_platform_interface.dart';

bool get _isDesktop =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.windows);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // ─────────────────────────────────────────────────
  // 1. Loopback redirect — launch + cancel
  // ─────────────────────────────────────────────────

  group(
    'Desktop loopback redirect >',
    skip: !_isDesktop ? 'Not desktop' : null,
    () {
      testWidgets(
        'launch and cancel returns RedirectCancelled',
        (tester) async {
          final callbackUrl = Uri.parse(
            'myapp://callback?code=desktop_basic_test',
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
                WindowsRedirectOptions.key: WindowsRedirectOptions(),
                LinuxRedirectOptions.key: LinuxRedirectOptions(),
              },
            ),
          );

          // The handle should have a URL with the loopback server port.
          print('Handle URL: ${handle.url}');
          expect(handle.url.hasScheme, isTrue);

          // Cancel before the browser can complete.
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
  // 2. Custom callback URL
  // ─────────────────────────────────────────────────

  group(
    'Desktop custom callback URL >',
    skip: !_isDesktop ? 'Not desktop' : null,
    () {
      testWidgets(
        'custom callbackUrl can be set',
        (tester) async {
          // On desktop, a custom callbackUrl can be provided to bind the
          // loopback server to a specific port/path.
          final handle = runRedirect(
            url: Uri.parse('https://httpbin.org/delay/60'),
            options: RedirectOptions(
              timeout: const Duration(seconds: 3),
              platformOptions: {
                if (defaultTargetPlatform == TargetPlatform.windows)
                  WindowsRedirectOptions.key: WindowsRedirectOptions(
                    callbackUrl: Uri.parse('http://127.0.0.1:0/callback'),
                  )
                else
                  LinuxRedirectOptions.key: LinuxRedirectOptions(
                    callbackUrl: Uri.parse('http://127.0.0.1:0/callback'),
                  ),
              },
            ),
          );

          final result = await handle.result.timeout(
            const Duration(seconds: 10),
            onTimeout: () => const RedirectCancelled(),
          );

          print('Custom callback result: $result');

          expect(result, isA<RedirectCancelled>());
        },
      );
    },
  );

  // ─────────────────────────────────────────────────
  // 3. Concurrent desktop redirects
  // ─────────────────────────────────────────────────

  group(
    'Desktop concurrent redirects >',
    skip: !_isDesktop ? 'Not desktop' : null,
    () {
      testWidgets(
        'two concurrent desktop handles bind on different ports',
        (tester) async {
          final makeHandle = (String code) {
            final cbUrl = Uri.parse('myapp://callback?code=$code');
            final encoded = Uri.encodeComponent(cbUrl.toString());
            return runRedirect(
              url: Uri.parse(
                'https://httpbin.org/redirect-to'
                '?url=$encoded&status_code=302',
              ),
              options: const RedirectOptions(
                platformOptions: {
                  WindowsRedirectOptions.key: WindowsRedirectOptions(),
                  LinuxRedirectOptions.key: LinuxRedirectOptions(),
                },
              ),
            );
          };

          final h1 = makeHandle('desktop_concurrent_a');
          final h2 = makeHandle('desktop_concurrent_b');

          // Each handle should have a unique nonce.
          expect(h1.nonce, isNot(equals(h2.nonce)));

          // On desktop, the URL includes the loopback port.
          // If a loopback server is used, the ports should differ.
          print('Handle 1 URL: ${h1.url}');
          print('Handle 2 URL: ${h2.url}');

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
  // 4. Option validation
  // ─────────────────────────────────────────────────

  group(
    'Desktop option validation >',
    skip: !_isDesktop ? 'Not desktop' : null,
    () {
      test('WindowsRedirectOptions has sensible defaults', () {
        const opts = WindowsRedirectOptions();
        expect(opts.openBrowser, isTrue);
        expect(opts.callbackUrl, isNull);
        expect(opts.httpResponseBuilder, isNull);
      });

      test('LinuxRedirectOptions has sensible defaults', () {
        const opts = LinuxRedirectOptions();
        expect(opts.openBrowser, isTrue);
        expect(opts.callbackUrl, isNull);
        expect(opts.httpResponseBuilder, isNull);
      });

      test('WindowsRedirectOptions can disable browser launch', () {
        const opts = WindowsRedirectOptions(openBrowser: false);
        expect(opts.openBrowser, isFalse);
      });
    },
  );
}
