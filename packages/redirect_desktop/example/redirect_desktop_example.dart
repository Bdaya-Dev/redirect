// comment_references: Doc comments reference types from the redirect package.
// ignore_for_file: comment_references

/// Example demonstrating redirect_desktop usage.
///
/// This is the Linux/Windows implementation of the redirect plugin.
/// Uses a loopback HTTP server to capture OAuth redirect callbacks.
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
/// For desktop-specific options, pass [DesktopRedirectOptions]:
///
/// ```dart
/// final handle = redirect.run(
///   url: authUrl,
///   callbackUrlScheme: 'http',
///   options: RedirectOptions(
///     platformOptions: {
///       DesktopRedirectOptions.key: DesktopRedirectOptions(
///         port: 8080,
///         host: 'localhost',
///         callbackPath: '/callback',
///         successHtml: '<html><body>Success! You may close this tab.</body></html>',
///       ),
///     },
///   ),
/// );
/// ```
library;
