/// Example demonstrating redirect_web_core usage.
///
/// This is the pure Dart web implementation (no Flutter dependency).
/// Use this package directly in Dart web frameworks like Jaspr,
/// or use it through the `redirect` or `redirect_web` packages
/// for Flutter web applications.
///
/// ```dart
/// import 'package:redirect_web_core/redirect_web_core.dart';
///
/// final redirect = RedirectWeb();
/// final handle = redirect.run(
///   url: Uri.parse('https://example.com/authorize'),
///   callbackUrlScheme: 'myapp',
/// );
/// final result = await handle.result;
/// ```
///
/// Supports multiple redirect modes:
///
/// ```dart
/// // Open in a popup window
/// final handle = redirect.runWithWebOptions(
///   url: authUrl,
///   callbackUrlScheme: 'myapp',
///   webOptions: WebRedirectOptions(
///     mode: WebRedirectMode.popup,
///     popupWidth: 600,
///     popupHeight: 800,
///   ),
/// );
///
/// // Open in a new tab
/// final handle = redirect.runWithWebOptions(
///   url: authUrl,
///   callbackUrlScheme: 'myapp',
///   webOptions: WebRedirectOptions(
///     mode: WebRedirectMode.newTab,
///   ),
/// );
/// ```
library;
