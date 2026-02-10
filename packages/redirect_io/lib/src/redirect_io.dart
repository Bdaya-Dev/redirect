import 'dart:async';
import 'dart:io';

import 'package:redirect_core/redirect_core.dart';
import 'package:redirect_io/src/io_redirect_options.dart';

/// Pure Dart IO implementation of [RedirectHandler].
///
/// Uses a loopback HTTP server to capture redirect callbacks.
/// Automatically opens the system browser and waits for the callback.
///
/// This implementation works on Linux, macOS, and Windows without any
/// platform-specific dependencies.
class RedirectIo implements RedirectHandler {
  /// Creates a new IO redirect handler.
  ///
  /// [ioOptions] configures server port, host, HTML responses, etc.
  RedirectIo({
    this.ioOptions = const IoRedirectOptions(),
  });

  /// IO-specific options.
  final IoRedirectOptions ioOptions;

  HttpServer? _server;
  Completer<RedirectResult>? _completer;

  @override
  RedirectHandle run({
    required Uri url,
    required String callbackUrlScheme,
    RedirectOptions options = const RedirectOptions(),
  }) {
    // Extract IO options from platformOptions, falling back to
    // constructor-injected defaults.
    final effectiveOptions = IoRedirectOptions.fromOptions(
      options,
      ioOptions,
    );

    // Cancel any existing operation synchronously
    _cancelSync();

    _completer = Completer<RedirectResult>();
    final completer = _completer!;

    Future<RedirectResult> doRun() async {
      try {
        final callbackUrl = effectiveOptions.callbackUrl;
        final host = callbackUrl?.host ?? 'localhost';
        final port = callbackUrl?.port ?? 0;
        final callbackPath =
            (callbackUrl?.path.isNotEmpty ?? false) ? callbackUrl!.path : '/callback';

        // Start loopback server
        _server = await HttpServer.bind(host, port);
        final actualPort = _server!.port;

        // Construct the redirect URI using the loopback server
        final redirectUri = Uri(
          scheme: 'http',
          host: host,
          port: actualPort,
          path: callbackPath,
        );

        // Modify the authorization URL to use our redirect URI
        final authUrl = url.replace(
          queryParameters: {
            ...url.queryParameters,
            'redirect_uri': redirectUri.toString(),
          },
        );

        // Handle incoming requests
        _server!.listen(
          (request) async {
            await _handleRequest(
              request: request,
              callbackUrlScheme: callbackUrlScheme,
              completer: completer,
              callbackPath: callbackPath,
              ioOptions: effectiveOptions,
            );
          },
          onError: (Object error, StackTrace stackTrace) {
            if (!completer.isCompleted) {
              completer.complete(
                RedirectFailure(error: error, stackTrace: stackTrace),
              );
            }
          },
        );

        // Launch the browser if enabled
        if (effectiveOptions.openBrowser) {
          final launched = await _launchBrowser(authUrl);

          if (!launched) {
            await _cleanup();
            return RedirectFailure(
              error: Exception('Failed to launch browser. URL: $authUrl'),
              stackTrace: StackTrace.current,
            );
          }
        }

        // Wait for result with optional timeout
        if (options.timeout != null) {
          return await completer.future.timeout(
            options.timeout!,
            onTimeout: () {
              unawaited(_cleanup());
              return const RedirectCancelled();
            },
          );
        }

        return await completer.future;
      } on Object catch (e, s) {
        await _cleanup();
        return RedirectFailure(error: e, stackTrace: s);
      }
    }

    return RedirectHandle(
      url: url,
      callbackUrlScheme: callbackUrlScheme,
      options: options,
      result: doRun(),
      cancel: _cancel,
    );
  }

  Future<void> _handleRequest({
    required HttpRequest request,
    required String callbackUrlScheme,
    required Completer<RedirectResult> completer,
    required String callbackPath,
    required IoRedirectOptions ioOptions,
  }) async {
    try {
      if (request.uri.path == callbackPath) {
        // Check for error response from the redirect target
        final error = request.uri.queryParameters['error'];
        if (error != null) {
          await _sendErrorResponse(request, error, ioOptions);
          if (!completer.isCompleted) {
            completer.complete(
              RedirectFailure(
                error: AuthorizationException(
                  error: error,
                  description: request.uri.queryParameters['error_description'],
                ),
                stackTrace: StackTrace.current,
              ),
            );
          }
          await _cleanup();
          return;
        }

        // Construct the callback URI with the original scheme
        final callbackUri = Uri(
          scheme: callbackUrlScheme,
          host: 'callback',
          queryParameters: request.uri.queryParameters,
        );

        // Send success response to browser
        await _sendSuccessResponse(request, ioOptions);

        // Complete with success
        if (!completer.isCompleted) {
          completer.complete(RedirectSuccess(uri: callbackUri));
        }

        await _cleanup();
      } else {
        // Handle other paths (favicon, etc.)
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      }
    } on Object catch (e, s) {
      if (!completer.isCompleted) {
        completer.complete(RedirectFailure(error: e, stackTrace: s));
      }
    }
  }

