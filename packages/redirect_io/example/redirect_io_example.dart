/// Example demonstrating redirect_io usage.
///
/// This example shows how to use the IO redirect implementation
/// for redirect-based flows in Dart applications.
///
/// Run with:
/// ```bash
/// dart run example/redirect_io_example.dart
/// ```
library;

import 'dart:io';

import 'package:redirect_io/redirect_io.dart';

/// Example subclass that provides per-redirect options.
class ExampleRedirectIo extends RedirectIo {
  @override
  ServerRedirectOptions getOptions(RedirectOptions options) {
    return ServerRedirectOptions(
      httpResponseBuilder: (request) {
        return const HttpCallbackResponse(
          body: '''
<!DOCTYPE html>
<html>
<head>
  <style>
    body { 
      font-family: system-ui; 
      display: flex; 
      justify-content: center; 
      align-items: center; 
      height: 100vh; 
      margin: 0;
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      color: white;
    }
    .container { text-align: center; }
  </style>
</head>
<body>
  <div class="container">
    <h1>&#x2713; Redirect Complete</h1>
    <p>You can close this window and return to the app.</p>
  </div>
</body>
</html>
''',
        );
      },
    );
  }
}

void main() async {
  stdout
    ..writeln('Redirect IO Example')
    ..writeln('====================\n');

  // Create the redirect handler
  final redirect = ExampleRedirectIo();

  // Test URL using httpbin to simulate a redirect
  // In a real app, this would be your provider's authorization URL
  final testUrl = Uri.parse(
    'https://httpbin.org/redirect-to'
    '?url=myapp%3A%2F%2Fcallback%3Fcode%3Dtest_auth_code_123'
    '&status_code=302',
  );

  stdout
    ..writeln('Starting redirect flow...')
    ..writeln('URL: $testUrl\n')
    ..writeln(
      'A browser window will open. Complete the flow to continue.\n',
    );

  final handle = redirect.run(
    url: testUrl,
    options: const RedirectOptions(
      timeout: Duration(minutes: 2),
    ),
  );

  try {
    final result = await handle.result;

    stdout.writeln('\nResult:');
    switch (result) {
      case RedirectSuccess(:final uri):
        stdout
          ..writeln('  ✓ Success!')
          ..writeln('  Callback URI: $uri')
          ..writeln('  Query parameters:');
        for (final entry in uri.queryParameters.entries) {
          stdout.writeln('    ${entry.key}: ${entry.value}');
        }
      case RedirectCancelled():
        stdout.writeln('  ✗ Cancelled by user or timeout');
      case RedirectPending():
        stdout.writeln('  ⏳ Pending (not used in CLI)');
      case RedirectFailure(:final error, :final stackTrace):
        stdout.writeln('  ✗ Failed: $error');
        if (stackTrace != null) {
          stdout.writeln('  Stack trace:\n$stackTrace');
        }
    }
  } finally {
    // Always clean up
    await handle.cancel();
  }
}
