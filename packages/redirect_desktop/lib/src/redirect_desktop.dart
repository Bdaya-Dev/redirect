import 'package:redirect_io/redirect_io.dart';
import 'package:redirect_platform_interface/redirect_platform_interface.dart';

/// The desktop implementation of [RedirectPlatform].
///
/// Delegates to [RedirectIo] for loopback HTTP server and browser launching.
/// This is a thin Flutter plugin wrapper that works on Linux and Windows.
///
/// On macOS, the `redirect_darwin` package is used instead
/// (ASWebAuthenticationSession).
class RedirectDesktopPlugin extends RedirectPlatform {
  /// Creates a new [RedirectDesktopPlugin].
  RedirectDesktopPlugin() : _delegate = RedirectIo();

  /// Registers this class as the default instance of [RedirectPlatform].
  static void registerWith() {
    RedirectPlatform.instance = RedirectDesktopPlugin();
  }

  final RedirectIo _delegate;

  @override
  RedirectHandle run({
    required Uri url,
    required String callbackUrlScheme,
    RedirectOptions options = const RedirectOptions(),
  }) {
    // Map DesktopRedirectOptions to IoRedirectOptions for the delegate.
    final desktopOptions = DesktopRedirectOptions.fromOptions(options);
    final ioOptions = IoRedirectOptions(
      callbackUrl: desktopOptions.callbackUrl,
      successHtml: desktopOptions.successHtml,
      openBrowser: desktopOptions.openBrowser,
    );

    final mappedOptions = RedirectOptions(
      preferEphemeral: options.preferEphemeral,
      timeout: options.timeout,
      platformOptions: {
        ...options.platformOptions,
        IoRedirectOptions.key: ioOptions,
      },
    );

    return _delegate.run(
      url: url,
      callbackUrlScheme: callbackUrlScheme,
      options: mappedOptions,
    );
  }
}
