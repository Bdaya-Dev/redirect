/// Asset-path constants for the redirect callback files.
///
/// The `.js` and `.html` files live in `redirect_web/assets/` and are
/// declared as Flutter assets in `redirect_web`'s pubspec. After
/// `flutter build web` they are served at the paths below.
///
/// ## Flutter web (recommended)
///
/// The callback files are **automatically bundled**. After
/// `flutter build web` they are available at:
///
/// | File | URL |
/// |------|-----|
/// | `redirect_callback.js` | `assets/packages/redirect_web/assets/redirect_callback.js` |
/// | `redirect_callback.html` | `assets/packages/redirect_web/assets/redirect_callback.html` |
///
/// Set your redirect URI to the HTML path above
/// and the package works **out of the box** — no manual file copying.
///
/// If you need a shorter callback URL or custom HTML, place your own
/// `callback.html` in `web/` and reference the JS asset by URL:
///
/// ```html
/// <script src="assets/packages/redirect_web/assets/redirect_callback.js"></script>
/// ```
library;

import 'package:redirect_core/redirect_core.dart';

/// URL-path constants for the callback assets shipped by `redirect_web`.
///
/// The raw files live at `assets/` inside the `redirect_web` package and
/// are declared as Flutter assets, so they are copied to
/// `build/web/assets/packages/redirect_web/assets/` during
/// `flutter build web`.
abstract final class RedirectWebAssets {
  /// Relative URL path to the bundled `redirect_callback.js` asset.
  ///
  /// After `flutter build web`, the file is served at this path relative
  /// to the app's `<base href>`.
  static const callbackJsAssetPath =
      'assets/packages/redirect_web/assets/redirect_callback.js';

  /// Relative URL path to the bundled `redirect_callback.html` asset.
  ///
  /// After `flutter build web`, the file is served at this path relative
  /// to the app's `<base href>`. Point your redirect URI here
  /// for zero-config callback handling.
  ///
  /// Same value as [WebRedirectOptions.defaultCallbackPath].
  static const String callbackHtmlAssetPath =
      WebRedirectOptions.defaultCallbackPath;
}
