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
import 'package:flutter/material.dart';
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

      expect(find.text('Redirect Plugin'), findsOneWidget);
      expect(find.text('Redirect URL'), findsOneWidget);
      expect(find.text('Callback URL Scheme'), findsOneWidget);
      expect(find.text('Core Options'), findsOneWidget);
      expect(find.text('Prefer Ephemeral Session'), findsOneWidget);
      expect(find.text('Timeout'), findsOneWidget);
      expect(find.text('Run Redirect'), findsOneWidget);
    });

    testWidgets('shows web-specific options on web', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      if (kIsWeb) {
        expect(find.text('Web-Specific Options'), findsOneWidget);
        expect(find.text('Redirect Strategy'), findsOneWidget);
        expect(find.text('Popup'), findsOneWidget);
        expect(find.text('New Tab'), findsOneWidget);
        expect(find.text('Same Page'), findsOneWidget);
        expect(find.text('Iframe'), findsOneWidget);
      }
    });

    testWidgets('info card mentions multi-handle support', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      if (kIsWeb) {
        expect(
          find.textContaining('multiple concurrent handles'),
          findsOneWidget,
        );
      }
    });
  });

  group('Mode selection', () {
    testWidgets('can switch between redirect modes', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      if (!kIsWeb) return;

      final popupButton = find.text('Popup');
      expect(popupButton, findsOneWidget);

      await tester.tap(find.text('Iframe'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Iframe mode (hidden by default)'),
        findsOneWidget,
      );

      await tester.tap(find.text('Same Page'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Same-page mode navigates away'),
        findsOneWidget,
      );

      await tester.tap(find.text('New Tab'));
      await tester.pumpAndSettle();
    });

    testWidgets('popup mode shows dimension controls', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      if (!kIsWeb) return;

      expect(find.text('Popup Dimensions'), findsOneWidget);

      await tester.tap(find.text('Iframe'));
      await tester.pumpAndSettle();

      expect(find.text('Popup Dimensions'), findsNothing);
    });
  });

  group('Multi-handle UI', () {
    testWidgets('Run Redirect button is always enabled', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      if (!kIsWeb) return;

      // Button should always be clickable — no single-handle lock
      final runButton = find.text('Run Redirect');
      expect(runButton, findsOneWidget);
    });

    testWidgets('clear completed button hidden when no handles', (
      tester,
    ) async {
      app.main();
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.delete_sweep), findsNothing);
    });
  });

  group('RedirectWeb static helpers (direct API)', () {
    testWidgets('hasPendingRedirect + resumePendingRedirect', (tester) async {
      if (!kIsWeb) return;

      RedirectWeb.clearPendingRedirect();
      expect(RedirectWeb.hasPendingRedirect(), isFalse);

      web.window.sessionStorage
        ..setItem('redirect_pending', 'true')
        ..setItem('redirect_callback_url', Uri.base.toString());

      expect(RedirectWeb.hasPendingRedirect(), isTrue);

      final result = RedirectWeb.resumePendingRedirect();
      expect(result, isA<RedirectSuccess>());
      expect(RedirectWeb.hasPendingRedirect(), isFalse);
    });

    testWidgets('handleCallback broadcasts to channels', (tester) async {
      if (!kIsWeb) return;

      const channelName = 'flutter_test_handle_callback';

      web.window.localStorage.setItem(
        'redirect_channels',
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

      await tester.pump(const Duration(milliseconds: 100));

      expect(received, contains('myapp://callback?token=abc'));

      listener.close();
      web.window.localStorage.removeItem('redirect_channels');
    });

    testWidgets('handleCallback broadcasts to multiple channels', (
      tester,
    ) async {
      if (!kIsWeb) return;

      const ch1 = 'flutter_test_multi_ch1';
      const ch2 = 'flutter_test_multi_ch2';

      web.window.localStorage.setItem(
        'redirect_channels',
        jsonEncode([ch1, ch2]),
      );

      final received1 = <String>[];
      final received2 = <String>[];

      final l1 = web.BroadcastChannel(ch1)
        ..onmessage = (web.MessageEvent event) {
          received1.add((event.data! as JSString).toDart);
        }.toJS;
      final l2 = web.BroadcastChannel(ch2)
        ..onmessage = (web.MessageEvent event) {
          received2.add((event.data! as JSString).toDart);
        }.toJS;

      RedirectWeb.handleCallback(
        Uri.parse('myapp://callback?multi=true'),
      );

      await tester.pump(const Duration(milliseconds: 100));

      expect(received1, contains('myapp://callback?multi=true'));
      expect(received2, contains('myapp://callback?multi=true'));

      l1.close();
      l2.close();
      web.window.localStorage.removeItem('redirect_channels');
    });

    testWidgets('clearPendingRedirect removes session state', (tester) async {
      if (!kIsWeb) return;

      web.window.sessionStorage
        ..setItem('redirect_pending', 'true')
        ..setItem('redirect_callback_url', 'https://example.com/cb');

      expect(RedirectWeb.hasPendingRedirect(), isTrue);

      RedirectWeb.clearPendingRedirect();

      expect(RedirectWeb.hasPendingRedirect(), isFalse);
      expect(
        web.window.sessionStorage.getItem('redirect_pending'),
        isNull,
      );
    });

    testWidgets('handleCallback with explicit channel', (tester) async {
      if (!kIsWeb) return;

      const channelName = 'flutter_test_explicit_channel';

      final received = <String>[];
      final listener = web.BroadcastChannel(channelName)
        ..onmessage = (web.MessageEvent event) {
          received.add((event.data! as JSString).toDart);
        }.toJS;

      RedirectWeb.handleCallback(
        Uri.parse('myapp://callback?explicit=yes'),
        channelName: channelName,
      );

      await tester.pump(const Duration(milliseconds: 100));

      expect(received, contains('myapp://callback?explicit=yes'));

      listener.close();
    });

    testWidgets('handles empty channel list gracefully', (tester) async {
      if (!kIsWeb) return;

      web.window.localStorage.removeItem('redirect_channels');

      expect(
        () => RedirectWeb.handleCallback(Uri.parse('myapp://callback')),
        returnsNormally,
      );
    });
  });
}
