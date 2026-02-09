import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/messages.g.dart',
    swiftOut: 'darwin/redirect_darwin/Sources/redirect_darwin/Messages.g.swift',
    swiftOptions: SwiftOptions(),
    dartPackageName: 'redirect_darwin',
  ),
)
/// Request to start a redirect-based authentication flow.
class RunRequest {
  RunRequest({
    required this.url,
    required this.callbackUrlScheme,
    required this.preferEphemeral,
    this.timeoutMillis,
  });

  final String url;
  final String callbackUrlScheme;
  final bool preferEphemeral;
  final int? timeoutMillis;
}

/// Host API for redirect operations on Darwin (iOS/macOS).
@HostApi()
abstract class RedirectHostApi {
  /// Starts a redirect flow and returns the callback URL, or null if cancelled.
  @async
  String? run(RunRequest request);

  /// Cancels the current redirect flow.
  void cancel();
}
