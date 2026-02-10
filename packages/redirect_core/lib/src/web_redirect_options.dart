import 'package:meta/meta.dart';
import 'package:redirect_core/redirect_core.dart';

/// Web-specific options for redirect-based flows.
///
/// Pass via [RedirectOptions.platformOptions] using [key]:
///
/// ```dart
/// runRedirect(
///   url: authUrl,
///   callbackUrlScheme: 'myapp',
///   options: RedirectOptions(
///     platformOptions: {
///       WebRedirectOptions.key: WebRedirectOptions(
///         mode: WebRedirectMode.newTab,
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
    this.popupWidth = 500,
    this.popupHeight = 700,
    this.popupLeft,
    this.popupTop,
    this.broadcastChannelName,
    this.iframeId,
    this.callbackPath,
    this.autoRegisterServiceWorker = false,
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

  /// How to open the authorization URL.
  ///
  /// Defaults to [WebRedirectMode.popup].
  final WebRedirectMode mode;

  /// Width of the popup window in pixels.
  ///
  /// Only used when [mode] is [WebRedirectMode.popup].
  /// Defaults to 500.
  final int popupWidth;

  /// Height of the popup window in pixels.
  ///
  /// Only used when [mode] is [WebRedirectMode.popup].
  /// Defaults to 700.
  final int popupHeight;

  /// Left position of the popup window.
  ///
  /// If null, the popup is centered horizontally.
  final int? popupLeft;

  /// Top position of the popup window.
  ///
  /// If null, the popup is centered vertically.
  final int? popupTop;

  /// Custom name for the BroadcastChannel used for communication.
  ///
  /// By default, each operation generates a unique channel name
  /// (`redirect_{callbackUrlScheme}_{nonce}`) and stores it in
  /// `localStorage` so the callback page can auto-discover it via
  /// `RedirectWeb.handleCallback`.
  ///
  /// Set this explicitly only if you need deterministic channel naming
  /// (e.g., for testing or when coordinating with a custom callback page).
  final String? broadcastChannelName;

  /// Custom ID for the hidden iframe element.
  ///
  /// Only used when [mode] is [WebRedirectMode.hiddenIframe].
  /// Defaults to `redirect_iframe`.
  final String? iframeId;

  /// The path on your origin that receives the callback.
  ///
  /// Used by the Service Worker (`redirect_sw.js`) to know which
  /// navigation requests to intercept. Defaults to `/callback`.
  ///
  /// Has no effect when the Service Worker is not registered.
  final String? callbackPath;

  /// Whether to auto-register the Service Worker when a redirect starts.
  ///
  /// When true, [RedirectWeb.registerServiceWorker] is invoked during
  /// `run()`/`runWithWebOptions()` using [callbackPath] if provided.
  ///
  /// Defaults to false (opt-in) to avoid side effects in apps that manage
  /// their own Service Worker.
  final bool autoRegisterServiceWorker;

  /// Creates a copy with the given fields replaced.
  WebRedirectOptions copyWith({
    WebRedirectMode? mode,
    int? popupWidth,
    int? popupHeight,
    int? popupLeft,
    int? popupTop,
    String? broadcastChannelName,
    String? iframeId,
    String? callbackPath,
    bool? autoRegisterServiceWorker,
  }) {
    return WebRedirectOptions(
      mode: mode ?? this.mode,
      popupWidth: popupWidth ?? this.popupWidth,
      popupHeight: popupHeight ?? this.popupHeight,
      popupLeft: popupLeft ?? this.popupLeft,
      popupTop: popupTop ?? this.popupTop,
      broadcastChannelName: broadcastChannelName ?? this.broadcastChannelName,
      iframeId: iframeId ?? this.iframeId,
      callbackPath: callbackPath ?? this.callbackPath,
      autoRegisterServiceWorker:
          autoRegisterServiceWorker ?? this.autoRegisterServiceWorker,
    );
  }
}
