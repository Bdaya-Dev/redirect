/// Pure Dart CLI implementation of redirect-based flows.
///
/// This package provides a CLI-friendly implementation that works with
/// any Dart application (CLI tools, servers, scripts, etc.) without
/// requiring Flutter.
///
/// ## Usage
///
/// ```dart
/// import 'package:redirect_cli/redirect_cli.dart';
///
/// void main() async {
///   final redirect = RedirectCli();
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
///       print('Pending'); // Not used in CLI
///     case RedirectFailure(:final error):
///       print('Error: $error');
///   }
/// }
/// ```
///
/// ## How it works
///
/// 1. Starts a local HTTP server on a specified port (or finds an
///    available one)
/// 2. Opens the system browser with the authorization URL
/// 3. Waits for the provider to redirect back to the local server
/// 4. Returns the callback URI containing the response
///
/// ## Customization
///
/// ```dart
/// final redirect = RedirectCli(
///   options: CliRedirectOptions(
///     port: 8080, // Or use portRange for auto-selection
///     successHtml: '<html>Success! You can close this tab.</html>',
///     errorHtml: '<html>Error occurred.</html>',
///   ),
/// );
/// ```
library;

export 'package:redirect_core/redirect_core.dart';
export 'src/cli_redirect_options.dart';
export 'src/redirect_cli.dart';
