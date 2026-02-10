import 'package:meta/meta.dart';
import 'package:redirect_core/redirect_core.dart';

/// Darwin (iOS/macOS) specific options for redirect-based flows.
///
/// Pass via [RedirectOptions.platformOptions] using [key].
///
/// Uses `ASWebAuthenticationSession` under the hood.
@immutable
class DarwinRedirectOptions {
  /// Creates Darwin redirect options.
  const DarwinRedirectOptions({
    this.additionalHeaderFields,
  });

  /// The key used in [RedirectOptions.platformOptions].
  static const String key = 'darwin';

  /// Extracts [DarwinRedirectOptions] from [RedirectOptions.platformOptions].
  ///
  /// Returns [fallback] if no Darwin options are set (defaults to
  /// `const DarwinRedirectOptions()`).
  static DarwinRedirectOptions fromOptions(
    RedirectOptions options, [
    DarwinRedirectOptions fallback = const DarwinRedirectOptions(),
  ]) {
    return options.getPlatformOption<DarwinRedirectOptions>(key) ?? fallback;
  }

  /// Additional HTTP header fields to set when loading the initial URL.
  ///
  /// Maps to `ASWebAuthenticationSession.additionalHeaderFields`.
  ///
  /// Requires iOS 17.4+ / macOS 14.4+. Ignored on older OS versions.
  final Map<String, String>? additionalHeaderFields;
}
