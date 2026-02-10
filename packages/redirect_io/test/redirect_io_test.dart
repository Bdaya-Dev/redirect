import 'package:redirect_io/redirect_io.dart';
import 'package:test/test.dart';

void main() {
  group('RedirectIo', () {
    test('can create instance with default options', () {
      final io = RedirectIo();
      expect(io.ioOptions.callbackUrl, isNull);
      expect(io.ioOptions.openBrowser, isTrue);
    });

    test('can create instance with custom options', () {
      final io = RedirectIo(
        ioOptions: IoRedirectOptions(
          callbackUrl: Uri.parse('http://127.0.0.1:8080/redirect/callback'),
          openBrowser: false,
        ),
      );

      expect(io.ioOptions.callbackUrl!.host, equals('127.0.0.1'));
      expect(io.ioOptions.callbackUrl!.port, equals(8080));
      expect(io.ioOptions.callbackUrl!.path, equals('/redirect/callback'));
      expect(io.ioOptions.openBrowser, isFalse);
    });

    test('serverPort is null before run', () {
      final io = RedirectIo();
      expect(io.serverPort, isNull);
    });

    test('callbackUrl is null before run', () {
      final io = RedirectIo();
      expect(io.callbackUrl, isNull);
    });
  });

  group('IoRedirectOptions', () {
    test('copyWith creates new instance with replaced fields', () {
      final original = IoRedirectOptions(
        callbackUrl: Uri.parse('http://localhost:8080/callback'),
      );

      final copied = original.copyWith(
        callbackUrl: Uri.parse('http://127.0.0.1:8080/callback'),
      );

      expect(copied.callbackUrl!.host, equals('127.0.0.1'));
    });
  });

  group('AuthorizationException', () {
    test('toString with description', () {
      const exception = AuthorizationException(
        error: 'access_denied',
        description: 'User denied access',
      );
      expect(
        exception.toString(),
        equals('AuthorizationException: access_denied - User denied access'),
      );
    });

    test('toString without description', () {
      const exception = AuthorizationException(error: 'invalid_request');
      expect(
        exception.toString(),
        equals('AuthorizationException: invalid_request'),
      );
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
