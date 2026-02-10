import 'package:redirect_io/redirect_io.dart';
import 'package:test/test.dart';

/// Test subclass that returns default options.
class TestRedirectIo extends RedirectIo {
  @override
  ServerRedirectOptions getOptions(RedirectOptions options) {
    return const ServerRedirectOptions();
  }
}

void main() {
  group('RedirectIo', () {
    test('can create subclass instance', () {
      final io = TestRedirectIo();
      expect(io.serverPortForNonce('nonexistent'), isNull);
    });
  });

  group('RedirectResult', () {
    test('pattern matching works with all cases', () {
      final results = <RedirectResult>[
        RedirectSuccess(uri: Uri.parse('myapp://callback?code=abc')),
        const RedirectCancelled(),
        const RedirectPending(),
        RedirectFailure(error: Exception('test error')),
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
}
