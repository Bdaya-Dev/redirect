import 'package:meta/meta.dart';

/// A snapshot of the incoming HTTP callback request.
///
/// Passed to [HttpResponseBuilder] so the builder can inspect the full
/// request (URI, method, headers) and decide what response to return.
@immutable
class HttpCallbackRequest {
  /// Creates an HTTP callback request snapshot.
  const HttpCallbackRequest({
    required this.uri,
    required this.method,
    this.headers = const {},
  });

  /// The full request URI including query parameters.
  final Uri uri;

  /// The HTTP method (e.g. `GET`, `POST`).
  final String method;

  /// The request headers.
  final Map<String, String> headers;
}

/// The response to send back to the browser after receiving a callback.
///
/// Used by [HttpResponseBuilder] to control what the user sees in the browser
/// after the redirect completes.
@immutable
class HttpCallbackResponse {
  /// Creates an HTTP callback response.
  const HttpCallbackResponse({
    this.statusCode = 200,
    this.body = '',
    this.headers = const {'content-type': 'text/html; charset=utf-8'},
  });

  /// Creates a 200 OK response with an HTML body.
  const HttpCallbackResponse.success({
    this.body = '',
    this.headers = const {'content-type': 'text/html; charset=utf-8'},
  }) : statusCode = 200;

  /// The HTTP status code.
  final int statusCode;

  /// The response body (typically HTML).
  final String body;

  /// Response headers.
  final Map<String, String> headers;
}

/// Builds the HTTP response to send to the browser after receiving a callback
/// on the loopback server.
///
/// Receives an [HttpCallbackRequest] containing the full request URI, HTTP
/// method, and headers so the caller can inspect whatever they need and
/// return an appropriate [HttpCallbackResponse]. This keeps the redirect
/// package protocol-agnostic.
///
/// Example:
/// ```dart
/// HttpResponseBuilder myBuilder = (request) {
///   return HttpCallbackResponse(
///     statusCode: 200,
///     body: '<h1>Done — you can close this tab.</h1>',
///   );
/// };
/// ```
typedef HttpResponseBuilder = HttpCallbackResponse Function(
  HttpCallbackRequest request,
);
