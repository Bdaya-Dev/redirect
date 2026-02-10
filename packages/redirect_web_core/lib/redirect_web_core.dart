/// Pure Dart web implementation of redirect-based flows.
///
/// This package provides a web-specific implementation that works with
/// any Dart web framework (Flutter, Jaspr, pure Dart, etc.).
///
/// ## Usage
///
/// ```dart
/// import 'package:redirect_web_core/redirect_web_core.dart';
///
/// final redirect = RedirectWeb();
///
/// final handle = redirect.run(
///   url: Uri.parse('https://auth.example.com/authorize'),
///   callbackUrlScheme: 'https',
///   options: RedirectOptions(
///     platformOptions: {
///       WebRedirectOptions.key: WebRedirectOptions(
///         mode: WebRedirectMode.popup,
///         callbackPath: '/callback.html',
///         autoRegisterServiceWorker: true,
///       ),
///     },
///   ),
/// );
/// final result = await handle.result;
/// ```
library;

export 'package:redirect_core/redirect_core.dart'
    show WebRedirectMode, WebRedirectOptions;
export 'src/redirect_web.dart';
export 'src/redirect_web_assets.dart';
