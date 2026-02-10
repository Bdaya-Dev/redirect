/// Desktop implementation of the redirect plugin.
///
/// Uses a loopback HTTP server to handle redirect callbacks,
/// providing a pure Dart implementation that works on Linux, macOS,
/// and Windows without any platform-specific native code.
library;

export 'src/redirect_desktop.dart';
