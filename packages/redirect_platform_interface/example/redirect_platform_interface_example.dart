import 'package:redirect_platform_interface/redirect_platform_interface.dart';

/// Example demonstrating how to implement a custom platform for the
/// redirect plugin using redirect_platform_interface.
///
/// Platform implementations extend [RedirectPlatform] and override
/// the [RedirectPlatform.run] method to provide platform-specific
/// redirect behavior.
class MyCustomPlatform extends RedirectPlatform {
  /// Registers this platform as the active [RedirectPlatform] instance.
  static void registerWith() {
    RedirectPlatform.instance = MyCustomPlatform();
  }

  @override
  RedirectHandle run({
    required Uri url,
    RedirectOptions options = const RedirectOptions(),
  }) {
    // Implement platform-specific redirect logic here.
    // For example: open a browser, listen for the callback URL,
    // and return the result.
    return RedirectHandle(
      url: url,
      options: options,
      result: Future.value(
        RedirectSuccess(
          uri: Uri.parse('myapp://callback'),
        ),
      ),
      cancel: () async {},
    );
  }
}
