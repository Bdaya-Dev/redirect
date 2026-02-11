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
  String? lastCancelledNonce;

  String? runResult = 'myapp://callback?code=abc123';
  PlatformException? runException;

  @override
  Future<String?> run(RunRequest request) async {
    lastRunRequest = request;
    if (runException != null) throw runException!;
    return runResult;
  }

  @override
  Future<void> cancel(String nonce) async {
    cancelCalled = true;
    lastCancelledNonce = nonce;
  }
}

/// Default options to use in tests.
const _defaultIosOptions = RedirectOptions(
  platformOptions: {
    IosRedirectOptions.key: IosRedirectOptions(
      callback: CallbackConfig.customScheme('myapp'),
    ),
  },
);

const _defaultMacosOptions = RedirectOptions(
  platformOptions: {
    MacosRedirectOptions.key: MacosRedirectOptions(
      callback: CallbackConfig.customScheme('myapp'),
    ),
  },
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RedirectIosPlugin', () {
    late RedirectIosPlugin redirect;
    late FakeRedirectHostApi fakeApi;

    setUp(() {
      fakeApi = FakeRedirectHostApi();
      redirect = RedirectIosPlugin(api: fakeApi);
    });

    test('can be registered', () {
      RedirectIosPlugin.registerWith();
      expect(RedirectPlatform.instance, isA<RedirectIosPlugin>());
    });

    test('run sends correct request arguments', () async {
      final url = Uri.parse('https://auth.example.com/authorize');
      final handle = redirect.run(
        url: url,
        options: _defaultIosOptions,
      );
      await handle.result;

      final req = fakeApi.lastRunRequest!;
      expect(req.nonce, equals(handle.nonce));
      expect(req.url, equals(url.toString()));
      expect(req.callback.type, equals(CallbackType.customScheme));
      expect(req.callback.scheme, equals('myapp'));
      expect(req.preferEphemeral, isFalse);
    });

    test('run passes preferEphemeral option', () async {
      final handle = redirect.run(
        url: Uri.parse('https://auth.example.com/authorize'),
        options: const RedirectOptions(
          platformOptions: {
            IosRedirectOptions.key: IosRedirectOptions(
              callback: CallbackConfig.customScheme('myapp'),
              preferEphemeral: true,
            ),
          },
        ),
      );
      await handle.result;

      expect(fakeApi.lastRunRequest!.preferEphemeral, isTrue);
    });

    test('run passes timeout option', () async {
      final handle = redirect.run(
        url: Uri.parse('https://auth.example.com/authorize'),
        options: _defaultIosOptions.copyWith(
          timeout: const Duration(seconds: 30),
        ),
      );
      await handle.result;

      expect(fakeApi.lastRunRequest!.timeoutMillis, equals(30000));
    });

    test('run returns RedirectSuccess on valid result', () async {
      final handle = redirect.run(
        url: Uri.parse('https://auth.example.com/authorize'),
        options: _defaultIosOptions,
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
        options: _defaultIosOptions,
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
          options: _defaultIosOptions,
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
        options: _defaultIosOptions,
      );
      final result = await handle.result;

      expect(result, isA<RedirectFailure>());
      expect(
        (result as RedirectFailure).error,
        isA<PlatformException>(),
      );
    });

    test('cancel calls the api with correct nonce', () async {
      final handle = redirect.run(
        url: Uri.parse('https://auth.example.com/authorize'),
        options: _defaultIosOptions,
      );
      await handle.cancel();

      expect(fakeApi.cancelCalled, isTrue);
      expect(fakeApi.lastCancelledNonce, equals(handle.nonce));
    });
  });

  group('RedirectMacosPlugin', () {
    late RedirectMacosPlugin redirect;
    late FakeRedirectHostApi fakeApi;

    setUp(() {
      fakeApi = FakeRedirectHostApi();
      redirect = RedirectMacosPlugin(api: fakeApi);
    });

    test('can be registered', () {
      RedirectMacosPlugin.registerWith();
      expect(RedirectPlatform.instance, isA<RedirectMacosPlugin>());
    });

    test('run returns RedirectSuccess on valid result', () async {
      final handle = redirect.run(
        url: Uri.parse('https://auth.example.com/authorize'),
        options: _defaultMacosOptions,
      );
      final result = await handle.result;

      expect(result, isA<RedirectSuccess>());
      expect(
        (result as RedirectSuccess).uri,
        equals(Uri.parse('myapp://callback?code=abc123')),
      );
    });

    test('cancel calls the api', () async {
      final handle = redirect.run(
        url: Uri.parse('https://auth.example.com/authorize'),
        options: _defaultMacosOptions,
      );
      await handle.cancel();

      expect(fakeApi.cancelCalled, isTrue);
    });
  });
}
