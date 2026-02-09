/// Example demonstrating redirect_android usage.
///
/// This is the Android implementation of the redirect plugin.
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
/// For Android-specific options, pass [AndroidRedirectOptions]:
///
/// ```dart
/// final handle = redirect.run(
///   url: authUrl,
///   callbackUrlScheme: 'myapp',
///   options: RedirectOptions(
///     platformOptions: {
///       AndroidRedirectOptions.key: AndroidRedirectOptions(
///         useCustomTabs: true,
///         showTitle: true,
///       ),
///     },
///   ),
/// );
/// ```
library;
