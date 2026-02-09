import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:redirect_desktop/src/desktop_redirect_options.dart';
import 'package:redirect_platform_interface/redirect_platform_interface.dart';

/// The desktop implementation of [RedirectPlatform].
///
/// Uses a loopback HTTP server to capture redirect callbacks.
/// This is a pure Dart implementation that works on Linux and Windows
/// without any platform-specific native code or dependencies.
///
/// On macOS, the `redirect_darwin` package is used instead (ASWebAuthenticationSession),
/// but this plugin includes a fallback `open` command for macOS in case
/// it is ever registered on that platform.
class RedirectDesktopPlugin extends RedirectPlatform {
  /// Registers this class as the default instance of [RedirectPlatform].
  static void registerWith() {
    RedirectPlatform.instance = RedirectDesktopPlugin();
  }

  HttpServer? _server;
  Completer<RedirectResult>? _completer;

  @override
  RedirectHandle run({
    required Uri url,
    required String callbackUrlScheme,
    RedirectOptions options = const RedirectOptions(),
  }) {
    final desktopOptions = DesktopRedirectOptions.fromOptions(options);

    // Cancel any existing operation synchronously
    _cancelSync();

    _completer = Completer<RedirectResult>();
    final completer = _completer!;

    Future<RedirectResult> doRun() async {
      try {
        // Start loopback server on an available port
        _server = await _startServer(desktopOptions);
        final port = _server!.port;

        // Construct the redirect URI using the loopback server
        final redirectUri = Uri(
          scheme: 'http',
          host: desktopOptions.host,
          port: port,
          path: desktopOptions.callbackPath,
        );

        // Append the redirect_uri query parameter to the authorization URL.
        // We operate on the raw query string to avoid double-encoding any
        // values that were already percent-encoded in the original URL.
        final separator = url.hasQuery ? '&' : '?';
        final redirectParam =
            'redirect_uri=${Uri.encodeComponent(redirectUri.toString())}';
        final authUrl = Uri.parse('$url$separator$redirectParam');

        // Handle incoming requests
        _server!.listen(
          (request) async {
            try {
              if (request.uri.path == desktopOptions.callbackPath) {
                // Construct the callback URI with the original scheme
                final callbackUri = Uri(
                  scheme: callbackUrlScheme,
                  host: 'callback',
                  queryParameters: request.uri.queryParameters,
                );

                // Send a success response to the browser
                request.response
                  ..statusCode = HttpStatus.ok
                  ..headers.contentType = ContentType.html
                  ..write(desktopOptions.successHtml ?? _successHtml);
                await request.response.close();

                // Complete with success
                if (!completer.isCompleted) {
                  completer.complete(RedirectSuccess(uri: callbackUri));
                }

                // Clean up
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
          },
          onError: (Object error, StackTrace stackTrace) {
            if (!completer.isCompleted) {
              completer.complete(
                RedirectFailure(error: error, stackTrace: stackTrace),
              );
            }
          },
        );

        // Launch the browser using platform-specific commands
        var launched = true;
        if (desktopOptions.openBrowser) {
          launched = await _launchUrl(authUrl);
        }

        if (!launched) {
          await _cleanup();
          return RedirectFailure(
            error: Exception('Failed to launch browser'),
            stackTrace: StackTrace.current,
          );
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

  void _cancelSync() {
    if (_completer != null && !_completer!.isCompleted) {
      _completer!.complete(const RedirectCancelled());
    }
    // Note: server cleanup is async, but we mark the completer done
    // synchronously to prevent races.
    unawaited(_cleanup());
  }

  Future<void> _cancel() async {
    if (_completer != null && !_completer!.isCompleted) {
      _completer!.complete(const RedirectCancelled());
    }
    await _cleanup();
  }

  Future<HttpServer> _startServer(DesktopRedirectOptions options) async {
    final bindAddress = options.bindAddress ?? InternetAddress.loopbackIPv4;

    if (options.port != null) {
      return HttpServer.bind(bindAddress, options.port!);
    }

    if (options.portRange != null) {
      final range = options.portRange!;
      for (var port = range.start; port <= range.end; port++) {
        try {
          return await HttpServer.bind(bindAddress, port);
        } on SocketException {
          continue;
        }
      }
      throw SocketException(
        'No available port in range ${range.start}-${range.end}',
      );
    }

    return HttpServer.bind(bindAddress, 0);
  }

  Future<void> _cleanup() async {
    await _server?.close(force: true);
    _server = null;
    _completer = null;
  }

  /// Launches a URL using platform-specific APIs.
  ///
  /// - Linux: Uses `xdg-open`
  /// - macOS: Uses `open` (fallback; normally handled by redirect_darwin)
  /// - Windows: Uses Win32 `ShellExecuteW` via FFI (same as url_launcher)
  Future<bool> _launchUrl(Uri url) async {
    final urlString = url.toString();

    try {
      if (Platform.isLinux) {
        final result = await Process.run('xdg-open', [urlString]);
        if (result.exitCode != 0) {
          debugPrint('Failed to launch URL: ${result.stderr}');
          return false;
        }
        return true;
      } else if (Platform.isMacOS) {
        final result = await Process.run('open', [urlString]);
        if (result.exitCode != 0) {
          debugPrint('Failed to launch URL: ${result.stderr}');
          return false;
        }
        return true;
      } else if (Platform.isWindows) {
        return _shellExecuteUrl(urlString);
      } else {
        return false;
      }
    } on Object catch (e) {
      debugPrint('Error launching URL: $e');
      return false;
    }
  }

  /// Launches a URL on Windows using the Win32 ShellExecuteW API.
  ///
  /// This avoids cmd.exe entirely, so URLs with `&`, `^`, `%` etc. are
  /// handled correctly — exactly as url_launcher_windows does it.
  static bool _shellExecuteUrl(String url) {
    // shell32.dll ShellExecuteW signature:
    //   HINSTANCE ShellExecuteW(
    //     HWND    hwnd,
    //     LPCWSTR lpOperation,
    //     LPCWSTR lpFile,
    //     LPCWSTR lpParameters,
    //     LPCWSTR lpDirectory,
    //     INT     nShowCmd,
    //   );
    final shell32 = DynamicLibrary.open('shell32.dll');
    final shellExecuteW = shell32
        .lookupFunction<
          IntPtr Function(
            IntPtr hwnd,
            Pointer<Utf16> lpOperation,
            Pointer<Utf16> lpFile,
            Pointer<Utf16> lpParameters,
            Pointer<Utf16> lpDirectory,
            Int32 nShowCmd,
          ),
          int Function(
            int hwnd,
            Pointer<Utf16> lpOperation,
            Pointer<Utf16> lpFile,
            Pointer<Utf16> lpParameters,
            Pointer<Utf16> lpDirectory,
            int nShowCmd,
          )
        >('ShellExecuteW');

    const swShowNormal = 1;

    final operation = 'open'.toNativeUtf16();
    final file = url.toNativeUtf16();
    try {
      // Return value > 32 indicates success per Win32 docs.
      final result = shellExecuteW(
        0, // hwnd - no parent window
        operation,
        file,
        nullptr, // no parameters
        nullptr, // no directory
        swShowNormal,
      );
      return result > 32;
    } finally {
      calloc
        ..free(operation)
        ..free(file);
    }
  }

  static const _successHtml = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Authentication Complete</title>
  <style>
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto,
        sans-serif;
      display: flex;
      justify-content: center;
      align-items: center;
      height: 100vh;
      margin: 0;
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      color: white;
    }
    .container {
      text-align: center;
      padding: 2rem;
    }
    h1 { font-size: 2rem; margin-bottom: 1rem; }
    p { opacity: 0.9; }
  </style>
</head>
<body>
  <div class="container">
    <h1>✓ Authentication Complete</h1>
    <p>You can close this window and return to the application.</p>
  </div>
</body>
</html>
''';
}
