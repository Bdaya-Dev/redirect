import 'package:redirect_io/redirect_io.dart';
import 'package:redirect_platform_interface/redirect_platform_interface.dart';

/// The Windows implementation of [RedirectPlatform].
///
/// Uses [RedirectIo] with a loopback HTTP server and browser launching.
class RedirectWindowsPlugin extends RedirectPlatform {
  /// Creates a new [RedirectWindowsPlugin].
  RedirectWindowsPlugin() : _delegate = _WindowsRedirectIo();

  /// Registers this class as the default instance of [RedirectPlatform].
  static void registerWith() {
    RedirectPlatform.instance = RedirectWindowsPlugin();
  }

  final _WindowsRedirectIo _delegate;

  @override
  RedirectHandle run({
    required Uri url,
    RedirectOptions options = const RedirectOptions(),
  }) {
    return _delegate.run(
      url: url,
      options: options,
    );
  }
}

/// The Linux implementation of [RedirectPlatform].
///
/// Uses [RedirectIo] with a loopback HTTP server and browser launching.
class RedirectLinuxPlugin extends RedirectPlatform {
  /// Creates a new [RedirectLinuxPlugin].
  RedirectLinuxPlugin() : _delegate = _LinuxRedirectIo();

  /// Registers this class as the default instance of [RedirectPlatform].
  static void registerWith() {
    RedirectPlatform.instance = RedirectLinuxPlugin();
  }

  final _LinuxRedirectIo _delegate;

  @override
  RedirectHandle run({
    required Uri url,
    RedirectOptions options = const RedirectOptions(),
  }) {
    return _delegate.run(
      url: url,
      options: options,
    );
  }
}

class _WindowsRedirectIo extends RedirectIo {
  @override
  ServerRedirectOptions getOptions(RedirectOptions options) {
    return WindowsRedirectOptions.fromOptions(options);
  }
}

class _LinuxRedirectIo extends RedirectIo {
  @override
  ServerRedirectOptions getOptions(RedirectOptions options) {
    return LinuxRedirectOptions.fromOptions(options);
  }
}
