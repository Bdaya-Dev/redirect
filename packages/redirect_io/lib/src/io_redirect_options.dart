import 'package:meta/meta.dart';
import 'package:redirect_core/redirect_core.dart';

/// IO-specific options for redirect-based flows using a loopback HTTP server.
///
/// Pass via [RedirectOptions.platformOptions] using [key]:
///
/// ```dart
/// redirect.run(
///   url: authUrl,
///   callbackUrlScheme: 'myapp',
///   options: RedirectOptions(
///     platformOptions: {
///       IoRedirectOptions.key: IoRedirectOptions(
///         callbackUrl: Uri.parse('http://localhost:8080/callback'),
///         openBrowser: false,
///       ),
///     },
///   ),
/// );
/// ```
@immutable
class IoRedirectOptions {
  /// Creates IO redirect options.
  const IoRedirectOptions({
    this.callbackUrl,
    this.successHtml,
    this.errorHtml,
    this.openBrowser = true,
  });

  /// The key used in [RedirectOptions.platformOptions].
  static const String key = 'io';

  /// Extracts [IoRedirectOptions] from [RedirectOptions.platformOptions].
  ///
  /// Returns [fallback] if no IO options are set (defaults to
  /// `const IoRedirectOptions()`).
  static IoRedirectOptions fromOptions(
    RedirectOptions options, [
    IoRedirectOptions fallback = const IoRedirectOptions(),
  ]) {
    return options.getPlatformOption<IoRedirectOptions>(key) ?? fallback;
  }

  /// The loopback callback URL for the local HTTP server.
  ///
  /// Components used:
  /// - **host** — hostname for the redirect URI and server bind address.
  ///   Defaults to `localhost`.
  /// - **port** — port to bind. Use `0` (the default) to auto-select an
  ///   available port.
  /// - **path** — callback path to listen on. Defaults to `/callback`.
  ///
  /// If null, defaults to `http://localhost:0/callback` (auto-selected port).
  ///
  /// Example:
  /// ```dart
  /// IoRedirectOptions(
  ///   callbackUrl: Uri.parse('http://localhost:8080/callback'),
  /// )
  /// ```
  final Uri? callbackUrl;

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
  IoRedirectOptions copyWith({
    Uri? callbackUrl,
    String? successHtml,
    String? errorHtml,
    bool? openBrowser,
  }) {
    return IoRedirectOptions(
      callbackUrl: callbackUrl ?? this.callbackUrl,
      successHtml: successHtml ?? this.successHtml,
      errorHtml: errorHtml ?? this.errorHtml,
      openBrowser: openBrowser ?? this.openBrowser,
    );
  }
}
