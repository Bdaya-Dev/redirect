import 'package:redirect_core/src/redirect_handle.dart';
import 'package:redirect_core/src/redirect_options.dart';
import 'package:redirect_core/src/redirect_result.dart';

/// Abstract interface for handling redirect-based flows.
///
/// This interface defines the contract for redirect operations. Platform
/// implementations provide concrete behavior for:
/// - Mobile (iOS/Android): Custom URL schemes, Universal/App Links
/// - Web: Popup windows with BroadcastChannel/postMessage
/// - Desktop: Loopback HTTP server (RFC 8252)
///
/// ## Usage
///
/// ```dart
/// final redirect = MyRedirectImplementation();
///
/// // Synchronous — on web, pre-opens a popup/tab in user-gesture context.
/// final handle = redirect.run(
///   url: Uri.parse('https://example.com/start?callback=myapp://done'),
/// );
///
/// // Await the result separately (won't trigger popup blockers).
/// final result = await handle.result;
///
/// switch (result) {
///   case RedirectSuccess(:final uri):
///     print('Callback received: $uri');
///   case RedirectCancelled():
///     print('User cancelled');
///   case RedirectFailure(:final error):
///     print('Error: $error');
/// }
/// ```
// ignore: one_member_abstracts
abstract interface class RedirectHandler {
  /// Opens [url] and waits for a redirect callback.
  ///
  /// Returns a [RedirectHandle] **synchronously**. This is important on web,
  /// where the browser window must be opened in the user-gesture call stack
  /// to avoid popup blockers. The actual result is available via
  /// `RedirectHandle.result`.
  ///
  /// ## Parameters
  ///
  /// - [url]: The URL to open (e.g., authorization endpoint, payment page)
  /// - [options]: Configuration for timeout, ephemeral sessions, and
  ///   platform-specific callback matching (see platform option classes).
  ///
  /// ## Callback Matching by Platform
  ///
  /// Each platform defines how callbacks are matched in its own options:
  ///
  /// | Platform | Option Class | Matching |
  /// |----------|-------------|----------|
  /// | iOS/macOS | `DarwinRedirectOptions` | `CallbackConfig` |
  /// | Android | `AndroidRedirectOptions` | Manifest intent filter |
  /// | Web | `WebRedirectOptions` | `callbackValidator` |
  /// | Desktop/IO | `ServerRedirectOptions` | `callbackValidator` |
  ///
  /// ## Error Handling
  ///
  /// The `RedirectHandle.result` future does not throw exceptions for
  /// expected outcomes. Instead, it completes with appropriate
  /// [RedirectResult] subtypes:
  /// - [RedirectSuccess] - Callback received successfully
  /// - [RedirectCancelled] - User dismissed the browser/cancelled
  /// - [RedirectFailure] - An error occurred
  RedirectHandle run({
    required Uri url,
    RedirectOptions options = const RedirectOptions(),
  });
}
