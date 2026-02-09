import 'package:redirect_cli/redirect_cli.dart';
import 'package:test/test.dart';

void main() {
  group('RedirectCli', () {
    test('can create instance with default options', () {
      final cli = RedirectCli();
      expect(cli.cliOptions.port, isNull);
      expect(cli.cliOptions.host, equals('localhost'));
      expect(cli.cliOptions.callbackPath, equals('/callback'));
      expect(cli.cliOptions.openBrowser, isTrue);
    });

    test('can create instance with custom options', () {
      final cli = RedirectCli(
        cliOptions: const CliRedirectOptions(
          port: 8080,
          host: '127.0.0.1',
          callbackPath: '/redirect/callback',
          openBrowser: false,
        ),
      );

      expect(cli.cliOptions.port, equals(8080));
      expect(cli.cliOptions.host, equals('127.0.0.1'));
      expect(cli.cliOptions.callbackPath, equals('/redirect/callback'));
      expect(cli.cliOptions.openBrowser, isFalse);
    });

    test('serverPort is null before run', () {
      final cli = RedirectCli();
      expect(cli.serverPort, isNull);
    });

    test('callbackUrl is null before run', () {
      final cli = RedirectCli();
      expect(cli.callbackUrl, isNull);
    });
  });

  group('CliRedirectOptions', () {
    test('assertion fails if both port and portRange are specified', () {
      expect(
        () => CliRedirectOptions(
          port: 8080,
          portRange: (start: 3000, end: 3100),
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('copyWith creates new instance with replaced fields', () {
      const original = CliRedirectOptions(
        port: 8080,
      );

      final copied = original.copyWith(host: '127.0.0.1');

      expect(copied.port, equals(8080));
      expect(copied.host, equals('127.0.0.1'));
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
