import 'package:flutter_test/flutter_test.dart';
import 'package:redirect_desktop/redirect_desktop.dart';
import 'package:redirect_platform_interface/redirect_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RedirectWindowsPlugin', () {
    test('can be registered', () {
      RedirectWindowsPlugin.registerWith();
      expect(RedirectPlatform.instance, isA<RedirectWindowsPlugin>());
    });
  });

  group('RedirectLinuxPlugin', () {
    test('can be registered', () {
      RedirectLinuxPlugin.registerWith();
      expect(RedirectPlatform.instance, isA<RedirectLinuxPlugin>());
    });
  });

  group('WindowsRedirectOptions', () {
    test('default values are correct', () {
      const options = WindowsRedirectOptions();

      expect(options.callbackUrl, isNull);
      expect(options.httpResponseBuilder, isNull);
      expect(options.openBrowser, isTrue);
    });

    test('custom values are stored correctly', () {
      final options = WindowsRedirectOptions(
        callbackUrl: Uri.parse('http://127.0.0.1:8080/oauth/callback'),
        openBrowser: false,
        httpResponseBuilder: (_) => const HttpCallbackResponse(
          body: '<h1>Done</h1>',
        ),
      );

      expect(options.callbackUrl!.host, equals('127.0.0.1'));
      expect(options.callbackUrl!.port, equals(8080));
      expect(options.callbackUrl!.path, equals('/oauth/callback'));
      expect(options.openBrowser, isFalse);
      expect(options.httpResponseBuilder, isNotNull);
    });

    test('fromOptions extracts options from platformOptions', () {
      final windowsOpts = WindowsRedirectOptions(
        callbackUrl: Uri.parse('http://localhost:9090/callback'),
      );
      final options = RedirectOptions(
        platformOptions: {WindowsRedirectOptions.key: windowsOpts},
      );

      final extracted = WindowsRedirectOptions.fromOptions(options);

      expect(extracted.callbackUrl!.port, equals(9090));
    });

    test('fromOptions returns fallback when not present', () {
      const options = RedirectOptions();
      final fallback = WindowsRedirectOptions(
        callbackUrl: Uri.parse('http://localhost:4000/callback'),
      );

      final extracted = WindowsRedirectOptions.fromOptions(options, fallback);

      expect(extracted.callbackUrl!.port, equals(4000));
    });

    test('fromOptions returns default when no fallback and not present', () {
      const options = RedirectOptions();

      final extracted = WindowsRedirectOptions.fromOptions(options);

      expect(extracted.callbackUrl, isNull);
    });
  });

  group('LinuxRedirectOptions', () {
    test('default values are correct', () {
      const options = LinuxRedirectOptions();

      expect(options.callbackUrl, isNull);
      expect(options.httpResponseBuilder, isNull);
      expect(options.openBrowser, isTrue);
    });

    test('fromOptions extracts options from platformOptions', () {
      final linuxOpts = LinuxRedirectOptions(
        callbackUrl: Uri.parse('http://localhost:7070/callback'),
      );
      final options = RedirectOptions(
        platformOptions: {LinuxRedirectOptions.key: linuxOpts},
      );

      final extracted = LinuxRedirectOptions.fromOptions(options);

      expect(extracted.callbackUrl!.port, equals(7070));
    });
  });
}
