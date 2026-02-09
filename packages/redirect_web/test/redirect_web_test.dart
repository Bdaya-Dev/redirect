import 'package:flutter_test/flutter_test.dart';
import 'package:redirect_platform_interface/redirect_platform_interface.dart';
import 'package:redirect_web/redirect_web.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RedirectWebPlugin', () {
    test('can be registered', () {
      RedirectWebPlugin.registerWith();
      expect(RedirectPlatform.instance, isA<RedirectWebPlugin>());
    });
  });
}
