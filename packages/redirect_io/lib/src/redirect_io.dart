import 'dart:async';
import 'dart:io';

import 'package:redirect_core/redirect_core.dart';

/// Tracks state for a single in-flight IO redirect operation.
class _PendingIoRedirect {
  _PendingIoRedirect({
    required this.server,
    required this.completer,
  });

  final HttpServer server;
  final Completer<RedirectResult> completer;
}

/// Abstract pure Dart IO implementation of [RedirectHandler].
///
/// Uses a loopback HTTP server to capture redirect callbacks.
/// Automatically opens the system browser and waits for the callback.
///
/// This implementation works on Linux, macOS, and Windows without any
/// platform-specific dependencies.
///
/// Supports multiple concurrent redirect operations — each run gets its
/// own loopback server on a separate ephemeral port.
///
/// Subclasses must implement [getOptions] to extract [ServerRedirectOptions]
/// from the per-redirect [RedirectOptions].
abstract class RedirectIo implements RedirectHandler {
  /// Creates a new IO redirect handler.
  RedirectIo();

  /// All in-flight redirect operations, keyed by nonce.
  final Map<String, _PendingIoRedirect> _pendingRedirects = {};

  /// Extracts [ServerRedirectOptions] from the per-redirect [options].
  ///
  /// Subclasses decide how to map the generic [RedirectOptions]
  /// (and its [RedirectOptions.platformOptions]) to [ServerRedirectOptions].
  ServerRedirectOptions getOptions(RedirectOptions options);

  @override
  RedirectHandle run({
    required Uri url,
    RedirectOptions options = const RedirectOptions(),
  }) {
    // Extract IO options via the subclass hook.
    final effectiveOptions = getOptions(options);

    // Generate nonce for this redirect operation.
    final nonce = generateRedirectNonce();

    final completer = Completer<RedirectResult>();

    Future<RedirectResult> doRun() async {
      try {
        final callbackUrl = effectiveOptions.callbackUrl;
        final host = callbackUrl?.host ?? 'localhost';
        final port = callbackUrl?.port ?? 0;
        final callbackPath = (callbackUrl?.path.isNotEmpty ?? false)
            ? callbackUrl!.path
            : '/callback';

        // Start loopback server
        final server = await HttpServer.bind(host, port);
        final actualPort = server.port;

        // Track this operation.
        _pendingRedirects[nonce] = _PendingIoRedirect(
          server: server,
          completer: completer,
        );

        // Inform the caller of the actual port (useful when port 0 was used).
        effectiveOptions.portCompleter?.complete(actualPort);

        // Build the final URL to navigate to.
        final navigateUrl =
            effectiveOptions.urlBuilder?.call(actualPort) ?? url;

        // Default validator: match by callback path.
        final callbackValidator = effectiveOptions.callbackValidator ??
            (Uri uri) => uri.path == callbackPath;

        // Handle incoming requests
        server.listen(
          (request) async {
            await _handleRequest(
              nonce: nonce,
              request: request,
              completer: completer,
              callbackValidator: callbackValidator,
              ioOptions: effectiveOptions,
            );
          },
          onError: (Object error, StackTrace stackTrace) {
            if (!completer.isCompleted) {
              completer.complete(
                RedirectFailure(error: error, stackTrace: stackTrace),
              );
              unawaited(_cleanupNonce(nonce));
            }
          },
        );

        // Launch the browser if enabled
        if (effectiveOptions.openBrowser) {
          final launched = await _launchBrowser(navigateUrl);

          if (!launched) {
            await _cleanupNonce(nonce);
            return RedirectFailure(
              error: Exception('Failed to launch browser. URL: $navigateUrl'),
              stackTrace: StackTrace.current,
            );
          }
        }

        // Wait for result with optional timeout
        if (options.timeout != null) {
          return await completer.future.timeout(
            options.timeout!,
            onTimeout: () {
              unawaited(_cleanupNonce(nonce));
              return const RedirectCancelled();
            },
          );
        }

        return await completer.future;
      } on Object catch (e, s) {
        if (effectiveOptions.portCompleter != null &&
            !effectiveOptions.portCompleter!.isCompleted) {
          effectiveOptions.portCompleter!.completeError(e, s);
        }
        await _cleanupNonce(nonce);
        return RedirectFailure(error: e, stackTrace: s);
      }
    }

    return RedirectHandle(
      url: url,
      nonce: nonce,
      options: options,
      result: doRun(),
      cancel: () => _cancelNonce(nonce),
    );
  }

  Future<void> _handleRequest({
    required String nonce,
    required HttpRequest request,
    required Completer<RedirectResult> completer,
    required CallbackValidator callbackValidator,
    required ServerRedirectOptions ioOptions,
  }) async {
    try {
      final isCallback = await callbackValidator(request.uri);
      if (isCallback) {
        // Send response to browser (using builder or default)
        await _sendCallbackResponse(request, ioOptions);

        // Complete with the actual request URI as-is.
        if (!completer.isCompleted) {
          completer.complete(RedirectSuccess(uri: request.uri));
        }

        await _cleanupNonce(nonce);
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

  Future<void> _sendCallbackResponse(
    HttpRequest request,
    ServerRedirectOptions ioOptions,
  ) async {
    final builder = ioOptions.httpResponseBuilder;
    final requestHeaders = <String, String>{};
    request.headers.forEach((name, values) {
      requestHeaders[name] = values.join(', ');
    });
    final callbackRequest = HttpCallbackRequest(
      uri: request.uri,
      method: request.method,
      headers: requestHeaders,
    );
    final response = builder != null
        ? builder(callbackRequest)
        : const HttpCallbackResponse(
            body: _defaultCallbackHtml,
          );

    request.response.statusCode = response.statusCode;
    for (final entry in response.headers.entries) {
      request.response.headers.set(entry.key, entry.value);
    }
    request.response.write(response.body);
    await request.response.close();
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

  /// Cancels a specific redirect operation by nonce.
  Future<void> _cancelNonce(String nonce) async {
    final pending = _pendingRedirects.remove(nonce);
    if (pending == null) return;
    if (!pending.completer.isCompleted) {
      pending.completer.complete(const RedirectCancelled());
    }
    await pending.server.close(force: true);
  }

  /// Cleans up server resources for a specific nonce without completing
  /// the completer (assumes it's already completed or will be completed
  /// by the caller).
  Future<void> _cleanupNonce(String nonce) async {
    final pending = _pendingRedirects.remove(nonce);
    if (pending == null) return;
    await pending.server.close(force: true);
  }

  /// Returns the port the server is listening on for a given nonce.
  ///
  /// Returns null if no server is running for that nonce.
  int? serverPortForNonce(String nonce) =>
      _pendingRedirects[nonce]?.server.port;
}

const _defaultCallbackHtml = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Redirect Complete</title>
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
    <div class="checkmark">&#x2713;</div>
    <h1>Redirect Complete</h1>
    <p>You can close this window and return to the application.</p>
  </div>
</body>
</html>
''';
