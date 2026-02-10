// Tests that EXECUTE the embedded JS assets in a real Chrome browser.
//
// - callbackJs: sets up localStorage channels, runs the IIFE, and verifies
//   that BroadcastChannel receives the URL, multiple channels work, errors
//   are tolerated, and window.close() is scheduled.
//
// - serviceWorkerJs message handler: runs the SW code inside an IIFE with
//   a mock `self`, then invokes the captured message handler and verifies
//   that callbackPath / channels state is updated correctly.
//
// - serviceWorkerJs fetch handler: same IIFE approach with a mock
//   BroadcastChannel constructor, invokes the captured fetch handler and
//   verifies that broadcasts go to the right channels (or don't, when
//   origin/path/mode don't match).
//
// Run with:
//   cd packages/redirect_web_core
//   dart test -p chrome test/redirect_web_assets_browser_test.dart

@TestOn('browser')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:redirect_web_core/src/redirect_web_assets.dart';
import 'package:test/test.dart';
import 'package:web/web.dart' as web;

@JS('eval')
external JSAny? jsEval(String code);

void main() {
  // ─────────────────────────────────────────────────
  // callbackJs — actual execution in the browser
  // ─────────────────────────────────────────────────

  group('callbackJs execution >', () {
    late String scheme;
    late String storageKey;

    setUp(() {
      scheme = web.window.location.protocol.replaceAll(':', '');
      storageKey = 'redirect_channels_$scheme';

      // Prevent window.close() from killing the test browser.
      jsEval('''
        window.__origClose = window.close;
        window.__closeCalled = false;
        window.close = function() { window.__closeCalled = true; };
      ''');
    });

    tearDown(() {
      jsEval('if (window.__origClose) window.close = window.__origClose;');
      web.window.localStorage.removeItem(storageKey);
      jsEval("history.replaceState(null, '', window.location.pathname)");
    });

    test('broadcasts current URL to a registered channel', () async {
      const channelName = 'test_cb_broadcast';
      web.window.localStorage.setItem(storageKey, jsonEncode([channelName]));

      final received = Completer<String>();
      final bc = web.BroadcastChannel(channelName)
        ..onmessage = (web.MessageEvent e) {
          received.complete((e.data! as JSString).toDart);
        }.toJS;

      try {
        jsEval(RedirectWebAssets.callbackJs);

        final url = await received.future.timeout(const Duration(seconds: 3));
        expect(url, equals(web.window.location.href));
      } finally {
        bc.close();
      }
    });

    test('broadcasts to multiple channels simultaneously', () async {
      const ch1 = 'test_cb_multi_1';
      const ch2 = 'test_cb_multi_2';
      web.window.localStorage.setItem(storageKey, jsonEncode([ch1, ch2]));

      final r1 = Completer<String>();
      final r2 = Completer<String>();

      final bc1 = web.BroadcastChannel(ch1)
        ..onmessage = (web.MessageEvent e) {
          r1.complete((e.data! as JSString).toDart);
        }.toJS;
      final bc2 = web.BroadcastChannel(ch2)
        ..onmessage = (web.MessageEvent e) {
          r2.complete((e.data! as JSString).toDart);
        }.toJS;

      try {
        jsEval(RedirectWebAssets.callbackJs);

        final url1 = await r1.future.timeout(const Duration(seconds: 3));
        final url2 = await r2.future.timeout(const Duration(seconds: 3));

        expect(url1, equals(web.window.location.href));
        expect(url2, equals(web.window.location.href));
      } finally {
        bc1.close();
        bc2.close();
      }
    });

    test('tolerates empty channel list', () {
      web.window.localStorage.setItem(storageKey, '[]');
      jsEval(RedirectWebAssets.callbackJs); // must not throw
    });

    test('tolerates missing localStorage key', () {
      web.window.localStorage.removeItem(storageKey);
      jsEval(RedirectWebAssets.callbackJs); // must not throw
    });

    test('tolerates corrupt localStorage value', () {
      web.window.localStorage.setItem(storageKey, 'not-json!!!');
      jsEval(RedirectWebAssets.callbackJs); // must not throw
    });

    test('schedules window.close via setTimeout', () async {
      web.window.localStorage.removeItem(storageKey);
      jsEval(RedirectWebAssets.callbackJs);

      // Must NOT close synchronously.
      final before = (jsEval('window.__closeCalled') as JSBoolean).toDart;
      expect(before, isFalse);

      // Wait past the 1500 ms timeout + buffer.
      await Future<void>.delayed(const Duration(milliseconds: 2000));

      final after = (jsEval('window.__closeCalled') as JSBoolean).toDart;
      expect(after, isTrue);
    });

    test('uses _scheme query-parameter override', () async {
      const customScheme = 'custom';
      const channelName = 'test_cb_scheme_override';
      final customKey = 'redirect_channels_$customScheme';
      web.window.localStorage.setItem(customKey, jsonEncode([channelName]));

      final received = Completer<String>();
      final bc = web.BroadcastChannel(channelName)
        ..onmessage = (web.MessageEvent e) {
          received.complete((e.data! as JSString).toDart);
        }.toJS;

      try {
        // Inject _scheme into the URL.
        jsEval("history.replaceState(null, '', '?_scheme=$customScheme')");
        jsEval(RedirectWebAssets.callbackJs);

        final url = await received.future.timeout(const Duration(seconds: 3));
        expect(url, contains('_scheme=$customScheme'));
      } finally {
        bc.close();
        web.window.localStorage.removeItem(customKey);
      }
    });
  });

  // ─────────────────────────────────────────────────
  // serviceWorkerJs — message handler
  // ─────────────────────────────────────────────────
  //
  // Strategy: wrap the SW source in an IIFE with a local `self` that
  // shadows the global (window).  The mock `self.addEventListener`
  // captures each handler. After eval, we call handlers directly and
  // inspect state via exported accessors.

  group('serviceWorkerJs message handler >', () {
    setUp(() {
      jsEval('''
        (function() {
          var self = {
            _listeners: {},
            addEventListener: function(type, fn) {
              this._listeners[type] = fn;
            },
            skipWaiting: function() {},
            clients: {
              claim: function() { return Promise.resolve(); }
            },
            location: { origin: 'http://test.local' }
          };

          ${RedirectWebAssets.serviceWorkerJs}

          window.__sw = {
            listeners: self._listeners,
            getCallbackPath: function() { return callbackPath; },
            getChannels: function() { return Array.from(channels); }
          };
        })();
      ''');
    });

    tearDown(() {
      jsEval('delete window.__sw;');
    });

    test('registers all four event listeners', () {
      for (final type in ['message', 'install', 'activate', 'fetch']) {
        final kind =
            (jsEval("typeof window.__sw.listeners['$type']") as JSString)
                .toDart;
        expect(kind, equals('function'), reason: '$type handler missing');
      }
    });

    test('default callbackPath is /callback', () {
      final path = (jsEval('window.__sw.getCallbackPath()') as JSString).toDart;
      expect(path, equals('/callback'));
    });

    test('redirect_config updates callbackPath', () {
      jsEval('''
        window.__sw.listeners.message({
          data: { type: 'redirect_config', callbackPath: '/auth/done' }
        });
      ''');

      final path = (jsEval('window.__sw.getCallbackPath()') as JSString).toDart;
      expect(path, equals('/auth/done'));
    });

    test('redirect_register adds a channel', () {
      jsEval('''
        window.__sw.listeners.message({
          data: { type: 'redirect_register', channel: 'ch_alpha' }
        });
      ''');

      final channels = _parseJsonArray('window.__sw.getChannels()');
      expect(channels, contains('ch_alpha'));
    });

    test('redirect_register adds multiple channels', () {
      jsEval('''
        window.__sw.listeners.message({
          data: { type: 'redirect_register', channel: 'ch_1' }
        });
        window.__sw.listeners.message({
          data: { type: 'redirect_register', channel: 'ch_2' }
        });
        window.__sw.listeners.message({
          data: { type: 'redirect_register', channel: 'ch_3' }
        });
      ''');

      final channels = _parseJsonArray('window.__sw.getChannels()');
      expect(channels, containsAll(['ch_1', 'ch_2', 'ch_3']));
    });

    test('redirect_unregister removes a channel', () {
      jsEval('''
        window.__sw.listeners.message({
          data: { type: 'redirect_register', channel: 'ch_stay' }
        });
        window.__sw.listeners.message({
          data: { type: 'redirect_register', channel: 'ch_go' }
        });
        window.__sw.listeners.message({
          data: { type: 'redirect_unregister', channel: 'ch_go' }
        });
      ''');

      final channels = _parseJsonArray('window.__sw.getChannels()');
      expect(channels, contains('ch_stay'));
      expect(channels, isNot(contains('ch_go')));
    });

    test('ignores messages without data or type', () {
      // None of these should throw.
      jsEval('window.__sw.listeners.message({});');
      jsEval('window.__sw.listeners.message({ data: null });');
      jsEval('window.__sw.listeners.message({ data: {} });');
    });

    test('ignores unknown message types', () {
      jsEval('''
        window.__sw.listeners.message({
          data: { type: 'unknown_xyz' }
        });
      ''');

      final path = (jsEval('window.__sw.getCallbackPath()') as JSString).toDart;
      expect(path, equals('/callback'));
    });
  });

  // ─────────────────────────────────────────────────
  // serviceWorkerJs — fetch handler
  // ─────────────────────────────────────────────────
  //
  // Same IIFE approach, but also overrides `BroadcastChannel` with a
  // mock that records every `postMessage` call.

  group('serviceWorkerJs fetch handler >', () {
    setUp(() {
      jsEval('''
        (function() {
          var __broadcasts = [];
          var __OrigBC = window.BroadcastChannel;

          var self = {
            _listeners: {},
            addEventListener: function(type, fn) {
              this._listeners[type] = fn;
            },
            skipWaiting: function() {},
            clients: {
              claim: function() { return Promise.resolve(); }
            },
            location: { origin: 'http://test.local' }
          };

          // Mock BroadcastChannel to capture broadcasts.
          window.BroadcastChannel = function(name) {
            return {
              postMessage: function(msg) {
                __broadcasts.push({ channel: name, message: msg });
              },
              close: function() {}
            };
          };

          ${RedirectWebAssets.serviceWorkerJs}

          window.__swf = {
            listeners: self._listeners,
            fire: function(ev) { self._listeners.fetch(ev); },
            msg:  function(d)  { self._listeners.message({ data: d }); },
            getBroadcasts:    function() { return __broadcasts; },
            clearBroadcasts:  function() { __broadcasts = []; },
            getCallbackPath:  function() { return callbackPath; }
          };
          window.__swf_origBC = __OrigBC;
        })();
      ''');
    });

    tearDown(() {
      jsEval('''
        if (window.__swf_origBC) {
          window.BroadcastChannel = window.__swf_origBC;
        }
        delete window.__swf;
        delete window.__swf_origBC;
      ''');
    });

    test('broadcasts callback URL to registered channels', () {
      jsEval('''
        window.__swf.msg({
          type: 'redirect_register', channel: 'fetch_ch_1'
        });
        window.__swf.msg({
          type: 'redirect_register', channel: 'fetch_ch_2'
        });
      ''');

      jsEval('''
        window.__swf.fire({
          request: {
            url: 'http://test.local/callback?code=xyz',
            mode: 'navigate'
          }
        });
      ''');

      final broadcasts = _parseJsonArray('window.__swf.getBroadcasts()');
      expect(broadcasts, hasLength(2));

      final names = broadcasts
          .cast<Map<String, dynamic>>()
          .map((b) => b['channel'])
          .toSet();
      expect(names, containsAll(['fetch_ch_1', 'fetch_ch_2']));

      for (final b in broadcasts.cast<Map<String, dynamic>>()) {
        expect(b['message'], equals('http://test.local/callback?code=xyz'));
      }
    });

    test('does NOT call event.respondWith', () {
      jsEval('''
        window.__swf.msg({
          type: 'redirect_register', channel: 'rw_ch'
        });
      ''');

      // If respondWith is called, the Error propagates and the test fails.
      jsEval('''
        window.__swf.fire({
          request: {
            url: 'http://test.local/callback',
            mode: 'navigate'
          },
          respondWith: function() {
            throw new Error('respondWith must NOT be called');
          }
        });
      ''');
    });

    test('ignores non-navigate requests', () {
      jsEval('''
        window.__swf.msg({
          type: 'redirect_register', channel: 'nav_ch'
        });
        window.__swf.clearBroadcasts();
        window.__swf.fire({
          request: {
            url: 'http://test.local/callback',
            mode: 'cors'
          }
        });
      ''');

      expect(_parseJsonArray('window.__swf.getBroadcasts()'), isEmpty);
    });

    test('ignores requests to wrong origin', () {
      jsEval('''
        window.__swf.msg({
          type: 'redirect_register', channel: 'origin_ch'
        });
        window.__swf.clearBroadcasts();
        window.__swf.fire({
          request: {
            url: 'http://other.local/callback',
            mode: 'navigate'
          }
        });
      ''');

      expect(_parseJsonArray('window.__swf.getBroadcasts()'), isEmpty);
    });

    test('ignores requests to wrong path', () {
      jsEval('''
        window.__swf.msg({
          type: 'redirect_register', channel: 'path_ch'
        });
        window.__swf.clearBroadcasts();
        window.__swf.fire({
          request: {
            url: 'http://test.local/other-path',
            mode: 'navigate'
          }
        });
      ''');

      expect(_parseJsonArray('window.__swf.getBroadcasts()'), isEmpty);
    });

    test('respects custom callbackPath from redirect_config', () {
      jsEval('''
        window.__swf.msg({
          type: 'redirect_config', callbackPath: '/auth/done'
        });
        window.__swf.msg({
          type: 'redirect_register', channel: 'custom_path_ch'
        });
        window.__swf.clearBroadcasts();
      ''');

      // Old path — ignored.
      jsEval('''
        window.__swf.fire({
          request: {
            url: 'http://test.local/callback',
            mode: 'navigate'
          }
        });
      ''');
      expect(_parseJsonArray('window.__swf.getBroadcasts()'), isEmpty);

      // New path — broadcasts.
      jsEval('''
        window.__swf.fire({
          request: {
            url: 'http://test.local/auth/done?token=abc',
            mode: 'navigate'
          }
        });
      ''');

      final broadcasts = _parseJsonArray('window.__swf.getBroadcasts()');
      expect(broadcasts, hasLength(1));
      expect(
        (broadcasts.first as Map<String, dynamic>)['message'],
        equals('http://test.local/auth/done?token=abc'),
      );
    });

    test('does not broadcast when no channels are registered', () {
      jsEval('''
        window.__swf.clearBroadcasts();
        window.__swf.fire({
          request: {
            url: 'http://test.local/callback',
            mode: 'navigate'
          }
        });
      ''');

      expect(_parseJsonArray('window.__swf.getBroadcasts()'), isEmpty);
    });
  });
}

/// Evaluates [expr] (which must return a JS array) and returns it as a
/// decoded Dart List.
List<dynamic> _parseJsonArray(String expr) {
  final json = (jsEval('JSON.stringify($expr)') as JSString).toDart;
  return jsonDecode(json) as List<dynamic>;
}
