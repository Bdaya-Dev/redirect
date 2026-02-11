import 'dart:async';

import 'package:meta/meta.dart';
import 'package:redirect_core/src/http_callback_response.dart';

/// Base options shared by redirect implementations that use a loopback
/// HTTP server and the system browser (IO, Desktop).
///
/// Subclasses can add platform-specific fields while inheriting the common
/// server configuration.
@immutable
class ServerRedirectOptions {
  /// Creates server redirect options.
  const ServerRedirectOptions({
    this.callbackUrl,
    this.callbackValidator,
    this.httpResponseBuilder,
    this.openBrowser = true,
    this.portCompleter,
    this.urlBuilder,
  });

  /// The loopback callback URL for the local HTTP server.
  ///
  /// Components used:
  /// - **host** — hostname for the redirect URI and server bind address.
  ///   Defaults to `localhost`.
  /// - **port** — port to bind. Use `0` (the default) to auto-select an
  ///   available port.
  /// - **path** — callback path to listen on. Defaults to `/callback`.
  ///
  /// If null, defaults to `http://localhost:0/callback` (auto-selected port).
  final Uri? callbackUrl;

  /// Validates whether an incoming request URI is the expected callback.
  ///
  /// Called for every request received on the loopback server. Return `true`
  /// to accept the request as the callback (completing the redirect flow),
  /// or `false` to ignore it.
  ///
  /// If null, the default validation accepts any request whose path matches
  /// the callback path derived from [callbackUrl] (or `/callback` by
  /// default).
  ///
  /// Supports both synchronous and asynchronous validation via [FutureOr].
  ///
  /// Example:
  /// ```dart
  /// ServerRedirectOptions(
  ///   callbackValidator: (uri) =>
  ///       uri.path == '/callback' && uri.queryParameters.containsKey('code'),
  /// )
  /// ```
  final CallbackValidator? callbackValidator;

  /// Builds the HTTP response sent to the browser after the callback is
  /// received on the loopback server.
  ///
  /// The builder receives the full request [Uri] so it can inspect query
  /// parameters, path, fragment, etc. and return an appropriate
  /// [HttpCallbackResponse] (status code, body, headers).
  ///
  /// If null, a default "redirect complete" HTML page is shown.
  ///
  /// Example:
  /// ```dart
  /// ServerRedirectOptions(
  ///   httpResponseBuilder: (request) {
  ///     return HttpCallbackResponse(
  ///       statusCode: 200,
  ///       body: '<h1>Done — you can close this tab.</h1>',
  ///     );
  ///   },
  /// )
  /// ```
  final HttpResponseBuilder? httpResponseBuilder;

  /// Whether to automatically open the system browser.
  ///
  /// Set to `false` if you want to handle browser launching yourself
  /// (e.g., display the URL for the user to copy manually).
  ///
  /// Defaults to `true`.
  final bool openBrowser;

  /// A [Completer] that will be completed with the actual port the loopback
  /// server bound to.
  ///
  /// This is useful when using port `0` (auto-select) and you need to know
  /// the actual port to construct URLs yourself. For example, to add a
  /// `redirect_uri` parameter to the target URL.
  ///
  /// The completer is completed after the server starts listening, before
  /// the browser is launched. If the server fails to bind, the completer
  /// is completed with an error.
  ///
  /// If null, the port is not reported.
  ///
  /// Example:
  /// ```dart
  /// final portCompleter = Completer<int>();
  /// final handle = redirect.run(
  ///   url: baseAuthUrl, // URL without redirect_uri
  ///   options: RedirectOptions(
  ///     platformOptions: {
  ///       IoRedirectOptions.key: IoRedirectOptions(
  ///         portCompleter: portCompleter,
  ///         openBrowser: false, // we'll open it ourselves
  ///       ),
  ///     },
  ///   ),
  /// );
  ///
  /// final port = await portCompleter.future;
  /// // Now construct the full URL with redirect_uri and open browser.
  /// ```
  final Completer<int>? portCompleter;

  /// Builds the final URL to open in the browser, given the actual port
  /// the loopback server bound to.
  ///
  /// This is the recommended way to construct protocol-specific URLs
  /// (e.g., URLs with a `redirect_uri` parameter)
  /// without coupling the redirect package to any particular protocol.
  ///
  /// The builder receives the actual port and should return the complete
  /// URL to navigate to. If null, the original `url` passed to
  /// `RedirectHandler.run` is used as-is.
  ///
  /// Example:
  /// ```dart
  /// ServerRedirectOptions(
  ///   urlBuilder: (port) => Uri.parse(
  ///     'https://auth.example.com/authorize'
  ///     '?client_id=my_client'
  ///     '&redirect_uri=http://localhost:$port/callback',
  ///   ),
  /// )
  /// ```
  final UrlBuilder? urlBuilder;
}

/// Builds the URL to open in the browser from the actual loopback server port.
///
/// See [ServerRedirectOptions.urlBuilder].
typedef UrlBuilder = Uri Function(int port);

/// Validates whether an incoming request URI is the expected callback.
///
/// See [ServerRedirectOptions.callbackValidator].
typedef CallbackValidator = FutureOr<bool> Function(Uri uri);
