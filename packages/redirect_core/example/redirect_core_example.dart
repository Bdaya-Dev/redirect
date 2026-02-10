import 'dart:io';

import 'package:redirect_core/redirect_core.dart';

/// Example implementation of [RedirectHandler] for demonstration purposes.
///
/// In real usage, you would use a platform-specific implementation
/// from the `redirect` package (for Flutter) or implement your own
/// for pure Dart applications.
class ExampleRedirect implements RedirectHandler {
  @override
  RedirectHandle run({
    required Uri url,
    RedirectOptions options = const RedirectOptions(),
  }) {
    // This is just a mock implementation for demonstration.
    // Real implementations would:
    // - Open a browser/webview
    // - Listen for the callback URL
    // - Return the result

    stdout
      ..writeln('Opening URL: $url')
      ..writeln('Options: $options');

    return RedirectHandle(
      url: url,
      options: options,
      result: Future.delayed(
        const Duration(milliseconds: 100),
        () => RedirectSuccess(
          uri: Uri.parse(
            'myapp://callback?code=mock_code&state=abc123',
          ),
        ),
      ),
      cancel: () async {
        stdout.writeln('Cancelling pending redirect operation');
      },
    );
  }
}

void main() async {
  final redirect = ExampleRedirect();

  // Example: Run a redirect flow
  final handle = redirect.run(
    url: Uri.parse('https://auth.example.com/authorize?client_id=xxx'),
    options: const RedirectOptions(
      timeout: Duration(minutes: 5),
      preferEphemeral: true,
    ),
  );

  // Each handle has a unique nonce (redirect request ID)
  stdout.writeln('Nonce: ${handle.nonce}');

  final result = await handle.result;

  // Handle the result using pattern matching
  switch (result) {
    case RedirectSuccess(:final uri):
      stdout
        ..writeln('Success! Received callback: $uri')
        ..writeln('Query parameters: ${uri.queryParameters}');
    case RedirectCancelled():
      stdout.writeln('User cancelled the redirect flow');
    case RedirectPending():
      stdout.writeln('Redirect initiated - result will arrive later');
    case RedirectFailure(:final error, :final stackTrace):
      stdout.writeln('Error: $error');
      if (stackTrace != null) {
        stdout.writeln('Stack trace: $stackTrace');
      }
  }
}
