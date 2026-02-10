/// Flutter plugin to facilitate redirect-based flows.
///
/// This package provides a cross-platform API for handling redirect-based
/// flows such as authorization or payment gateway redirects.
///
/// ## Usage
///
/// ```dart
/// import 'package:redirect/redirect.dart';
///
/// final result = await runRedirect(
///   url: Uri.parse('https://example.com/authorize'),
///   callbackUrlScheme: 'myapp',
/// );
///
/// switch (result) {
///   case RedirectSuccess(:final uri):
///     print('Received callback: $uri');
///   case RedirectCancelled():
///     print('User cancelled');
///   case RedirectFailure(:final error):
///     print('Error: $error');
/// }
/// ```
library;

import 'package:redirect_platform_interface/redirect_platform_interface.dart';

export 'package:redirect_platform_interface/redirect_platform_interface.dart'
    show
        AndroidRedirectOptions,
        DarwinRedirectOptions,
        DesktopRedirectOptions,
        RedirectCancelled,
        RedirectFailure,
        RedirectHandle,
        RedirectHandler,
        RedirectOptions,
        RedirectPending,
        RedirectResult,
        RedirectSuccess,
        WebRedirectMode,
        WebRedirectOptions;

/// Opens [url] and waits for a redirect matching [callbackUrlScheme].
///
/// Returns a [RedirectHandle] synchronously. On web, the browser window
/// is pre-opened in the current call stack to avoid popup blockers.
///
/// This is a convenience function that delegates to
/// [RedirectPlatform.instance].
///
/// See [RedirectPlatform.run] for details.
RedirectHandle runRedirect({
  required Uri url,
  required String callbackUrlScheme,
  RedirectOptions options = const RedirectOptions(),
}) {
  return RedirectPlatform.instance.run(
    url: url,
    callbackUrlScheme: callbackUrlScheme,
    options: options,
  );
}
