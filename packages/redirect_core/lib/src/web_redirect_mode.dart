import 'package:redirect_core/src/web_redirect_options.dart';

/// Specifies how the redirect URL should be opened on web.
enum WebRedirectMode {
  /// Opens a popup window.
  ///
  /// The popup dimensions, position, and browser chrome can be customized via
  /// [WebRedirectOptions.popupOptions].
  ///
  /// This is often blocked by popup blockers if not triggered by a user
  /// gesture (click/tap).
  popup,

  /// Opens in a new browser tab.
  ///
  /// The original page remains open. The callback is received via the
  /// BroadcastChannel API.
  ///
  /// Customize the tab target and features via
  /// [WebRedirectOptions.newTabOptions].
  newTab,

  /// Redirects the current page (same-tab navigation).
  ///
  /// The entire page navigates away to the redirect URL. After
  /// the redirect, the server redirects back to your callback URL.
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

  /// Opens the redirect URL in an iframe.
  ///
  /// By default the iframe is hidden (`display: none`), which is useful for
  /// silent or background redirects. Set `IframeOptions(hidden: false)` to
  /// make the iframe visible (e.g., for embedding consent forms or payment
  /// pages).
  ///
  /// Customize the iframe element via [WebRedirectOptions.iframeOptions].
  ///
  /// **Security note**: Many servers block iframe embedding
  /// via X-Frame-Options or CSP. This mode may not work with all providers.
  iframe,
}
