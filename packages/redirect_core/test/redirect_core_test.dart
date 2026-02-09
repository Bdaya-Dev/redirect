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
      expect(options.preferEphemeral, isFalse);
    });

    test('custom values are stored correctly', () {
      const options = RedirectOptions(
        timeout: Duration(seconds: 30),
        preferEphemeral: true,
      );

      expect(options.timeout, equals(const Duration(seconds: 30)));
      expect(options.preferEphemeral, isTrue);
    });

    test('copyWith creates new instance with updated values', () {
      const original = RedirectOptions(
        timeout: Duration(seconds: 30),
      );

      final copied = original.copyWith(preferEphemeral: true);

      expect(copied.timeout, equals(const Duration(seconds: 30)));
      expect(copied.preferEphemeral, isTrue);
      expect(original.preferEphemeral, isFalse);
    });

    test('equality works correctly', () {
      const options1 = RedirectOptions(
        timeout: Duration(seconds: 30),
        preferEphemeral: true,
      );
      const options2 = RedirectOptions(
        timeout: Duration(seconds: 30),
        preferEphemeral: true,
      );

      expect(options1, equals(options2));
      expect(options1.hashCode, equals(options2.hashCode));
    });

    test('toString returns expected format', () {
      const options = RedirectOptions(
        timeout: Duration(seconds: 30),
        preferEphemeral: true,
      );

      expect(
        options.toString(),
        equals(
          'RedirectOptions(timeout: 0:00:30.000000, preferEphemeral: true)',
        ),
      );
    });
  });
}
