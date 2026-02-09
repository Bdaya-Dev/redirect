// Integration tests for the redirect Flutter example app on web.
//
// These tests compile Flutter widgets to JS and run in Chrome, giving access
// to real web APIs (BroadcastChannel, localStorage, sessionStorage).
//
// Run with (web requires chromedriver running on port 4444):
//   cd packages/redirect/example
//   chromedriver --port=4444
//   flutter drive \
//     --driver=test_driver/integration_test.dart \
//     --target=integration_test/redirect_web_integration_test.dart \
//     -d web-server

import 'dart:convert';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:redirect/redirect.dart';
import 'package:redirect_example/main.dart' as app;
import 'package:redirect_web_core/redirect_web_core.dart';
import 'package:web/web.dart' as web;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('App renders correctly', () {
    testWidgets('shows all main UI elements', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Title
      expect(find.text('Redirect Plugin'), findsOneWidget);

      // URL input
      expect(find.text('Authorization URL'), findsOneWidget);

      // Callback scheme input
      expect(find.text('Callback URL Scheme'), findsOneWidget);

      // Core Options section
      expect(find.text('Core Options'), findsOneWidget);
      expect(find.text('Prefer Ephemeral Session'), findsOneWidget);
      expect(find.text('Timeout'), findsOneWidget);

      // Run Redirect button
      expect(find.text('Run Redirect'), findsOneWidget);
    });

    testWidgets('shows web-specific options on web', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      if (kIsWeb) {
        expect(find.text('Web-Specific Options'), findsOneWidget);
        expect(find.text('Redirect Strategy'), findsOneWidget);

        // Mode buttons
        expect(find.text('Popup'), findsOneWidget);
        expect(find.text('New Tab'), findsOneWidget);
        expect(find.text('Same Page'), findsOneWidget);
        expect(find.text('Iframe'), findsOneWidget);
      }
    });
  });

  group('Mode selection', () {
    testWidgets('can switch between redirect modes', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      if (!kIsWeb) return;

      // Default mode is Popup
      final popupButton = find.text('Popup');
      expect(popupButton, findsOneWidget);

      // Switch to Iframe mode
      await tester.tap(find.text('Iframe'));
      await tester.pumpAndSettle();

      // Iframe info text should appear
      expect(
        find.textContaining('Hidden iframe is for silent refresh'),
        findsOneWidget,
      );

      // Switch to Same Page mode
      await tester.tap(find.text('Same Page'));
      await tester.pumpAndSettle();

      // Same page warning should appear
      expect(
        find.textContaining('Same-page mode navigates away'),
        findsOneWidget,
      );

      // Switch to New Tab mode
      await tester.tap(find.text('New Tab'));
      await tester.pumpAndSettle();
    });

    testWidgets('popup mode shows dimension controls', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      if (!kIsWeb) return;

      // Popup is default → dimension controls visible
      expect(find.text('Popup Dimensions'), findsOneWidget);

      // Switch to another mode
      await tester.tap(find.text('Iframe'));
      await tester.pumpAndSettle();

      // Dimension controls should be hidden
      expect(find.text('Popup Dimensions'), findsNothing);
    });
  });

  // NOTE: Testing actual redirect flows (iframe, cancel, timeout) via
  // `flutter drive -d web-server` is unreliable because:
  //   1. Async state changes from button taps don't propagate through
  //      the tester's pump cycle in the same way as unit tests.
  //   2. Real HTTP redirects (to httpbin.org) race with test's manual
  //      BroadcastChannel simulation.
  //   3. Real-time timers (Duration-based timeouts) don't advance with
  //      tester.pump() in integration tests.
  //
  // The underlying redirect flows are thoroughly tested in:
  //   - redirect_web_core's browser integration tests
  //     (dart test -p chrome test/integration/)
  //   - redirect_web_core's Jaspr integration tests
  //   - redirect_platform_test.dart for native platforms

  group('RedirectWeb static helpers (direct API)', () {
    testWidgets('hasPendingRedirect + resumePendingRedirect', (tester) async {
      if (!kIsWeb) return;

      // Clean state
      RedirectWeb.clearPendingRedirect();
      expect(RedirectWeb.hasPendingRedirect(), isFalse);

      // Simulate a pending redirect by writing to sessionStorage
      web.window.sessionStorage
        ..setItem('redirect_pending', 'true')
        ..setItem('redirect_pending_scheme', Uri.base.scheme);

      expect(RedirectWeb.hasPendingRedirect(), isTrue);

      final result = RedirectWeb.resumePendingRedirect();
      expect(result, isA<RedirectSuccess>());
      expect(RedirectWeb.hasPendingRedirect(), isFalse);
    });

    testWidgets('handleCallback broadcasts to channels', (tester) async {
      if (!kIsWeb) return;

      const channelName = 'flutter_test_handle_callback';

      // Register channel in localStorage
      web.window.localStorage.setItem(
        'redirect_channels_myapp',
        jsonEncode([channelName]),
      );

      final received = <String>[];
      final listener = web.BroadcastChannel(channelName)
        ..onmessage = (web.MessageEvent event) {
          received.add((event.data! as JSString).toDart);
        }.toJS;

      RedirectWeb.handleCallback(
        Uri.parse('myapp://callback?token=abc'),
      );

      // Give the BroadcastChannel time to propagate
      await tester.pump(const Duration(milliseconds: 100));

      expect(received, contains('myapp://callback?token=abc'));

      listener.close();
      web.window.localStorage.removeItem('redirect_channels_myapp');
    });
  });
}
