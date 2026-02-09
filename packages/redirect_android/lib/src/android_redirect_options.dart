import 'package:meta/meta.dart';
import 'package:redirect_core/redirect_core.dart';

/// Android-specific options for redirect-based flows.
///
/// Pass via [RedirectOptions.platformOptions] using [key].
@immutable
class AndroidRedirectOptions {
  /// Creates Android redirect options.
  const AndroidRedirectOptions({
    this.preferEphemeral,
    this.useCustomTabs = true,
    this.showTitle = false,
    this.enableUrlBarHiding = false,
    this.toolbarColor,
    this.secondaryToolbarColor,
  });

  /// The key used in [RedirectOptions.platformOptions].
  static const String key = 'android';

  /// Extracts [AndroidRedirectOptions] from [RedirectOptions.platformOptions].
  ///
  /// Returns [fallback] if no Android options are set (defaults to
  /// `const AndroidRedirectOptions()`).
  static AndroidRedirectOptions fromOptions(
    RedirectOptions options, [
    AndroidRedirectOptions fallback = const AndroidRedirectOptions(),
  ]) {
    return options.getPlatformOption<AndroidRedirectOptions>(key) ?? fallback;
  }

  /// Overrides [RedirectOptions.preferEphemeral] when non-null.
  final bool? preferEphemeral;

  /// Whether to use Chrome Custom Tabs when available.
  final bool useCustomTabs;

  /// Whether to show the page title in the Custom Tabs toolbar.
  final bool showTitle;

  /// Whether to hide the URL bar on scroll in Custom Tabs.
  final bool enableUrlBarHiding;

  /// Primary toolbar color (ARGB int).
  final int? toolbarColor;

  /// Secondary toolbar color (ARGB int).
  final int? secondaryToolbarColor;
}
