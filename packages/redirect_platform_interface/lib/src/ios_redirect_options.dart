import 'package:meta/meta.dart';
import 'package:redirect_core/redirect_core.dart';
import 'package:redirect_platform_interface/src/darwin_redirect_options.dart';

/// iOS-specific options for redirect-based flows.
///
/// Extends [DarwinRedirectOptions] which provides the shared Darwin fields
/// (`additionalHeaderFields`).
///
/// Pass via [RedirectOptions.platformOptions] using [key].
@immutable
class IosRedirectOptions extends DarwinRedirectOptions {
  /// Creates iOS redirect options.
  const IosRedirectOptions({
    required super.callback,
    super.preferEphemeral,
    super.additionalHeaderFields,
  });

  /// The key used in [RedirectOptions.platformOptions].
  static const String key = 'ios';

  /// Extracts [IosRedirectOptions] from [RedirectOptions.platformOptions].
  ///
  /// Returns [fallback] if no iOS options are set.
  /// Throws [StateError] if neither is available.
  static IosRedirectOptions fromOptions(
    RedirectOptions options, [
    IosRedirectOptions? fallback,
  ]) {
    final result = options.getPlatformOption<IosRedirectOptions>(key);
    if (result == null && fallback == null) {
      throw StateError(
        'IosRedirectOptions must be provided in '
        'RedirectOptions.platformOptions with key "$key". '
        'A CallbackConfig is required on iOS.',
      );
    }
    return result ?? fallback!;
  }
}
