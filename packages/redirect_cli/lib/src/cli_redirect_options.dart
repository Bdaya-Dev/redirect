import 'package:meta/meta.dart';
import 'package:redirect_core/redirect_core.dart';

/// CLI/desktop-specific options for redirect-based flows.
///
/// Pass via [RedirectOptions.platformOptions] using [key]:
///
/// ```dart
/// redirect.run(
///   url: authUrl,
///   callbackUrlScheme: 'myapp',
///   options: RedirectOptions(
///     platformOptions: {
///       CliRedirectOptions.key: CliRedirectOptions(
///         port: 8080,
///         openBrowser: false,
///       ),
///     },
///   ),
/// );
/// ```
@immutable
class CliRedirectOptions {
  /// Creates CLI redirect options.
  const CliRedirectOptions({
    this.port,
    this.portRange,
    this.host = 'localhost',
    this.bindAddress,
    this.callbackPath = '/callback',
    this.successHtml,
    this.errorHtml,
    this.openBrowser = true,
  }) : assert(
          port == null || portRange == null,
          'Cannot specify both port and portRange',
        );

  /// The key used in [RedirectOptions.platformOptions].
  static const String key = 'cli';

  /// Extracts [CliRedirectOptions] from [RedirectOptions.platformOptions].
  ///
  /// Returns [fallback] if no CLI options are set (defaults to
  /// `const CliRedirectOptions()`).
  static CliRedirectOptions fromOptions(
    RedirectOptions options, [
    CliRedirectOptions fallback = const CliRedirectOptions(),
  ]) {
    return options.getPlatformOption<CliRedirectOptions>(key) ?? fallback;
  }

  /// Fixed port to use for the callback server.
  ///
  /// If null and [portRange] is also null, an available port is chosen
  /// automatically (port 0).
  final int? port;

  /// Range of ports to try for the callback server.
  ///
  /// The first available port in the range will be used.
  /// If null and [port] is also null, an available port is chosen
  /// automatically.
  final ({int start, int end})? portRange;

  /// Hostname to use in the redirect URI.
  ///
  /// This is the hostname that will appear in the `redirect_uri` parameter
  /// sent to the authorization server. Defaults to `localhost`.
  ///
  /// Common values:
  /// - `localhost` (default)
  /// - `127.0.0.1`
  /// - `[::1]` (IPv6 loopback)
  final String host;

  /// Address to bind the HTTP server to.
  ///
  /// If null, binds to `InternetAddress.loopbackIPv4`.
  /// Use `InternetAddress.loopbackIPv6` for IPv6-only environments.
  final Object? bindAddress;

  /// Path for the callback URL.
  ///
  /// Defaults to `/callback`. The full callback URL will be:
  /// `http://{host}:{port}{callbackPath}`
  final String callbackPath;

  /// Custom HTML to display on successful callback.
  ///
  /// If null, a default success page is shown.
  final String? successHtml;

  /// Custom HTML to display on error.
  ///
  /// If null, a default error page is shown.
  final String? errorHtml;

  /// Whether to automatically open the system browser.
  ///
  /// Set to `false` if you want to handle browser launching yourself
  /// (e.g., display the URL for the user to copy manually).
  ///
  /// Defaults to `true`.
  final bool openBrowser;

  /// Creates a copy with the given fields replaced.
  CliRedirectOptions copyWith({
    int? port,
    ({int start, int end})? portRange,
    String? host,
    Object? bindAddress,
    String? callbackPath,
    String? successHtml,
    String? errorHtml,
    bool? openBrowser,
  }) {
    return CliRedirectOptions(
      port: port ?? this.port,
      portRange: portRange ?? this.portRange,
      host: host ?? this.host,
      bindAddress: bindAddress ?? this.bindAddress,
      callbackPath: callbackPath ?? this.callbackPath,
      successHtml: successHtml ?? this.successHtml,
      errorHtml: errorHtml ?? this.errorHtml,
      openBrowser: openBrowser ?? this.openBrowser,
    );
  }
}
