@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:redirect_platform_interface/redirect_platform_interface.dart';
import 'package:redirect_web/redirect_web.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RedirectWebPlugin', () {
    test('can be registered', () {
      RedirectWebPlugin.registerWith();
      expect(RedirectPlatform.instance, isA<RedirectWebPlugin>());
    });

    test('registration replaces default platform instance', () {
      final previousInstance = RedirectPlatform.instance;
      RedirectWebPlugin.registerWith();
      final newInstance = RedirectPlatform.instance;
      expect(newInstance, isA<RedirectWebPlugin>());
      expect(
        identical(previousInstance, newInstance),
        isFalse,
      );
    });

    test('run() returns a valid RedirectHandle', () {
      RedirectWebPlugin.registerWith();
      final plugin = RedirectPlatform.instance;

      final handle = plugin.run(
        url: Uri.parse('about:blank'),
        options: const RedirectOptions(
          timeout: Duration(milliseconds: 200),
          platformOptions: {
            WebRedirectOptions.key: WebRedirectOptions(
              mode: WebRedirectMode.iframe,
              broadcastChannelName: 'test_plugin_run',
              iframeOptions: IframeOptions(id: 'test_plugin_iframe'),
            ),
          },
        ),
      );

      expect(handle.url, equals(Uri.parse('about:blank')));
    });

    test('run() delegates to core RedirectWeb', () async {
      final plugin = RedirectWebPlugin();

      final handle = plugin.run(
        url: Uri.parse('about:blank'),
        options: const RedirectOptions(
          timeout: Duration(milliseconds: 100),
          platformOptions: {
            WebRedirectOptions.key: WebRedirectOptions(
              mode: WebRedirectMode.iframe,
              broadcastChannelName: 'test_delegation',
              iframeOptions: IframeOptions(id: 'test_delegation_iframe'),
            ),
          },
        ),
      );

      expect(handle.url, equals(Uri.parse('about:blank')));

      // Times out → RedirectCancelled
      final result = await handle.result;
      expect(result, isA<RedirectCancelled>());
    });

    test('can be instantiated without arguments', () {
      final plugin = RedirectWebPlugin();
      expect(plugin, isA<RedirectPlatform>());
    });

    test('multiple handles can run concurrently', () async {
      final plugin = RedirectWebPlugin();

      final handle1 = plugin.run(
        url: Uri.parse('about:blank'),
        options: const RedirectOptions(
          timeout: Duration(milliseconds: 200),
          platformOptions: {
            WebRedirectOptions.key: WebRedirectOptions(
              mode: WebRedirectMode.iframe,
              broadcastChannelName: 'test_multi_1',
              iframeOptions: IframeOptions(id: 'test_multi_iframe_1'),
            ),
          },
        ),
      );

      final handle2 = plugin.run(
        url: Uri.parse('about:blank'),
        options: const RedirectOptions(
          timeout: Duration(milliseconds: 200),
          platformOptions: {
            WebRedirectOptions.key: WebRedirectOptions(
              mode: WebRedirectMode.iframe,
              broadcastChannelName: 'test_multi_2',
              iframeOptions: IframeOptions(id: 'test_multi_iframe_2'),
            ),
          },
        ),
      );

      // Both should complete (via timeout)
      final results = await Future.wait([handle1.result, handle2.result]);
      expect(results, hasLength(2));
    });
  });
}
