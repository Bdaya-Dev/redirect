import 'package:flutter_test/flutter_test.dart';
import 'package:redirect_desktop/redirect_desktop.dart';
import 'package:redirect_platform_interface/redirect_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RedirectDesktopPlugin', () {
    test('can be registered', () {
      RedirectDesktopPlugin.registerWith();
      expect(RedirectPlatform.instance, isA<RedirectDesktopPlugin>());
    });
  });

  group('DesktopRedirectOptions', () {
    test('default values are correct', () {
      const options = DesktopRedirectOptions();

      expect(options.callbackUrl, isNull);
      expect(options.successHtml, isNull);
      expect(options.openBrowser, isTrue);
    });

    test('custom values are stored correctly', () {
      final options = DesktopRedirectOptions(
        callbackUrl: Uri.parse('http://127.0.0.1:8080/oauth/callback'),
        openBrowser: false,
        successHtml: '<h1>Done</h1>',
      );

      expect(options.callbackUrl!.host, equals('127.0.0.1'));
      expect(options.callbackUrl!.port, equals(8080));
      expect(options.callbackUrl!.path, equals('/oauth/callback'));
      expect(options.openBrowser, isFalse);
      expect(options.successHtml, equals('<h1>Done</h1>'));
    });

    test('fromOptions extracts desktop options from platformOptions', () {
      final desktopOpts = DesktopRedirectOptions(
        callbackUrl: Uri.parse('http://localhost:9090/callback'),
      );
      final options = RedirectOptions(
        platformOptions: {DesktopRedirectOptions.key: desktopOpts},
      );

      final extracted = DesktopRedirectOptions.fromOptions(options);

      expect(extracted.callbackUrl!.port, equals(9090));
    });

    test('fromOptions returns fallback when not present', () {
      const options = RedirectOptions();
      final fallback = DesktopRedirectOptions(
        callbackUrl: Uri.parse('http://localhost:4000/callback'),
      );

      final extracted = DesktopRedirectOptions.fromOptions(options, fallback);

      expect(extracted.callbackUrl!.port, equals(4000));
    });

    test('fromOptions returns default when no fallback and not present', () {
      const options = RedirectOptions();

      final extracted = DesktopRedirectOptions.fromOptions(options);

      expect(extracted.callbackUrl, isNull);
    });
  });
}