  Future<void> _sendSuccessResponse(
    HttpRequest request,
    IoRedirectOptions ioOptions,
  ) async {
    request.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.html
      ..write(ioOptions.successHtml ?? _defaultSuccessHtml);
    await request.response.close();
  }

  Future<void> _sendErrorResponse(
    HttpRequest request,
    String error,
    IoRedirectOptions ioOptions,
  ) async {
    // HTML-escape the error to prevent XSS attacks
    final escapedError = _htmlEscape(error);
    final html =
        ioOptions.errorHtml ??
        _defaultErrorHtml.replaceAll('{{error}}', escapedError);
    request.response
      ..statusCode = HttpStatus.badRequest
      ..headers.contentType = ContentType.html
      ..write(html);
    await request.response.close();
  }

  /// Escapes HTML special characters to prevent XSS.
  String _htmlEscape(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#x27;');
  }

  /// Launches the system browser with the given URL.
  Future<bool> _launchBrowser(Uri url) async {
    final urlString = url.toString();

    try {
      ProcessResult result;

      if (Platform.isLinux) {
        result = await Process.run('xdg-open', [urlString]);
      } else if (Platform.isMacOS) {
        result = await Process.run('open', [urlString]);
      } else if (Platform.isWindows) {
        // Windows 'start' command needs cmd.exe
        // Empty title is required when URL contains special chars
        result = await Process.run(
          'cmd',
          ['/c', 'start', '', urlString],
          runInShell: true,
        );
      } else {
        return false;
      }

      return result.exitCode == 0;
    } on Object {
      return false;
    }
  }

  void _cancelSync() {
    if (_completer != null && !_completer!.isCompleted) {
      _completer!.complete(const RedirectCancelled());
    }
    unawaited(_cleanup());
  }

  Future<void> _cancel() async {
    if (_completer != null && !_completer!.isCompleted) {
      _completer!.complete(const RedirectCancelled());
    }
    await _cleanup();
  }

  Future<void> _cleanup() async {
    await _server?.close(force: true);
    _server = null;
    _completer = null;
  }

  /// Returns the port the server is listening on.
  ///
  /// Returns null if the server is not running.
  int? get serverPort => _server?.port;

  /// Returns the full callback URL the server is listening on.
  ///
  /// Useful when [IoRedirectOptions.openBrowser] is false and you need
  /// to display the URL to the user.
  ///
  /// Returns null if the server is not running.
  Uri? get callbackUrl {
    if (_server == null) return null;
    final url = ioOptions.callbackUrl;
    return Uri(
      scheme: 'http',
      host: url?.host ?? 'localhost',
      port: _server!.port,
      path: (url?.path.isNotEmpty ?? false) ? url!.path : '/callback',
    );
  }
}

/// An exception representing an authorization error response.
class AuthorizationException implements Exception {
  /// Creates an authorization exception.
  const AuthorizationException({
    required this.error,
    this.description,
  });

  /// The error code from the authorization server.
  final String error;

  /// Optional human-readable description of the error.
  final String? description;

  @override
  String toString() {
    if (description != null) {
      return 'AuthorizationException: $error - $description';
    }
    return 'AuthorizationException: $error';
  }
}

const _defaultSuccessHtml = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Authentication Successful</title>
  <style>
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      display: flex;
      justify-content: center;
      align-items: center;
      min-height: 100vh;
      margin: 0;
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      color: white;
    }
    .container {
      text-align: center;
      padding: 2rem;
    }
    .checkmark {
      font-size: 4rem;
      margin-bottom: 1rem;
    }
    h1 { margin: 0 0 0.5rem; }
    p { opacity: 0.9; }
  </style>
</head>
<body>
  <div class="container">
    <div class="checkmark">✓</div>
    <h1>Authentication Successful</h1>
    <p>You can close this window and return to the application.</p>
  </div>
</body>
</html>
''';

const _defaultErrorHtml = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Authentication Failed</title>
  <style>
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      display: flex;
      justify-content: center;
      align-items: center;
      min-height: 100vh;
      margin: 0;
      background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%);
      color: white;
    }
    .container {
      text-align: center;
      padding: 2rem;
    }
    .error-icon {
      font-size: 4rem;
      margin-bottom: 1rem;
    }
    h1 { margin: 0 0 0.5rem; }
    p { opacity: 0.9; }
    .error-code {
      background: rgba(0,0,0,0.2);
      padding: 0.5rem 1rem;
      border-radius: 4px;
      margin-top: 1rem;
      font-family: monospace;
    }
  </style>
</head>
<body>
  <div class="container">
    <div class="error-icon">✗</div>
    <h1>Authentication Failed</h1>
    <p>An error occurred during authentication.</p>
    <div class="error-code">{{error}}</div>
  </div>
</body>
</html>
''';
