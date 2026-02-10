import 'package:meta/meta.dart';
import 'package:redirect_core/redirect_core.dart';

/// Android-specific options for redirect-based flows.
///
/// Pass via [RedirectOptions.platformOptions] using [key].
///
/// On Android, the callback URL scheme must be declared in your app's
/// `AndroidManifest.xml` at build time. The [callbackUrlScheme] here is
/// used at runtime to correlate the incoming intent with the pending
/// redirect request.
///
/// ```xml
/// <activity
///     android:name="com.bdayadev.redirect_android.CallbackActivity"
///     android:exported="true">
///     <intent-filter>
///         <action android:name="android.intent.action.VIEW" />
///         <category android:name="android.intent.category.DEFAULT" />
///         <category android:name="android.intent.category.BROWSABLE" />
///         <data android:scheme="myapp" />
///     </intent-filter>
/// </activity>
/// ```
@immutable
class AndroidRedirectOptions {
  /// Creates Android redirect options.
  const AndroidRedirectOptions({
    required this.callbackUrlScheme,
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
    AndroidRedirectOptions? fallback,
  ]) {
    final result = options.getPlatformOption<AndroidRedirectOptions>(key);
    if (result == null && fallback == null) {
      throw StateError(
        'AndroidRedirectOptions must be provided in '
        'RedirectOptions.platformOptions with key "$key". '
        'The callbackUrlScheme is required on Android.',
      );
    }
    return result ?? fallback!;
  }

  /// The URL scheme to match for callback correlation.
  ///
  /// Must match the `<data android:scheme="..."/>` declared in your
  /// app's `AndroidManifest.xml`.
  final String callbackUrlScheme;

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
