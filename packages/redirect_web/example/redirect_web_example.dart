// comment_references: Doc comments reference types from the redirect package.
// ignore_for_file: comment_references

/// Example demonstrating redirect_web usage.
///
/// This is the Flutter web implementation of the redirect plugin.
/// It wraps redirect_web_core for Flutter plugin registration.
/// Typically used through the `redirect` package which automatically
/// selects the correct platform implementation.
///
/// ```dart
/// import 'package:redirect/redirect.dart';
///
/// final redirect = Redirect();
/// final handle = redirect.run(
///   url: Uri.parse('https://example.com/authorize'),
///   callbackUrlScheme: 'myapp',
/// );
/// final result = await handle.result;
/// ```
///
/// For web-specific options, pass [WebRedirectOptions]:
///
/// ```dart
/// final handle = redirect.run(
///   url: redirectUrl,
///   callbackUrlScheme: 'myapp',
///   options: RedirectOptions(
///     platformOptions: {
///       WebRedirectOptions.key: WebRedirectOptions(
///         mode: WebRedirectMode.popup,
///         popupOptions: PopupOptions(
///           width: 600,
///           height: 800,
///         ),
///       ),
///     },
///   ),
/// );
/// ```
library;
