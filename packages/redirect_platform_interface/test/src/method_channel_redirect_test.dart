import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redirect_platform_interface/redirect_platform_interface.dart';
import 'package:redirect_platform_interface/src/method_channel_redirect.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('$MethodChannelRedirect', () {
    late MethodChannelRedirect methodChannelRedirect;
    final log = <MethodCall>[];

    setUp(() async {
      methodChannelRedirect = MethodChannelRedirect();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            methodChannelRedirect.methodChannel,
            (methodCall) async {
              log.add(methodCall);
              switch (methodCall.method) {
                case 'run':
                  return 'myapp://callback?code=test123';
                case 'cancel':
                  return null;
                default:
                  return null;
              }
            },
          );
    });

    tearDown(() {
      log.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            methodChannelRedirect.methodChannel,
            null,
          );
    });

    test('run sends correct arguments', () async {
      final url = Uri.parse('https://auth.example.com/authorize');
      final handle = methodChannelRedirect.run(
        url: url,
        callbackUrlScheme: 'myapp',
      );
      await handle.result;

      expect(log, hasLength(1));
      expect(log.first.method, equals('run'));
      expect(
        log.first.arguments,
        equals(<String, dynamic>{
          'url': url.toString(),
          'callbackUrlScheme': 'myapp',
          'preferEphemeral': false,
        }),
      );
    });

    test('run sends timeout when specified', () async {
      final handle = methodChannelRedirect.run(
        url: Uri.parse('https://auth.example.com/authorize'),
        callbackUrlScheme: 'myapp',
        options: const RedirectOptions(timeout: Duration(seconds: 60)),
      );
      await handle.result;

      expect(log, hasLength(1));
      expect(
        (log.first.arguments as Map)['timeoutMillis'],
        equals(60000),
      );
    });

    test('run returns RedirectSuccess on valid response', () async {
      final handle = methodChannelRedirect.run(
        url: Uri.parse('https://auth.example.com/authorize'),
        callbackUrlScheme: 'myapp',
      );
      final result = await handle.result;

      expect(result, isA<RedirectSuccess>());
      expect(
        (result as RedirectSuccess).uri,
        equals(Uri.parse('myapp://callback?code=test123')),
      );
    });

    test('run returns RedirectCancelled on null response', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            methodChannelRedirect.methodChannel,
            (methodCall) async {
              log.add(methodCall);
              return null;
            },
          );

      final handle = methodChannelRedirect.run(
        url: Uri.parse('https://auth.example.com/authorize'),
        callbackUrlScheme: 'myapp',
      );
      final result = await handle.result;

      expect(result, isA<RedirectCancelled>());
    });

    test(
      'run returns RedirectCancelled on CANCELLED PlatformException',
      () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              methodChannelRedirect.methodChannel,
              (methodCall) async {
                log.add(methodCall);
                throw PlatformException(code: 'CANCELLED');
              },
            );

        final handle = methodChannelRedirect.run(
          url: Uri.parse('https://auth.example.com/authorize'),
          callbackUrlScheme: 'myapp',
        );
        final result = await handle.result;

        expect(result, isA<RedirectCancelled>());
      },
    );

    test('run returns RedirectFailure on other PlatformException', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            methodChannelRedirect.methodChannel,
            (methodCall) async {
              log.add(methodCall);
              throw PlatformException(
                code: 'ERROR',
                message: 'Something failed',
              );
            },
          );

      final handle = methodChannelRedirect.run(
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

    test('cancel sends correct method call', () async {
      final handle = methodChannelRedirect.run(
        url: Uri.parse('https://auth.example.com/authorize'),
        callbackUrlScheme: 'myapp',
      );
      await handle.cancel();

      expect(log.last.method, equals('cancel'));
    });
  });
}
