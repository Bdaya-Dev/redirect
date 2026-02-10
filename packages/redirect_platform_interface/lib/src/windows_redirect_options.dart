import 'package:meta/meta.dart';
import 'package:redirect_core/redirect_core.dart';

/// Windows-specific options for redirect-based flows.
///
/// Extends [ServerRedirectOptions] which provides the shared loopback
/// server fields (`callbackUrl`, `httpResponseBuilder`, `openBrowser`).
///
/// Pass via [RedirectOptions.platformOptions] using [key].
@immutable
class WindowsRedirectOptions extends ServerRedirectOptions {
  /// Creates Windows redirect options.
  const WindowsRedirectOptions({
    super.callbackUrl,
    super.callbackValidator,
    super.httpResponseBuilder,
    super.openBrowser,
    super.portCompleter,
    super.urlBuilder,
  });

  /// The key used in [RedirectOptions.platformOptions].
  static const String key = 'windows';

  /// Extracts [WindowsRedirectOptions] from [RedirectOptions.platformOptions].
  ///
  /// Returns [fallback] if no Windows options are set (defaults to
  /// `const WindowsRedirectOptions()`).
  static WindowsRedirectOptions fromOptions(
    RedirectOptions options, [
    WindowsRedirectOptions fallback = const WindowsRedirectOptions(),
  ]) {
    return options.getPlatformOption<WindowsRedirectOptions>(key) ?? fallback;
  }
}
