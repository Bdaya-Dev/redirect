import 'package:meta/meta.dart';
import 'package:redirect_core/redirect_core.dart';

/// Linux-specific options for redirect-based flows.
///
/// Extends [ServerRedirectOptions] which provides the shared loopback
/// server fields (`callbackUrl`, `httpResponseBuilder`, `openBrowser`).
///
/// Pass via [RedirectOptions.platformOptions] using [key].
@immutable
class LinuxRedirectOptions extends ServerRedirectOptions {
  /// Creates Linux redirect options.
  const LinuxRedirectOptions({
    super.callbackUrl,
    super.callbackValidator,
    super.httpResponseBuilder,
    super.openBrowser,
    super.portCompleter,
    super.urlBuilder,
  });

  /// The key used in [RedirectOptions.platformOptions].
  static const String key = 'linux';

  /// Extracts [LinuxRedirectOptions] from [RedirectOptions.platformOptions].
  ///
  /// Returns [fallback] if no Linux options are set (defaults to
  /// `const LinuxRedirectOptions()`).
  static LinuxRedirectOptions fromOptions(
    RedirectOptions options, [
    LinuxRedirectOptions fallback = const LinuxRedirectOptions(),
  ]) {
    return options.getPlatformOption<LinuxRedirectOptions>(key) ?? fallback;
  }
}
