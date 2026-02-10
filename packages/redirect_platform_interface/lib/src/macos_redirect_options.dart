import 'package:meta/meta.dart';
import 'package:redirect_core/redirect_core.dart';
import 'package:redirect_platform_interface/src/darwin_redirect_options.dart';

/// macOS-specific options for redirect-based flows.
///
/// Extends [DarwinRedirectOptions] which provides the shared Darwin fields
/// (`additionalHeaderFields`).
///
/// Pass via [RedirectOptions.platformOptions] using [key].
@immutable
class MacosRedirectOptions extends DarwinRedirectOptions {
  /// Creates macOS redirect options.
  const MacosRedirectOptions({
    required super.callback,
    super.additionalHeaderFields,
  });

  /// The key used in [RedirectOptions.platformOptions].
  static const String key = 'macos';

  /// Extracts [MacosRedirectOptions] from [RedirectOptions.platformOptions].
  ///
  /// Returns [fallback] if no macOS options are set.
  /// Throws [StateError] if neither is available.
  static MacosRedirectOptions fromOptions(
    RedirectOptions options, [
    MacosRedirectOptions? fallback,
  ]) {
    final result = options.getPlatformOption<MacosRedirectOptions>(key);
    if (result == null && fallback == null) {
      throw StateError(
        'MacosRedirectOptions must be provided in '
        'RedirectOptions.platformOptions with key "$key". '
        'A CallbackConfig is required on macOS.',
      );
    }
    return result ?? fallback!;
  }
}
