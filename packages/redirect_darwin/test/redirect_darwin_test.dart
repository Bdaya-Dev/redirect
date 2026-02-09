// Pigeon-generated interface uses pigeonVar_ naming.
// ignore_for_file: non_constant_identifier_names

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redirect_darwin/redirect_darwin.dart';
import 'package:redirect_darwin/src/messages.g.dart';
import 'package:redirect_platform_interface/redirect_platform_interface.dart';

/// A fake [RedirectHostApi] for testing.
class FakeRedirectHostApi implements RedirectHostApi {
  @override
  BinaryMessenger? get pigeonVar_binaryMessenger => null;

  @override
  String get pigeonVar_messageChannelSuffix => '';

  RunRequest? lastRunRequest;
  bool cancelCalled = false;

  String? runResult = 'myapp://callback?code=abc123';
  PlatformException? runException;

  @override
  Future<String?> run(RunRequest request) async {
    lastRunRequest = request;
    if (runException != null) throw runException!;
    return runResult;
  }

  @override
  Future<void> cancel() async {
    cancelCalled = true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RedirectDarwinPlugin', () {
    late RedirectDarwinPlugin redirect;
    late FakeRedirectHostApi fakeApi;

    setUp(() {
      fakeApi = FakeRedirectHostApi();
      redirect = RedirectDarwinPlugin(api: fakeApi);
    });

    test('can be registered', () {
      RedirectDarwinPlugin.registerWith();
      expect(RedirectPlatform.instance, isA<RedirectDarwinPlugin>());
    });

    test('run sends correct request arguments', () async {
      final url = Uri.parse('https://auth.example.com/authorize');
      final handle = redirect.run(
        url: url,
        callbackUrlScheme: 'myapp',
      );
      await handle.result;

      final req = fakeApi.lastRunRequest!;
      expect(req.url, equals(url.toString()));
      expect(req.callbackUrlScheme, equals('myapp'));
      expect(req.preferEphemeral, isFalse);
    });

    test('run passes preferEphemeral option', () async {
      final handle = redirect.run(
        url: Uri.parse('https://auth.example.com/authorize'),
        callbackUrlScheme: 'myapp',
        options: const RedirectOptions(preferEphemeral: true),
      );
      await handle.result;

      expect(fakeApi.lastRunRequest!.preferEphemeral, isTrue);
    });

    test('run passes timeout option', () async {
      final handle = redirect.run(
        url: Uri.parse('https://auth.example.com/authorize'),
        callbackUrlScheme: 'myapp',
        options: const RedirectOptions(timeout: Duration(seconds: 30)),
      );
      await handle.result;

      expect(fakeApi.lastRunRequest!.timeoutMillis, equals(30000));
    });

    test('run returns RedirectSuccess on valid result', () async {
      final handle = redirect.run(
        url: Uri.parse('https://auth.example.com/authorize'),
        callbackUrlScheme: 'myapp',
      );
      final result = await handle.result;

      expect(result, isA<RedirectSuccess>());
      expect(
        (result as RedirectSuccess).uri,
        equals(Uri.parse('myapp://callback?code=abc123')),
      );
    });

    test('run returns RedirectCancelled on null result', () async {
      fakeApi.runResult = null;

      final handle = redirect.run(
        url: Uri.parse('https://auth.example.com/authorize'),
        callbackUrlScheme: 'myapp',
      );
      final result = await handle.result;

      expect(result, isA<RedirectCancelled>());
    });

    test(
      'run returns RedirectCancelled on CANCELLED PlatformException',
      () async {
        fakeApi.runException = PlatformException(code: 'CANCELLED');

        final handle = redirect.run(
          url: Uri.parse('https://auth.example.com/authorize'),
          callbackUrlScheme: 'myapp',
        );
        final result = await handle.result;

        expect(result, isA<RedirectCancelled>());
      },
    );

    test('run returns RedirectFailure on other PlatformException', () async {
      fakeApi.runException = PlatformException(
        code: 'ERROR',
        message: 'Something failed',
      );

      final handle = redirect.run(
        url: Uri.parse('https://auth.example.com/authorize'),
        callbackUrlScheme: 'myapp',
      );
      final result = await handle.result;

      expect(result, isA<RedirectFailure>());
      expect(
        (result as RedirectFailure).error,
        isA<PlatformException>(),
      );
    });

    test('cancel calls the api', () async {
      final handle = redirect.run(
        url: Uri.parse('https://auth.example.com/authorize'),
        callbackUrlScheme: 'myapp',
      );
      await handle.cancel();

      expect(fakeApi.cancelCalled, isTrue);
    });
  });
}
