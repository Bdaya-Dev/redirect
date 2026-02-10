import 'package:flutter_test/flutter_test.dart';
import 'package:redirect_platform_interface/redirect_platform_interface.dart';

class RedirectMock extends RedirectPlatform {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RedirectPlatformInterface', () {
    test('can set and get instance', () {
      final mock = RedirectMock();
      RedirectPlatform.instance = mock;
      expect(RedirectPlatform.instance, equals(mock));
    });

    test('run throws UnimplementedError by default', () {
      final mock = RedirectMock();
      RedirectPlatform.instance = mock;

      expect(
        () => mock.run(
          url: Uri.parse('https://example.com'),
        ),
        throwsA(isA<UnimplementedError>()),
      );
    });
  });
}
