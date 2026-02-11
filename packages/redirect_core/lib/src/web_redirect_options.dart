import 'dart:async';

import 'package:meta/meta.dart';
import 'package:redirect_core/redirect_core.dart';

/// Validates whether a URI received on the web BroadcastChannel is the
/// expected callback.
///
/// See [WebRedirectOptions.callbackValidator].
typedef WebCallbackValidator = FutureOr<bool> Function(Uri uri);

/// Web-specific options for redirect-based flows.
///
/// Pass via [RedirectOptions.platformOptions] using [key]:
///
/// ```dart
/// runRedirect(
///   url: redirectUrl,
///   options: RedirectOptions(
///     platformOptions: {
///       WebRedirectOptions.key: WebRedirectOptions(
///         mode: WebRedirectMode.newTab,
///         callbackValidator: (uri) =>
///             uri.scheme == 'https' && uri.host == 'myapp.example.com',
///       ),
///     },
///   ),
/// );
/// ```
@immutable
class WebRedirectOptions {
  /// Creates web redirect options.
  const WebRedirectOptions({
    this.mode = WebRedirectMode.popup,
    this.callbackValidator,
    this.popupOptions = const PopupOptions(),
    this.newTabOptions = const NewTabOptions(),
    this.iframeOptions = const IframeOptions(),
    this.broadcastChannelName,
  });

  /// The key used in [RedirectOptions.platformOptions] for web options.
  static const String key = 'web';

  /// Extracts [WebRedirectOptions] from [RedirectOptions.platformOptions].
  ///
  /// Returns [fallback] if no web options are set (defaults to
  /// `const WebRedirectOptions()`).
  static WebRedirectOptions fromOptions(
    RedirectOptions options, [
    WebRedirectOptions fallback = const WebRedirectOptions(),
  ]) {
    return options.getPlatformOption<WebRedirectOptions>(key) ?? fallback;
  }

  /// How to open the redirect URL.
  ///
  /// Defaults to [WebRedirectMode.popup].
  final WebRedirectMode mode;

  /// Validates whether an incoming callback URI should be accepted.
  ///
  /// Called when a message arrives on the BroadcastChannel. Return `true`
  /// to accept, `false` to ignore.
  ///
  /// If null, **all** valid URIs received on the channel are accepted.
  ///
  /// Supports both synchronous and asynchronous validation via [FutureOr].
  ///
  /// Example:
  /// ```dart
  /// WebRedirectOptions(
  ///   callbackValidator: (uri) =>
  ///       uri.scheme == 'https' &&
  ///       uri.host == 'myapp.example.com' &&
  ///       uri.path == '/callback',
  /// )
  /// ```
  final WebCallbackValidator? callbackValidator;

  /// Options for the popup window.
  ///
  /// Only used when [mode] is [WebRedirectMode.popup].
  /// See [PopupOptions] for available configuration.
  final PopupOptions popupOptions;

  /// Options for the new tab.
  ///
  /// Only used when [mode] is [WebRedirectMode.newTab].
  /// See [NewTabOptions] for available configuration.
  final NewTabOptions newTabOptions;

  /// Options for the iframe element.
  ///
  /// Only used when [mode] is [WebRedirectMode.iframe].
  /// See [IframeOptions] for available configuration.
  final IframeOptions iframeOptions;

  /// Custom name for the BroadcastChannel used for communication.
  ///
  /// By default, each operation generates a unique channel name
  /// (`redirect_{nonce}`) and stores it in `localStorage` so the
  /// callback page can auto-discover it via `RedirectWeb.handleCallback`.
  ///
  /// Set this explicitly only if you need deterministic channel naming
  /// (e.g., for testing or when coordinating with a custom callback page).
  final String? broadcastChannelName;

  /// Relative URL path to the bundled callback HTML page.
  ///
  /// After `flutter build web`, the `redirect_web` package ships
  /// `redirect_callback.html` as a Flutter asset at this path relative
  /// to the app's `<base href>`.
  static const defaultCallbackPath =
      'assets/packages/redirect_web/assets/redirect_callback.html';

  /// Resolves the absolute URL for the default bundled callback page.
  ///
  /// On web platforms (where [Uri.base] has an `http` or `https` scheme),
  /// returns the full URL by resolving [defaultCallbackPath] against
  /// [Uri.base].
  ///
  /// Returns `null` on non-web platforms since the bundled callback page
  /// is only relevant for web.
  ///
  /// Example:
  /// ```dart
  /// final callbackUrl = WebRedirectOptions.resolveDefaultCallbackUrl();
  /// // On web → https://myapp.com/assets/packages/redirect_web/assets/redirect_callback.html
  /// // On non-web → null
  /// ```
  static Uri? resolveDefaultCallbackUrl() {
    final base = Uri.base;
    if (base.scheme == 'http' || base.scheme == 'https') {
      return base.resolve(defaultCallbackPath);
    }
    return null;
  }

  /// Creates a copy with the given fields replaced.
  WebRedirectOptions copyWith({
    WebRedirectMode? mode,
    WebCallbackValidator? callbackValidator,
    PopupOptions? popupOptions,
    NewTabOptions? newTabOptions,
    IframeOptions? iframeOptions,
    String? broadcastChannelName,
  }) {
    return WebRedirectOptions(
      mode: mode ?? this.mode,
      callbackValidator: callbackValidator ?? this.callbackValidator,
      popupOptions: popupOptions ?? this.popupOptions,
      newTabOptions: newTabOptions ?? this.newTabOptions,
      iframeOptions: iframeOptions ?? this.iframeOptions,
      broadcastChannelName: broadcastChannelName ?? this.broadcastChannelName,
    );
  }
}
