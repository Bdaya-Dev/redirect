import 'package:flutter/foundation.dart';
import 'package:redirect_platform_interface/redirect_platform_interface.dart';

/// The platform types supported by the redirect plugin.
///
/// Used by [constructRedirectUrl] to let platform-specific builders
/// know which platform they are building for. This is especially useful
/// for group callbacks like `onDarwin` that cover multiple platforms.
enum RedirectPlatformType {
  /// Android — uses Chrome Custom Tabs.
  android,

  /// iOS — uses ASWebAuthenticationSession.
  ios,

  /// macOS — uses ASWebAuthenticationSession.
  macos,

  /// Linux — uses a loopback HTTP server + system browser.
  linux,

  /// Windows — uses a loopback HTTP server + system browser.
  windows,

  /// Web — uses popup, new tab, same-page redirect, or iframe.
  web,
}

/// Configuration returned by a [RedirectUrlBuilder].
///
/// Bundles the redirect [url] with any [platformOptions] needed for that
/// platform.
class RedirectUrlConfig {
  /// Creates a redirect URL configuration.
  const RedirectUrlConfig({
    required this.url,
    this.platformOptions = const {},
    this.timeout,
  });

  /// The redirect URL to open.
  final Uri url;

  /// How long to wait for a callback before auto-cancelling.
  ///
  /// If `null` (the default), no timeout is applied.
  final Duration? timeout;

  /// Platform-specific options to include in the final [RedirectOptions].
  ///
  /// These are merged directly into [RedirectOptions.platformOptions].
  /// Use the platform option class's `key` constant:
  ///
  /// ```dart
  /// RedirectUrlConfig(
  ///   url: myUrl,
  ///   platformOptions: {
  ///     AndroidRedirectOptions.key: AndroidRedirectOptions(
  ///       callbackUrlScheme: 'myapp',
  ///     ),
  ///   },
  /// )
  /// ```
  final Map<String, Object> platformOptions;
}

/// A callback that builds a [RedirectUrlConfig] for the given [platform].
typedef RedirectUrlBuilder =
    RedirectUrlConfig Function(
      RedirectPlatformType platform,
    );

/// Override in tests to control the platform detected by
/// [constructRedirectUrl].
///
/// Set to `null` (the default) to use the real platform.
///
/// ```dart
/// tearDown(() {
///   debugRedirectPlatformTypeOverride = null;
/// });
///
/// test('uses Android builder', () {
///   debugRedirectPlatformTypeOverride = RedirectPlatformType.android;
///   final (:url, :options) = constructRedirectUrl(
///     fallback: (_) => RedirectUrlConfig(url: someUrl),
///     onAndroid: (_) => RedirectUrlConfig(url: androidUrl),
///   );
///   expect(url, androidUrl);
/// });
/// ```
@visibleForTesting
RedirectPlatformType? debugRedirectPlatformTypeOverride;

/// Detects the current platform and calls the matching builder to construct
/// a redirect URL and [RedirectOptions].
///
/// Each platform checks builders from most specific to least specific
/// before falling back to [fallback]:
///
/// | Platform | Resolution order |
/// |----------|-----------------|
/// | Android  | [onAndroid] > [onMobile] > [fallback] |
/// | iOS      | [onIos] > [onDarwin] > [onMobile] > [fallback] |
/// | macOS    | [onMacos] > [onDarwin] > [fallback] |
/// | Linux    | [onLinux] > [onDesktop] > [fallback] |
/// | Windows  | [onWindows] > [onDesktop] > [fallback] |
/// | Web      | [onWeb] > [fallback] |
///
/// The builder receives the specific [RedirectPlatformType], so group
/// callbacks like [onDarwin] can distinguish between iOS and macOS:
///
/// ```dart
/// final (:url, :options) = constructRedirectUrl(
///   fallback: (_) => RedirectUrlConfig(url: baseUrl),
///   onAndroid: (_) => RedirectUrlConfig(
///     url: Uri.parse('$baseUrl?redirect_uri=myapp://callback'),
///     platformOptions: {
///       AndroidRedirectOptions.key: AndroidRedirectOptions(
///         callbackUrlScheme: 'myapp',
///       ),
///     },
///   ),
///   onDarwin: (platform) => RedirectUrlConfig(
///     url: Uri.parse('$baseUrl?redirect_uri=myapp://callback'),
///     platformOptions: {
///       if (platform == RedirectPlatformType.ios)
///         IosRedirectOptions.key: IosRedirectOptions(
///           callback: CallbackConfig.customScheme('myapp'),
///           preferEphemeral: true,
///         )
///       else
///         MacosRedirectOptions.key: MacosRedirectOptions(
///           callback: CallbackConfig.customScheme('myapp'),
///           preferEphemeral: true,
///         ),
///     },
///   ),
///   timeout: Duration(minutes: 5),
/// );
///
/// final handle = runRedirect(url: url, options: options);
/// ```
///
/// [RedirectUrlConfig.timeout] from the selected builder takes precedence
/// over the top-level [timeout] default.
///
/// `preferEphemeral` is not a parameter here — set it directly on the
/// platform options that support it ([DarwinRedirectOptions],
/// [AndroidRedirectOptions]).
({Uri url, RedirectOptions options}) constructRedirectUrl({
  required RedirectUrlBuilder fallback,
  RedirectUrlBuilder? onAndroid,
  RedirectUrlBuilder? onIos,
  RedirectUrlBuilder? onMacos,
  RedirectUrlBuilder? onDarwin,
  RedirectUrlBuilder? onLinux,
  RedirectUrlBuilder? onWindows,
  RedirectUrlBuilder? onDesktop,
  RedirectUrlBuilder? onWeb,
  RedirectUrlBuilder? onMobile,
  Duration? timeout,
}) {
  final platform = debugRedirectPlatformTypeOverride ?? _detectPlatformType();

  final builder = switch (platform) {
    RedirectPlatformType.android => onAndroid ?? onMobile ?? fallback,
    RedirectPlatformType.ios => onIos ?? onDarwin ?? onMobile ?? fallback,
    RedirectPlatformType.macos => onMacos ?? onDarwin ?? fallback,
    RedirectPlatformType.linux => onLinux ?? onDesktop ?? fallback,
    RedirectPlatformType.windows => onWindows ?? onDesktop ?? fallback,
    RedirectPlatformType.web => onWeb ?? fallback,
  };

  final config = builder(platform);

  return (
    url: config.url,
    options: RedirectOptions(
      timeout: config.timeout ?? timeout,
      platformOptions: config.platformOptions,
    ),
  );
}

RedirectPlatformType _detectPlatformType() {
  if (kIsWeb) return RedirectPlatformType.web;
  return switch (defaultTargetPlatform) {
    TargetPlatform.android => RedirectPlatformType.android,
    TargetPlatform.iOS => RedirectPlatformType.ios,
    TargetPlatform.macOS => RedirectPlatformType.macos,
    TargetPlatform.linux => RedirectPlatformType.linux,
    TargetPlatform.windows => RedirectPlatformType.windows,
    TargetPlatform.fuchsia => throw UnimplementedError(
      'Fuchsia is not currently supported by redirect.',
    ),
  };
}
