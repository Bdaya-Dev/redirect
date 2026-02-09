import 'package:meta/meta.dart';
import 'package:redirect_core/redirect_core.dart';

/// Desktop-specific options for redirect-based flows.
///
/// Pass via [RedirectOptions.platformOptions] using [key].
@immutable
class DesktopRedirectOptions {
  /// Creates desktop redirect options.
  const DesktopRedirectOptions({
    this.port,
    this.portRange,
    this.host = 'localhost',
    this.bindAddress,
    this.callbackPath = '/callback',
    this.successHtml,
    this.openBrowser = true,
  }) : assert(
          port == null || portRange == null,
          'Cannot specify both port and portRange',
        );

  /// The key used in [RedirectOptions.platformOptions].
  static const String key = 'desktop';

  /// Extracts [DesktopRedirectOptions] from [RedirectOptions.platformOptions].
  ///
  /// Returns [fallback] if no desktop options are set (defaults to
  /// `const DesktopRedirectOptions()`).
  static DesktopRedirectOptions fromOptions(
    RedirectOptions options, [
    DesktopRedirectOptions fallback = const DesktopRedirectOptions(),
  ]) {
    return options.getPlatformOption<DesktopRedirectOptions>(key) ?? fallback;
  }

  /// Fixed port to use for the callback server.
  final int? port;

  /// Range of ports to try for the callback server.
  final ({int start, int end})? portRange;

  /// Hostname to use in the redirect URI.
  final String host;

  /// Address to bind the HTTP server to.
  final Object? bindAddress;

  /// Path for the callback URL.
  final String callbackPath;

  /// Custom HTML to display on successful callback.
  final String? successHtml;

  /// Whether to automatically open the system browser.
  final bool openBrowser;
}
