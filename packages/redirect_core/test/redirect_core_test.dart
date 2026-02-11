import 'package:redirect_core/redirect_core.dart';
import 'package:test/test.dart';

void main() {
  group('RedirectResult', () {
    group('RedirectSuccess', () {
      test('stores uri correctly', () {
        final uri = Uri.parse('myapp://callback?code=abc123');
        final result = RedirectSuccess(uri: uri);

        expect(result.uri, equals(uri));
      });

      test('equality works correctly', () {
        final uri = Uri.parse('myapp://callback?code=abc123');
        final result1 = RedirectSuccess(uri: uri);
        final result2 = RedirectSuccess(uri: uri);

        expect(result1, equals(result2));
        expect(result1.hashCode, equals(result2.hashCode));
      });

      test('toString returns expected format', () {
        final uri = Uri.parse('myapp://callback');
        final result = RedirectSuccess(uri: uri);

        expect(result.toString(), equals('RedirectSuccess($uri)'));
      });
    });

    group('RedirectCancelled', () {
      test('equality works correctly', () {
        const result1 = RedirectCancelled();
        const result2 = RedirectCancelled();

        expect(result1, equals(result2));
        expect(result1.hashCode, equals(result2.hashCode));
      });

      test('toString returns expected format', () {
        const result = RedirectCancelled();

        expect(result.toString(), equals('RedirectCancelled()'));
      });
    });

    group('RedirectFailure', () {
      test('stores error correctly', () {
        final error = Exception('Something went wrong');
        final result = RedirectFailure(error: error);

        expect(result.error, equals(error));
        expect(result.stackTrace, isNull);
      });

      test('stores error and stack trace correctly', () {
        final error = Exception('Something went wrong');
        final stackTrace = StackTrace.current;
        final result = RedirectFailure(error: error, stackTrace: stackTrace);

        expect(result.error, equals(error));
        expect(result.stackTrace, equals(stackTrace));
      });

      test('equality works correctly', () {
        final error = Exception('error');
        final result1 = RedirectFailure(error: error);
        final result2 = RedirectFailure(error: error);

        expect(result1, equals(result2));
        expect(result1.hashCode, equals(result2.hashCode));
      });

      test('toString returns expected format', () {
        final error = Exception('error');
        final result = RedirectFailure(error: error);

        expect(result.toString(), equals('RedirectFailure($error)'));
      });
    });

    test('pattern matching works with sealed class', () {
      final results = <RedirectResult>[
        RedirectSuccess(uri: Uri.parse('myapp://callback')),
        const RedirectCancelled(),
        const RedirectPending(),
        RedirectFailure(error: Exception('error')),
      ];

      final descriptions = results.map((result) {
        return switch (result) {
          RedirectSuccess(:final uri) => 'success: $uri',
          RedirectCancelled() => 'cancelled',
          RedirectPending() => 'pending',
          RedirectFailure(:final error) => 'failure: $error',
        };
      }).toList();

      expect(descriptions[0], startsWith('success:'));
      expect(descriptions[1], equals('cancelled'));
      expect(descriptions[2], equals('pending'));
      expect(descriptions[3], startsWith('failure:'));
    });
  });

  group('RedirectOptions', () {
    test('default values are correct', () {
      const options = RedirectOptions();

      expect(options.timeout, isNull);
    });

    test('custom values are stored correctly', () {
      const options = RedirectOptions(
        timeout: Duration(seconds: 30),
      );

      expect(options.timeout, equals(const Duration(seconds: 30)));
    });

    test('copyWith creates new instance with updated values', () {
      const original = RedirectOptions(
        timeout: Duration(seconds: 30),
      );

      final copied = original.copyWith(
        timeout: const Duration(seconds: 60),
      );

      expect(copied.timeout, equals(const Duration(seconds: 60)));
      expect(original.timeout, equals(const Duration(seconds: 30)));
    });

    test('equality works correctly', () {
      const options1 = RedirectOptions(
        timeout: Duration(seconds: 30),
      );
      const options2 = RedirectOptions(
        timeout: Duration(seconds: 30),
      );

      expect(options1, equals(options2));
      expect(options1.hashCode, equals(options2.hashCode));
    });

    test('toString returns expected format', () {
      const options = RedirectOptions(
        timeout: Duration(seconds: 30),
      );

      expect(
        options.toString(),
        equals(
          'RedirectOptions(timeout: 0:00:30.000000)',
        ),
      );
    });
  });

  group('WebRedirectOptions', () {
    test('default values are correct', () {
      const options = WebRedirectOptions();

      expect(options.mode, equals(WebRedirectMode.popup));
      expect(options.popupOptions.width, equals(500));
      expect(options.popupOptions.height, equals(700));
      expect(options.popupOptions.left, isNull);
      expect(options.popupOptions.top, isNull);
      expect(options.broadcastChannelName, isNull);
      expect(options.iframeOptions.id, equals('redirect_iframe'));
    });

    test('custom values are stored correctly', () {
      const options = WebRedirectOptions(
        mode: WebRedirectMode.newTab,
        popupOptions: PopupOptions(
          width: 400,
          height: 500,
          left: 100,
          top: 200,
        ),
        broadcastChannelName: 'test_channel',
        iframeOptions: IframeOptions(id: 'test_iframe'),
      );

      expect(options.mode, equals(WebRedirectMode.newTab));
      expect(options.popupOptions.width, equals(400));
      expect(options.popupOptions.height, equals(500));
      expect(options.popupOptions.left, equals(100));
      expect(options.popupOptions.top, equals(200));
      expect(options.broadcastChannelName, equals('test_channel'));
      expect(options.iframeOptions.id, equals('test_iframe'));
    });

    test('fromOptions extracts web options from platformOptions', () {
      const webOpts = WebRedirectOptions(mode: WebRedirectMode.iframe);
      const options = RedirectOptions(
        platformOptions: {WebRedirectOptions.key: webOpts},
      );

      final extracted = WebRedirectOptions.fromOptions(options);

      expect(extracted.mode, equals(WebRedirectMode.iframe));
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
          WebRedirectMode.iframe,
        ]),
      );
    });

    test('each value has a distinct index', () {
      final indices = WebRedirectMode.values.map((v) => v.index).toSet();
      expect(indices.length, equals(WebRedirectMode.values.length));
    });
  });
}
