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
/// // Using popup (default)
/// final result = await redirect.run(
///   url: Uri.parse('https://auth.example.com/authorize'),
///   callbackUrlScheme: 'https',
/// );
/// ```
///
/// ## Custom Web Options
///
/// Configure via constructor (applies to all calls):
///
/// ```dart
/// final redirect = RedirectWeb(
///   defaultWebOptions: WebRedirectOptions(mode: WebRedirectMode.newTab),
/// );
/// ```
///
/// Or per-call with `runWithWebOptions`:
///
/// ```dart
/// final result = await redirect.runWithWebOptions(
///   url: Uri.parse('https://auth.example.com/authorize'),
///   callbackUrlScheme: 'https',
///   webOptions: WebRedirectOptions(mode: WebRedirectMode.samePage),
/// );
/// ```
library;

export 'package:redirect_core/redirect_core.dart'
    show WebRedirectMode, WebRedirectOptions;
export 'src/redirect_web.dart';
