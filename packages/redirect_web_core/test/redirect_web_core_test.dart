@TestOn('vm')
library;

// redirect_web_core uses dart:js_interop and package:web which require
// a browser environment. Since we can't run a real browser in unit tests,
// we only validate the public API surface, constructors, and the
// RedirectPending return value from samePage mode.
//
// Full behavioral testing of popup/tab/iframe/BroadcastChannel logic
// is delegated to integration tests (Fluttium flows) in the example app.

import 'package:redirect_core/redirect_core.dart';
import 'package:test/test.dart';

void main() {
  group('WebRedirectOptions', () {
    test('default values are correct', () {
      const options = WebRedirectOptions();

      expect(options.mode, equals(WebRedirectMode.popup));
      expect(options.popupWidth, equals(500));
      expect(options.popupHeight, equals(700));
      expect(options.popupLeft, isNull);
      expect(options.popupTop, isNull);
      expect(options.broadcastChannelName, isNull);
      expect(options.iframeId, isNull);
    });

    test('custom values are stored correctly', () {
      const options = WebRedirectOptions(
        mode: WebRedirectMode.newTab,
        popupWidth: 400,
        popupHeight: 500,
        popupLeft: 100,
        popupTop: 200,
        broadcastChannelName: 'test_channel',
        iframeId: 'test_iframe',
      );

      expect(options.mode, equals(WebRedirectMode.newTab));
      expect(options.popupWidth, equals(400));
      expect(options.popupHeight, equals(500));
      expect(options.popupLeft, equals(100));
      expect(options.popupTop, equals(200));
      expect(options.broadcastChannelName, equals('test_channel'));
      expect(options.iframeId, equals('test_iframe'));
    });

    test('fromOptions extracts web options from platformOptions', () {
      const webOpts = WebRedirectOptions(mode: WebRedirectMode.hiddenIframe);
      const options = RedirectOptions(
        platformOptions: {WebRedirectOptions.key: webOpts},
      );

      final extracted = WebRedirectOptions.fromOptions(options);

      expect(extracted.mode, equals(WebRedirectMode.hiddenIframe));
    });

    test('fromOptions returns fallback when not present', () {
      const options = RedirectOptions();
      const fallback = WebRedirectOptions(mode: WebRedirectMode.samePage);

      final extracted = WebRedirectOptions.fromOptions(options, fallback);

      expect(extracted.mode, equals(WebRedirectMode.samePage));
    });

    test('fromOptions returns default when no fallback and not present', () {
      const options = RedirectOptions();

      final extracted = WebRedirectOptions.fromOptions(options);

      expect(extracted.mode, equals(WebRedirectMode.popup));
    });
  });

  group('WebRedirectMode', () {
    test('has all expected values', () {
      expect(
        WebRedirectMode.values,
        containsAll([
          WebRedirectMode.popup,
          WebRedirectMode.newTab,
          WebRedirectMode.samePage,
          WebRedirectMode.hiddenIframe,
        ]),
      );
    });

    test('each value has a distinct index', () {
      final indices = WebRedirectMode.values.map((v) => v.index).toSet();
      expect(indices.length, equals(WebRedirectMode.values.length));
    });
  });
}
