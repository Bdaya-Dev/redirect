import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/messages.g.dart',
    swiftOut: 'darwin/redirect_darwin/Sources/redirect_darwin/Messages.g.swift',
    swiftOptions: SwiftOptions(),
    dartPackageName: 'redirect_darwin',
  ),
)

/// The type of callback URL matching to use.
enum CallbackType {
  /// Match by custom URL scheme (e.g., `myapp://...`).
  customScheme,

  /// Match by HTTPS host and path (Universal Links).
  https,
}

/// Configuration for how to match callback URLs.
class CallbackConfigMessage {
  CallbackConfigMessage({
    required this.type,
    this.scheme,
    this.host,
    this.path,
  });

  /// The type of callback matching.
  final CallbackType type;

  /// The custom URL scheme (for [CallbackType.customScheme]).
  final String? scheme;

  /// The HTTPS host (for [CallbackType.https]).
  final String? host;

  /// The HTTPS path (for [CallbackType.https]).
  final String? path;
}

/// Request to start a redirect-based authentication flow.
class RunRequest {
  RunRequest({
    required this.nonce,
    required this.url,
    required this.callback,
    required this.preferEphemeral,
    this.timeoutMillis,
    this.additionalHeaderFields,
  });

  /// Unique identifier for this redirect operation.
  ///
  /// Used to correlate the request with its callback, enabling
  /// multiple concurrent redirect flows.
  final String nonce;
  final String url;
  final CallbackConfigMessage callback;
  final bool preferEphemeral;
  final int? timeoutMillis;

  /// Additional HTTP headers to set on the initial URL load.
  ///
  /// Maps to `ASWebAuthenticationSession.additionalHeaderFields`.
  /// Requires iOS 17.4+ / macOS 14.4+. Ignored on older OS versions.
  final Map<String?, String?>? additionalHeaderFields;
}

/// Host API for redirect operations on Darwin (iOS/macOS).
@HostApi()
abstract class RedirectHostApi {
  /// Starts a redirect flow and returns the callback URL, or null if cancelled.
  @async
  String? run(RunRequest request);

  /// Cancels the redirect flow identified by [nonce].
  ///
  /// If [nonce] is empty, cancels all pending operations.
  void cancel(String nonce);
}
