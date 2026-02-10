import 'package:meta/meta.dart';
import 'package:redirect_core/redirect_core.dart';

/// Desktop-specific options for redirect-based flows.
///
/// Pass via [RedirectOptions.platformOptions] using [key].
@immutable
class DesktopRedirectOptions {
  /// Creates desktop redirect options.
  const DesktopRedirectOptions({
    this.callbackUrl,
    this.successHtml,
    this.openBrowser = true,
  });

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
  /// DesktopRedirectOptions(
  ///   callbackUrl: Uri.parse('http://127.0.0.1:8080/callback'),
  /// )
  /// ```
  final Uri? callbackUrl;

  /// Custom HTML to display on successful callback.
  final String? successHtml;

  /// Whether to automatically open the system browser.
  final bool openBrowser;
}
