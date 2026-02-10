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
/// class MyRedirectIo extends RedirectIo {
///   @override
///   ServerRedirectOptions getOptions(RedirectOptions options) {
///     return const ServerRedirectOptions();
///   }
/// }
///
/// void main() async {
///   final redirect = MyRedirectIo();
///
///   final result = await redirect.run(
///     url: Uri.parse('https://auth.example.com/authorize?client_id=...'),
///   ).result;
///
///   switch (result) {
///     case RedirectSuccess(:final uri):
///       print('Got callback: ${uri}');
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
/// 2. Opens the system browser with the redirect URL
/// 3. Waits for the target to redirect back to the local server
/// 4. Returns the callback URI containing the response
///
/// ## Customization
///
/// Override `RedirectIo.getOptions` to control per-redirect configuration:
///
/// ```dart
/// class CustomRedirectIo extends RedirectIo {
///   @override
///   ServerRedirectOptions getOptions(RedirectOptions options) {
///     return ServerRedirectOptions(
///       callbackUrl: Uri.parse('http://localhost:8080/callback'),
///       httpResponseBuilder: (request) {
///         return HttpCallbackResponse(
///           statusCode: 200,
///           body: '<html>Done! You can close this tab.</html>',
///         );
///       },
///     );
///   }
/// }
/// ```
library;

export 'package:redirect_core/redirect_core.dart';
export 'src/redirect_io.dart';
