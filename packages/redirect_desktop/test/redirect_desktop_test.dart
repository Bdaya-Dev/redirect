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

      expect(options.port, isNull);
      expect(options.portRange, isNull);
      expect(options.host, equals('localhost'));
      expect(options.bindAddress, isNull);
      expect(options.callbackPath, equals('/callback'));
      expect(options.successHtml, isNull);
      expect(options.openBrowser, isTrue);
    });

    test('custom values are stored correctly', () {
      const options = DesktopRedirectOptions(
        port: 8080,
        host: '127.0.0.1',
        callbackPath: '/oauth/callback',
        openBrowser: false,
        successHtml: '<h1>Done</h1>',
      );

      expect(options.port, equals(8080));
      expect(options.host, equals('127.0.0.1'));
      expect(options.callbackPath, equals('/oauth/callback'));
      expect(options.openBrowser, isFalse);
      expect(options.successHtml, equals('<h1>Done</h1>'));
    });

    test('assertion fails if both port and portRange are specified', () {
      expect(
        () => DesktopRedirectOptions(
          port: 8080,
          portRange: (start: 3000, end: 3100),
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('portRange can be set without port', () {
      const options = DesktopRedirectOptions(
        portRange: (start: 3000, end: 3100),
      );

      expect(options.port, isNull);
      expect(options.portRange, isNotNull);
      expect(options.portRange!.start, equals(3000));
      expect(options.portRange!.end, equals(3100));
    });

    test('fromOptions extracts desktop options from platformOptions', () {
      const desktopOpts = DesktopRedirectOptions(port: 9090);
      const options = RedirectOptions(
        platformOptions: {DesktopRedirectOptions.key: desktopOpts},
      );

      final extracted = DesktopRedirectOptions.fromOptions(options);

      expect(extracted.port, equals(9090));
    });

    test('fromOptions returns fallback when not present', () {
      const options = RedirectOptions();
      const fallback = DesktopRedirectOptions(port: 4000);

      final extracted = DesktopRedirectOptions.fromOptions(options, fallback);

      expect(extracted.port, equals(4000));
    });

    test('fromOptions returns default when no fallback and not present', () {
      const options = RedirectOptions();

      final extracted = DesktopRedirectOptions.fromOptions(options);

      expect(extracted.port, isNull);
      expect(extracted.host, equals('localhost'));
    });
  });
}
