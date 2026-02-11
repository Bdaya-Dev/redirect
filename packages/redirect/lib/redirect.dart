/// Flutter plugin to facilitate redirect-based flows.
///
/// This package provides a cross-platform API for handling redirect-based
/// flows.
///
/// ## Usage
///
/// ```dart
/// import 'package:redirect/redirect.dart';
///
/// final result = await runRedirect(
///   url: Uri.parse('https://example.com/authorize'),
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
        CallbackConfig,
        CustomSchemeCallbackConfig,
        DarwinRedirectOptions,
        HttpsCallbackConfig,
        IframeOptions,
        IosRedirectOptions,
        LinuxRedirectOptions,
        MacosRedirectOptions,
        NewTabOptions,
        PopupOptions,
        RedirectCancelled,
        RedirectFailure,
        RedirectHandle,
        RedirectHandler,
        RedirectOptions,
        RedirectPending,
        RedirectResult,
        RedirectSuccess,
        WebCallbackValidator,
        WebRedirectMode,
        WebRedirectOptions,
        WindowsRedirectOptions;

export 'src/construct_redirect_url.dart';

/// Opens [url] and waits for a redirect callback.
///
/// Returns a [RedirectHandle] synchronously. On web, the browser window
/// is pre-opened in the current call stack to avoid popup blockers.
///
/// Callback matching is configured per-platform via [options]:
/// - **iOS/macOS**: Use `IosRedirectOptions` / `MacosRedirectOptions` with
///   a [CallbackConfig] (custom scheme or HTTPS host+path).
/// - **Android**: Use `AndroidRedirectOptions` with `callbackUrlScheme`
///   matching the manifest intent filter.
/// - **Web**: Use `WebRedirectOptions` with an optional `callbackValidator`.
/// - **Desktop/IO**: Use `WindowsRedirectOptions` / `LinuxRedirectOptions`
///   with an optional `callbackValidator`.
///
/// This is a convenience function that delegates to
/// [RedirectPlatform.instance].
///
/// See [RedirectPlatform.run] for details.
RedirectHandle runRedirect({
  required Uri url,
  RedirectOptions options = const RedirectOptions(),
}) {
  return RedirectPlatform.instance.run(
    url: url,
    options: options,
  );
}
