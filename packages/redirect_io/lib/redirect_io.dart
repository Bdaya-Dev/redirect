/// Pure Dart IO implementation of redirect-based flows.
///
/// This package provides a loopback-HTTP-server-based implementation
/// that works with any Dart application (CLI tools, servers, desktop
/// apps, etc.) without requiring Flutter.
///
/// ## Usage
///
/// ```dart
/// import 'package:redirect_io/redirect_io.dart';
///
/// void main() async {
///   final redirect = RedirectIo();
///
///   final result = await redirect.run(
///     url: Uri.parse('https://auth.example.com/authorize?client_id=...'),
///     callbackUrlScheme: 'myapp',
///   );
///
///   switch (result) {
///     case RedirectSuccess(:final uri):
///       print('Got token: ${uri.queryParameters['code']}');
///     case RedirectCancelled():
///       print('Cancelled');
///     case RedirectPending():
///       print('Pending');
///     case RedirectFailure(:final error):
///       print('Error: $error');
///   }
/// }
/// ```
///
/// ## How it works
///
/// 1. Starts a local HTTP server on a specified port (or auto-selects one)
/// 2. Opens the system browser with the authorization URL
/// 3. Waits for the provider to redirect back to the local server
/// 4. Returns the callback URI containing the response
///
/// ## Customization
///
/// ```dart
/// final redirect = RedirectIo(
///   ioOptions: IoRedirectOptions(
///     callbackUrl: Uri.parse('http://localhost:8080/callback'),
///     successHtml: '<html>Success! You can close this tab.</html>',
///     errorHtml: '<html>Error occurred.</html>',
///   ),
/// );
/// ```
library;

export 'package:redirect_core/redirect_core.dart';
export 'src/io_redirect_options.dart';
export 'src/redirect_io.dart';
