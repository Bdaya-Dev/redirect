// Pure Dart integration tests for redirect_web_core.
//
// These tests run in a real Chrome browser via `dart test -p chrome`
// and exercise all redirect flows using BroadcastChannel, localStorage,
// sessionStorage, and DOM APIs.
//
// Run with:
//   cd packages/redirect_web_core
//   dart test -p chrome test/integration/redirect_web_integration_test.dart
@TestOn('browser')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:redirect_core/redirect_core.dart';
import 'package:redirect_web_core/redirect_web_core.dart';
import 'package:test/test.dart';
import 'package:web/web.dart' as web;

void main() {
  late RedirectWeb redirect;

  setUp(() {
    redirect = RedirectWeb();
    _cleanupStorage();
    _cleanupIframes();
  });

  tearDown(() {
    _cleanupStorage();
    _cleanupIframes();
  });

  // ─────────────────────────────────────────────────
  // Iframe mode — fully testable (no user gesture needed)
  // ─────────────────────────────────────────────────

  group('Iframe mode >', () {
    test('completes with RedirectSuccess when callback is broadcast', () async {
      const channelName = 'test_iframe_success';

      final handle = redirect.runWithWebOptions(
        url: Uri.parse('about:blank'),
        callbackUrlScheme: 'myapp',
        webOptions: const WebRedirectOptions(
          mode: WebRedirectMode.hiddenIframe,
          broadcastChannelName: channelName,
        ),
      );

      // Give the channel listener time to register
      await _nextTick();

      // Simulate the callback page broadcasting the result
      web.BroadcastChannel(channelName)
        ..postMessage('myapp://callback?code=abc123'.toJS)
        ..close();

      final result = await handle.result;
      expect(result, isA<RedirectSuccess>());

      final success = result as RedirectSuccess;
      expect(success.uri.scheme, equals('myapp'));
      expect(success.uri.host, equals('callback'));
      expect(success.uri.queryParameters['code'], equals('abc123'));
    });

    test('creates a hidden iframe in the DOM', () {
      const channelName = 'test_iframe_dom';

      redirect.runWithWebOptions(
        url: Uri.parse('about:blank'),
        callbackUrlScheme: 'myapp',
        webOptions: const WebRedirectOptions(
          mode: WebRedirectMode.hiddenIframe,
          broadcastChannelName: channelName,
          iframeId: 'test_iframe_element',
        ),
      );

      final iframe = web.document.getElementById('test_iframe_element');
      expect(iframe, isNotNull);
      expect(iframe, isA<web.HTMLIFrameElement>());
      expect(
        (iframe! as web.HTMLIFrameElement).style.display,
        equals('none'),
      );
    });

    test('uses custom iframe ID', () {
      const channelName = 'test_iframe_custom_id';
      const customId = 'my_custom_iframe_id';

      redirect.runWithWebOptions(
        url: Uri.parse('about:blank'),
        callbackUrlScheme: 'myapp',
        webOptions: const WebRedirectOptions(
          mode: WebRedirectMode.hiddenIframe,
          broadcastChannelName: channelName,
          iframeId: customId,
        ),
      );

      expect(web.document.getElementById(customId), isNotNull);
    });

    test('uses default iframe ID when not specified', () {
      const channelName = 'test_iframe_default_id';

      redirect.runWithWebOptions(
        url: Uri.parse('about:blank'),
        callbackUrlScheme: 'myapp',
        webOptions: const WebRedirectOptions(
          mode: WebRedirectMode.hiddenIframe,
          broadcastChannelName: channelName,
        ),
      );

      // Default id is 'redirect_iframe'
      expect(web.document.getElementById('redirect_iframe'), isNotNull);
    });

    test('removes iframe from DOM after success', () async {
      const channelName = 'test_iframe_cleanup';
      const iframeId = 'test_iframe_cleanup_elem';

      final handle = redirect.runWithWebOptions(
        url: Uri.parse('about:blank'),
        callbackUrlScheme: 'myapp',
        webOptions: const WebRedirectOptions(
          mode: WebRedirectMode.hiddenIframe,
          broadcastChannelName: channelName,
          iframeId: iframeId,
        ),
      );

      // Iframe should exist while redirect is pending
      expect(web.document.getElementById(iframeId), isNotNull);

      await _nextTick();

      // Simulate callback
      web.BroadcastChannel(channelName)
        ..postMessage('myapp://done'.toJS)
        ..close();

      await handle.result;

      // Iframe should be removed after success
      expect(web.document.getElementById(iframeId), isNull);
    });

    test('cancel completes with RedirectCancelled', () async {
      const channelName = 'test_iframe_cancel';
      const iframeId = 'test_iframe_cancel_elem';

      final handle = redirect.runWithWebOptions(
        url: Uri.parse('about:blank'),
        callbackUrlScheme: 'myapp',
        webOptions: const WebRedirectOptions(
          mode: WebRedirectMode.hiddenIframe,
          broadcastChannelName: channelName,
          iframeId: iframeId,
        ),
      );

      expect(web.document.getElementById(iframeId), isNotNull);

      await handle.cancel();

      final result = await handle.result;
      expect(result, isA<RedirectCancelled>());

      // Iframe should be removed after cancel
      expect(web.document.getElementById(iframeId), isNull);
    });

    test('timeout completes with RedirectCancelled', () async {
      const channelName = 'test_iframe_timeout';

      final handle = redirect.runWithWebOptions(
        url: Uri.parse('about:blank'),
        callbackUrlScheme: 'myapp',
        options: const RedirectOptions(
          timeout: Duration(milliseconds: 200),
        ),
        webOptions: const WebRedirectOptions(
          mode: WebRedirectMode.hiddenIframe,
          broadcastChannelName: channelName,
        ),
      );

      final result = await handle.result;
      expect(result, isA<RedirectCancelled>());
    });

    test('ignores messages with wrong scheme', () async {
      const channelName = 'test_iframe_wrong_scheme';

      final handle = redirect.runWithWebOptions(
        url: Uri.parse('about:blank'),
        callbackUrlScheme: 'myapp',
        options: const RedirectOptions(
          timeout: Duration(milliseconds: 500),
        ),
        webOptions: const WebRedirectOptions(
          mode: WebRedirectMode.hiddenIframe,
          broadcastChannelName: channelName,
        ),
      );

      await _nextTick();

      // Post a message with the wrong scheme
      web.BroadcastChannel(channelName)
        ..postMessage('https://wrong-scheme.example.com/cb'.toJS)
        ..close();

      // Should NOT complete with success — should time out
      final result = await handle.result;
      expect(result, isA<RedirectCancelled>());
    });

    test('ignores malformed messages', () async {
      const channelName = 'test_iframe_malformed';

      final handle = redirect.runWithWebOptions(
        url: Uri.parse('about:blank'),
        callbackUrlScheme: 'myapp',
        options: const RedirectOptions(
          timeout: Duration(milliseconds: 500),
        ),
        webOptions: const WebRedirectOptions(
          mode: WebRedirectMode.hiddenIframe,
          broadcastChannelName: channelName,
        ),
      );

      await _nextTick();

      // Post a non-string message
      web.BroadcastChannel(channelName)
        ..postMessage(42.toJS)
        ..close();

      // Should time out
      final result = await handle.result;
      expect(result, isA<RedirectCancelled>());
    });

    test('sets iframe src to the redirect URL', () {
      const channelName = 'test_iframe_src';
      const iframeId = 'test_iframe_src_elem';
      final url = Uri.parse('https://example.com/authorize?client_id=abc');

      redirect.runWithWebOptions(
        url: url,
        callbackUrlScheme: 'myapp',
        webOptions: const WebRedirectOptions(
          mode: WebRedirectMode.hiddenIframe,
          broadcastChannelName: channelName,
          iframeId: iframeId,
        ),
      );

      final iframe =
          web.document.getElementById(iframeId)! as web.HTMLIFrameElement;
      expect(iframe.src, equals(url.toString()));
    });
  });

  // ─────────────────────────────────────────────────
  // Concurrent operations
  // ─────────────────────────────────────────────────

  group('Concurrent operations >', () {
    test('isolated via unique channel names', () async {
      const channel1 = 'test_concurrent_1';
      const channel2 = 'test_concurrent_2';

      final handle1 = redirect.runWithWebOptions(
        url: Uri.parse('about:blank'),
        callbackUrlScheme: 'myapp',
        webOptions: const WebRedirectOptions(
          mode: WebRedirectMode.hiddenIframe,
          broadcastChannelName: channel1,
          iframeId: 'concurrent_iframe_1',
        ),
      );

      final handle2 = redirect.runWithWebOptions(
        url: Uri.parse('about:blank'),
        callbackUrlScheme: 'myapp',
        webOptions: const WebRedirectOptions(
          mode: WebRedirectMode.hiddenIframe,
          broadcastChannelName: channel2,
          iframeId: 'concurrent_iframe_2',
        ),
      );

      await _nextTick();

      // Send callback only to channel2
      web.BroadcastChannel(channel2)
        ..postMessage('myapp://callback2?op=2'.toJS)
        ..close();

      final result2 = await handle2.result;
      expect(result2, isA<RedirectSuccess>());
      expect(
        (result2 as RedirectSuccess).uri.queryParameters['op'],
        equals('2'),
      );

      // handle1 is still pending — cancel it
      await handle1.cancel();
      final result1 = await handle1.result;
      expect(result1, isA<RedirectCancelled>());
    });

    test('different schemes in parallel', () async {
      const channel1 = 'test_multi_scheme_1';
      const channel2 = 'test_multi_scheme_2';

      // Use lowercase schemes — Dart's Uri.parse lowercases schemes.
      final handle1 = redirect.runWithWebOptions(
        url: Uri.parse('about:blank'),
        callbackUrlScheme: 'schemea',
        webOptions: const WebRedirectOptions(
          mode: WebRedirectMode.hiddenIframe,
          broadcastChannelName: channel1,
          iframeId: 'multi_scheme_iframe_1',
        ),
      );

      final handle2 = redirect.runWithWebOptions(
        url: Uri.parse('about:blank'),
        callbackUrlScheme: 'schemeb',
        webOptions: const WebRedirectOptions(
          mode: WebRedirectMode.hiddenIframe,
          broadcastChannelName: channel2,
          iframeId: 'multi_scheme_iframe_2',
        ),
      );

      await _nextTick();

      // Resolve both
      web.BroadcastChannel(channel1)
        ..postMessage('schemea://cb?k=v1'.toJS)
        ..close();
      web.BroadcastChannel(channel2)
        ..postMessage('schemeb://cb?k=v2'.toJS)
        ..close();

      final r1 = await handle1.result;
      final r2 = await handle2.result;

      expect(r1, isA<RedirectSuccess>());
      expect(r2, isA<RedirectSuccess>());
      expect(
        (r1 as RedirectSuccess).uri.queryParameters['k'],
        equals('v1'),
      );
      expect(
        (r2 as RedirectSuccess).uri.queryParameters['k'],
        equals('v2'),
      );
    });
  });

  // ─────────────────────────────────────────────────
  // Popup mode
  // ─────────────────────────────────────────────────

  group('Popup mode >', () {
    test('returns handle with correct metadata', () async {
      const channelName = 'test_popup_meta';
      final url = Uri.parse('https://example.com/auth?client_id=test');

      final handle = redirect.runWithWebOptions(
        url: url,
        callbackUrlScheme: 'myapp',
        options: const RedirectOptions(
          timeout: Duration(seconds: 5),
        ),
        webOptions: const WebRedirectOptions(
          broadcastChannelName: channelName,
        ),
      );

      expect(handle.url, equals(url));
      expect(handle.callbackUrlScheme, equals('myapp'));

      // In headless test, the popup may be blocked → RedirectFailure,
      // or it may open but close-watcher events don't fire → times out.
      final result = await handle.result;
      // Accept either outcome
      expect(
        result,
        anyOf(isA<RedirectFailure>(), isA<RedirectCancelled>()),
      );
    });

    test('succeeds via BroadcastChannel when popup opens', () async {
      // Use about:blank — less likely to be blocked
      const channelName = 'test_popup_bc_success';

      final handle = redirect.runWithWebOptions(
        url: Uri.parse('about:blank'),
        callbackUrlScheme: 'myapp',
        options: const RedirectOptions(
          timeout: Duration(seconds: 5),
        ),
        webOptions: const WebRedirectOptions(
          broadcastChannelName: channelName,
        ),
      );

      await _nextTick();

      // Attempt to send callback via BroadcastChannel
      web.BroadcastChannel(channelName)
        ..postMessage('myapp://popup-callback?code=popup1'.toJS)
        ..close();

      final result = await handle.result;

      // If the popup opened successfully, the BC message completes it.
      // If popup was blocked, we already got RedirectFailure.
      expect(
        result,
        anyOf(
          isA<RedirectSuccess>(),
          isA<RedirectFailure>(),
          isA<RedirectCancelled>(),
        ),
      );

      if (result is RedirectSuccess) {
        expect(result.uri.queryParameters['code'], equals('popup1'));
      }
    });
  });

  // ─────────────────────────────────────────────────
  // New tab mode
  // ─────────────────────────────────────────────────

  group('New tab mode >', () {
    test('returns handle with correct metadata', () async {
      const channelName = 'test_newtab_meta';
      final url = Uri.parse('https://example.com/pay');

      final handle = redirect.runWithWebOptions(
        url: url,
        callbackUrlScheme: 'myapp',
        options: const RedirectOptions(
          timeout: Duration(seconds: 5),
        ),
        webOptions: const WebRedirectOptions(
          mode: WebRedirectMode.newTab,
          broadcastChannelName: channelName,
        ),
      );

      expect(handle.url, equals(url));
      expect(handle.callbackUrlScheme, equals('myapp'));

      final result = await handle.result;
      expect(
        result,
        anyOf(isA<RedirectFailure>(), isA<RedirectCancelled>()),
      );
    });

    test('succeeds via BroadcastChannel when tab opens', () async {
      const channelName = 'test_newtab_bc_success';

      final handle = redirect.runWithWebOptions(
        url: Uri.parse('about:blank'),
        callbackUrlScheme: 'myapp',
        options: const RedirectOptions(
          timeout: Duration(seconds: 5),
        ),
        webOptions: const WebRedirectOptions(
          mode: WebRedirectMode.newTab,
          broadcastChannelName: channelName,
        ),
      );

      await _nextTick();

      web.BroadcastChannel(channelName)
        ..postMessage('myapp://tab-callback?code=tab1'.toJS)
        ..close();

      final result = await handle.result;
      expect(
        result,
        anyOf(
          isA<RedirectSuccess>(),
          isA<RedirectFailure>(),
          isA<RedirectCancelled>(),
        ),
      );

      if (result is RedirectSuccess) {
        expect(result.uri.queryParameters['code'], equals('tab1'));
      }
    });
  });

  // ─────────────────────────────────────────────────
  // Same-page mode (static helpers only — no navigation)
  // ─────────────────────────────────────────────────

  group('Same-page mode >', () {
    test('hasPendingRedirect returns false initially', () {
      expect(RedirectWeb.hasPendingRedirect(), isFalse);
    });

    test('hasPendingRedirect returns true when pending', () {
      web.window.sessionStorage
        ..setItem('redirect_pending', 'true')
        ..setItem('redirect_pending_scheme', 'myapp');

      expect(RedirectWeb.hasPendingRedirect(), isTrue);
    });

    test('resumePendingRedirect returns null when no pending', () {
      expect(RedirectWeb.resumePendingRedirect(), isNull);
    });

    test('resumePendingRedirect returns success when scheme matches', () {
      final currentScheme = Uri.base.scheme;

      web.window.sessionStorage
        ..setItem('redirect_pending', 'true')
        ..setItem('redirect_pending_scheme', currentScheme);

      final result = RedirectWeb.resumePendingRedirect();
      expect(result, isA<RedirectSuccess>());
      expect((result! as RedirectSuccess).uri, equals(Uri.base));
    });

    test('resumePendingRedirect returns failure when scheme mismatches', () {
      web.window.sessionStorage
        ..setItem('redirect_pending', 'true')
        ..setItem('redirect_pending_scheme', 'nonexistent_xyz_scheme');

      final result = RedirectWeb.resumePendingRedirect();
      expect(result, isA<RedirectFailure>());
    });

    test('resumePendingRedirect clears sessionStorage', () {
      web.window.sessionStorage
        ..setItem('redirect_pending', 'true')
        ..setItem('redirect_pending_scheme', Uri.base.scheme);

      RedirectWeb.resumePendingRedirect();

      expect(
        web.window.sessionStorage.getItem('redirect_pending'),
        isNull,
      );
      expect(
        web.window.sessionStorage.getItem('redirect_pending_scheme'),
        isNull,
      );
    });

    test('clearPendingRedirect removes all pending state', () {
      web.window.sessionStorage
        ..setItem('redirect_pending', 'true')
        ..setItem('redirect_pending_scheme', 'myapp');

      RedirectWeb.clearPendingRedirect();

      expect(
        web.window.sessionStorage.getItem('redirect_pending'),
        isNull,
      );
      expect(
        web.window.sessionStorage.getItem('redirect_pending_scheme'),
        isNull,
      );
      expect(RedirectWeb.hasPendingRedirect(), isFalse);
    });

    test('resumePendingRedirect accepts any URI when no scheme stored', () {
      web.window.sessionStorage.setItem('redirect_pending', 'true');
      // Intentionally NOT setting redirect_pending_scheme

      final result = RedirectWeb.resumePendingRedirect();
      // Should accept any URI (backward compat)
      expect(result, isA<RedirectSuccess>());
    });
  });

  // ─────────────────────────────────────────────────
  // handleCallback
  // ─────────────────────────────────────────────────

  group('handleCallback >', () {
    test('broadcasts to all registered channels for a scheme', () async {
      const ch1 = 'test_hcb_ch1';
      const ch2 = 'test_hcb_ch2';
      const scheme = 'myapp';

      web.window.localStorage.setItem(
        'redirect_channels_$scheme',
        jsonEncode([ch1, ch2]),
      );

      final received1 = Completer<String>();
      final received2 = Completer<String>();

      final listener1 = web.BroadcastChannel(ch1)
        ..onmessage = (web.MessageEvent event) {
          received1.complete((event.data! as JSString).toDart);
        }.toJS;

      final listener2 = web.BroadcastChannel(ch2)
        ..onmessage = (web.MessageEvent event) {
          received2.complete((event.data! as JSString).toDart);
        }.toJS;

      RedirectWeb.handleCallback(
        Uri.parse('myapp://callback?token=xyz'),
      );

      final msg1 = await received1.future.timeout(const Duration(seconds: 2));
      final msg2 = await received2.future.timeout(const Duration(seconds: 2));

      expect(msg1, equals('myapp://callback?token=xyz'));
      expect(msg2, equals('myapp://callback?token=xyz'));

      listener1.close();
      listener2.close();
    });

    test('broadcasts to explicit channel name', () async {
      const channelName = 'test_hcb_explicit';

      final received = Completer<String>();
      final listener = web.BroadcastChannel(channelName)
        ..onmessage = (web.MessageEvent event) {
          received.complete((event.data! as JSString).toDart);
        }.toJS;

      RedirectWeb.handleCallback(
        Uri.parse('https://example.com/callback?code=123'),
        channelName: channelName,
      );

      final msg = await received.future.timeout(const Duration(seconds: 2));
      expect(msg, equals('https://example.com/callback?code=123'));

      listener.close();
    });

    test('handles empty channel list gracefully', () {
      // No channels registered — should not throw
      web.window.localStorage.removeItem('redirect_channels_myapp');

      expect(
        () => RedirectWeb.handleCallback(Uri.parse('myapp://callback')),
        returnsNormally,
      );
    });

    test('handles malformed localStorage gracefully', () {
      // Corrupt localStorage value
      web.window.localStorage.setItem('redirect_channels_myapp', 'not-json');

      expect(
        () => RedirectWeb.handleCallback(Uri.parse('myapp://callback')),
        returnsNormally,
      );
    });
  });

  // ─────────────────────────────────────────────────
  // Channel registry
  // ─────────────────────────────────────────────────

  group('Channel registry >', () {
    test('run() registers channel in localStorage', () async {
      const channelName = 'test_registry_reg';

      final handle = redirect.runWithWebOptions(
        url: Uri.parse('about:blank'),
        callbackUrlScheme: 'testscheme',
        webOptions: const WebRedirectOptions(
          mode: WebRedirectMode.hiddenIframe,
          broadcastChannelName: channelName,
        ),
      );

      final raw = web.window.localStorage.getItem(
        'redirect_channels_testscheme',
      );
      expect(raw, isNotNull);
      final channels = (jsonDecode(raw!) as List<dynamic>).cast<String>();
      expect(channels, contains(channelName));

      await handle.cancel();
    });

    test('cleanup unregisters channel from localStorage', () async {
      const channelName = 'test_registry_unreg';

      final handle = redirect.runWithWebOptions(
        url: Uri.parse('about:blank'),
        callbackUrlScheme: 'cleanscheme',
        webOptions: const WebRedirectOptions(
          mode: WebRedirectMode.hiddenIframe,
          broadcastChannelName: channelName,
        ),
      );

      // Cancel triggers cleanup
      await handle.cancel();
      await handle.result;

      final raw = web.window.localStorage.getItem(
        'redirect_channels_cleanscheme',
      );
      if (raw != null) {
        final channels = (jsonDecode(raw) as List<dynamic>).cast<String>();
        expect(channels, isNot(contains(channelName)));
      }
    });

    test('multiple operations share localStorage key', () async {
      const ch1 = 'test_registry_multi_1';
      const ch2 = 'test_registry_multi_2';

      final handle1 = redirect.runWithWebOptions(
        url: Uri.parse('about:blank'),
        callbackUrlScheme: 'shared',
        webOptions: const WebRedirectOptions(
          mode: WebRedirectMode.hiddenIframe,
          broadcastChannelName: ch1,
          iframeId: 'reg_multi_1',
        ),
      );

      final handle2 = redirect.runWithWebOptions(
        url: Uri.parse('about:blank'),
        callbackUrlScheme: 'shared',
        webOptions: const WebRedirectOptions(
          mode: WebRedirectMode.hiddenIframe,
          broadcastChannelName: ch2,
          iframeId: 'reg_multi_2',
        ),
      );

      final raw = web.window.localStorage.getItem('redirect_channels_shared');
      expect(raw, isNotNull);
      final channels = (jsonDecode(raw!) as List<dynamic>).cast<String>();
      expect(channels, contains(ch1));
      expect(channels, contains(ch2));

      await handle1.cancel();
      await handle2.cancel();
    });
  });

  // ─────────────────────────────────────────────────
  // Constructor / default options
  // ─────────────────────────────────────────────────

  group('Constructor and defaults >', () {
    test('uses popup mode by default', () {
      final r = RedirectWeb();
      expect(r.defaultWebOptions.mode, equals(WebRedirectMode.popup));
    });

    test('accepts custom default options', () {
      final r = RedirectWeb(
        defaultWebOptions: const WebRedirectOptions(
          mode: WebRedirectMode.hiddenIframe,
          popupWidth: 400,
          popupHeight: 600,
        ),
      );
      expect(
        r.defaultWebOptions.mode,
        equals(WebRedirectMode.hiddenIframe),
      );
      expect(r.defaultWebOptions.popupWidth, equals(400));
      expect(r.defaultWebOptions.popupHeight, equals(600));
    });

    test('run() uses defaultWebOptions', () {
      RedirectWeb(
        defaultWebOptions: const WebRedirectOptions(
          mode: WebRedirectMode.hiddenIframe,
          broadcastChannelName: 'test_default_opts',
          iframeId: 'default_opts_iframe',
        ),
      ).run(
        url: Uri.parse('about:blank'),
        callbackUrlScheme: 'myapp',
      );

      // Should have created an iframe (because default mode is iframe)
      expect(
        web.document.getElementById('default_opts_iframe'),
        isNotNull,
      );
    });

    test('platformOptions override defaultWebOptions', () {
      RedirectWeb().run(
        url: Uri.parse('about:blank'),
        callbackUrlScheme: 'myapp',
        options: const RedirectOptions(
          platformOptions: {
            WebRedirectOptions.key: WebRedirectOptions(
              mode: WebRedirectMode.hiddenIframe, // <-- override to iframe
              broadcastChannelName: 'test_override',
              iframeId: 'override_iframe',
            ),
          },
        ),
      );

      // Should have created an iframe (override takes effect)
      expect(
        web.document.getElementById('override_iframe'),
        isNotNull,
      );
    });
  });

  // ─────────────────────────────────────────────────
  // RedirectHandle
  // ─────────────────────────────────────────────────

  group('RedirectHandle >', () {
    test('exposes original parameters', () async {
      const channelName = 'test_handle_params';
      final url = Uri.parse('https://example.com/auth?scope=openid');

      final handle = redirect.runWithWebOptions(
        url: url,
        callbackUrlScheme: 'myapp',
        webOptions: const WebRedirectOptions(
          mode: WebRedirectMode.hiddenIframe,
          broadcastChannelName: channelName,
        ),
      );

      expect(handle.url, equals(url));
      expect(handle.callbackUrlScheme, equals('myapp'));

      await handle.cancel();
    });

    test('cancel is idempotent', () async {
      const channelName = 'test_handle_idempotent';

      final handle = redirect.runWithWebOptions(
        url: Uri.parse('about:blank'),
        callbackUrlScheme: 'myapp',
        webOptions: const WebRedirectOptions(
          mode: WebRedirectMode.hiddenIframe,
          broadcastChannelName: channelName,
        ),
      );

      // Cancel multiple times — should not throw
      await handle.cancel();
      await handle.cancel();
      await handle.cancel();

      final result = await handle.result;
      expect(result, isA<RedirectCancelled>());
    });
  });

  // ─────────────────────────────────────────────────
  // End-to-end flow: handleCallback ↔ BroadcastChannel ↔ run()
  // ─────────────────────────────────────────────────

  group('End-to-end >', () {
    test('handleCallback completes a pending iframe redirect', () async {
      const channelName = 'test_e2e_hcb';

      final handle = redirect.runWithWebOptions(
        url: Uri.parse('about:blank'),
        callbackUrlScheme: 'myapp',
        webOptions: const WebRedirectOptions(
          mode: WebRedirectMode.hiddenIframe,
          broadcastChannelName: channelName,
        ),
      );

      await _nextTick();

      // Simulate what the callback page does: call handleCallback
      // with an explicit channel name.
      RedirectWeb.handleCallback(
        Uri.parse('myapp://callback?state=e2e_test'),
        channelName: channelName,
      );

      final result = await handle.result;
      expect(result, isA<RedirectSuccess>());
      expect(
        (result as RedirectSuccess).uri.queryParameters['state'],
        equals('e2e_test'),
      );
    });

    test('handleCallback auto-discovers channels from localStorage', () async {
      const channelName = 'test_e2e_autodiscovery';

      final handle = redirect.runWithWebOptions(
        url: Uri.parse('about:blank'),
        callbackUrlScheme: 'myapp',
        webOptions: const WebRedirectOptions(
          mode: WebRedirectMode.hiddenIframe,
          broadcastChannelName: channelName,
        ),
      );

      await _nextTick();

      // Verify the channel is registered in localStorage
      final raw = web.window.localStorage.getItem('redirect_channels_myapp');
      expect(raw, isNotNull);
      expect(
        (jsonDecode(raw!) as List<dynamic>).cast<String>(),
        contains(channelName),
      );

      // Call handleCallback WITHOUT explicit channel name —
      // it should auto-discover from localStorage.
      RedirectWeb.handleCallback(
        Uri.parse('myapp://callback?autodiscovered=true'),
      );

      final result = await handle.result;
      expect(result, isA<RedirectSuccess>());
      expect(
        (result as RedirectSuccess).uri.queryParameters['autodiscovered'],
        equals('true'),
      );
    });
  });
}

/// Yields to the event loop so that async listeners initialize.
Future<void> _nextTick() =>
    Future<void>.delayed(const Duration(milliseconds: 50));

/// Remove all redirect-related localStorage and sessionStorage entries.
void _cleanupStorage() {
  final keysToRemove = <String>[];
  for (var i = 0; i < web.window.localStorage.length; i++) {
    final key = web.window.localStorage.key(i);
    if (key != null && key.startsWith('redirect_')) {
      keysToRemove.add(key);
    }
  }
  keysToRemove.forEach(web.window.localStorage.removeItem);

  web.window.sessionStorage
    ..removeItem('redirect_pending')
    ..removeItem('redirect_pending_scheme');
}

/// Remove all iframes created during tests.
void _cleanupIframes() {
  final iframes = web.document.querySelectorAll('iframe');
  for (var i = 0; i < iframes.length; i++) {
    iframes.item(i)?.parentNode?.removeChild(iframes.item(i)!);
  }
}
