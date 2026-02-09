import 'package:redirect_core/src/web_redirect_options.dart';

/// Specifies how the authorization URL should be opened on web.
enum WebRedirectMode {
  /// Opens a popup window.
  ///
  /// The popup dimensions and position can be customized via
  /// [WebRedirectOptions.popupWidth] and [WebRedirectOptions.popupHeight].
  ///
  /// This is often blocked by popup blockers if not triggered by a user
  /// gesture (click/tap).
  popup,

  /// Opens in a new browser tab.
  ///
  /// The original page remains open. The callback is received via the
  /// BroadcastChannel API.
  newTab,

  /// Redirects the current page (same-tab navigation).
  ///
  /// The entire page navigates away to the authorization URL. After
  /// authorization, the provider redirects back to your callback URL.
  ///
  /// **Important**: When using this mode, you must:
  /// 1. Store any necessary state before calling `run()` (e.g., in
  ///    sessionStorage or localStorage)
  /// 2. Handle the callback by calling `RedirectWeb.resumePendingRedirect()`
  ///    early in your app's `main()` on the next page load
  ///
  /// This mode returns `RedirectPending` immediately since the page
  /// navigates away. The actual result must be retrieved on the callback page.
  samePage,

  /// Opens in a hidden iframe.
  ///
  /// Useful for silent token refresh when the authorization server supports
  /// `prompt=none` or similar.
  ///
  /// **Security note**: Many authorization servers block iframe embedding
  /// via X-Frame-Options or CSP. This mode may not work with all providers.
  hiddenIframe,
}
