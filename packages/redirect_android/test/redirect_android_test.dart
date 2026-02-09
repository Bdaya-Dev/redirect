import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redirect_android/redirect_android.dart';
import 'package:redirect_android/src/messages.g.dart';
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

  group('RedirectAndroidPlugin', () {
    late RedirectAndroidPlugin redirect;
    late FakeRedirectHostApi fakeApi;

    setUp(() {
      fakeApi = FakeRedirectHostApi();
      redirect = RedirectAndroidPlugin(api: fakeApi);
    });

    test('can be registered', () {
      RedirectAndroidPlugin.registerWith();
      expect(RedirectPlatform.instance, isA<RedirectAndroidPlugin>());
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
      expect(req.androidOptions.useCustomTabs, isTrue);
      expect(req.androidOptions.showTitle, isFalse);
      expect(req.androidOptions.enableUrlBarHiding, isFalse);
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

    test('run sends default androidOptions', () async {
      final handle = redirect.run(
        url: Uri.parse('https://auth.example.com/authorize'),
        callbackUrlScheme: 'myapp',
      );
      await handle.result;

      final opts = fakeApi.lastRunRequest!.androidOptions;
      expect(opts.useCustomTabs, isTrue);
      expect(opts.showTitle, isFalse);
      expect(opts.enableUrlBarHiding, isFalse);
      expect(opts.toolbarColor, isNull);
      expect(opts.secondaryToolbarColor, isNull);
    });

    test('run sends custom androidOptions via platformOptions', () async {
      const androidOpts = AndroidRedirectOptions(
        useCustomTabs: false,
        showTitle: true,
        enableUrlBarHiding: true,
        toolbarColor: 0xFF0000FF,
        secondaryToolbarColor: 0xFFFF0000,
      );

      final handle = redirect.run(
        url: Uri.parse('https://auth.example.com/authorize'),
        callbackUrlScheme: 'myapp',
        options: RedirectOptions(
          platformOptions: {AndroidRedirectOptions.key: androidOpts},
        ),
      );
      await handle.result;

      final opts = fakeApi.lastRunRequest!.androidOptions;
      expect(opts.useCustomTabs, isFalse);
      expect(opts.showTitle, isTrue);
      expect(opts.enableUrlBarHiding, isTrue);
      expect(opts.toolbarColor, equals(0xFF0000FF));
      expect(opts.secondaryToolbarColor, equals(0xFFFF0000));
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

  group('AndroidRedirectOptions', () {
    test('default values are correct', () {
      const options = AndroidRedirectOptions();

      expect(options.preferEphemeral, isNull);
      expect(options.useCustomTabs, isTrue);
      expect(options.showTitle, isFalse);
      expect(options.enableUrlBarHiding, isFalse);
      expect(options.toolbarColor, isNull);
      expect(options.secondaryToolbarColor, isNull);
    });

    test('custom values are stored correctly', () {
      const options = AndroidRedirectOptions(
        preferEphemeral: true,
        useCustomTabs: false,
        showTitle: true,
        enableUrlBarHiding: true,
        toolbarColor: 0xFF0000FF,
        secondaryToolbarColor: 0xFFFF0000,
      );

      expect(options.preferEphemeral, isTrue);
      expect(options.useCustomTabs, isFalse);
      expect(options.showTitle, isTrue);
      expect(options.enableUrlBarHiding, isTrue);
      expect(options.toolbarColor, equals(0xFF0000FF));
      expect(options.secondaryToolbarColor, equals(0xFFFF0000));
    });

    test('fromOptions extracts android options from platformOptions', () {
      const androidOpts = AndroidRedirectOptions(showTitle: true);
      final options = RedirectOptions(
        platformOptions: {AndroidRedirectOptions.key: androidOpts},
      );

      final extracted = AndroidRedirectOptions.fromOptions(options);

      expect(extracted.showTitle, isTrue);
    });

    test('fromOptions returns fallback when not present', () {
      const options = RedirectOptions();
      const fallback = AndroidRedirectOptions(showTitle: true);

      final extracted = AndroidRedirectOptions.fromOptions(options, fallback);

      expect(extracted.showTitle, isTrue);
    });

    test('fromOptions returns default when no fallback and not present', () {
      const options = RedirectOptions();

      final extracted = AndroidRedirectOptions.fromOptions(options);

      expect(extracted.useCustomTabs, isTrue);
      expect(extracted.showTitle, isFalse);
    });

    test('key is android', () {
      expect(AndroidRedirectOptions.key, equals('android'));
    });
  });
}
