import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/messages.g.dart',
    kotlinOut: 'android/src/main/kotlin/com/bdayadev/Messages.g.kt',
    kotlinOptions: KotlinOptions(package: 'com.bdayadev'),
    dartPackageName: 'redirect_android',
  ),
)
/// Options for Android Custom Tabs.
class AndroidOptions {
  AndroidOptions({
    required this.useCustomTabs,
    required this.showTitle,
    required this.enableUrlBarHiding,
    this.toolbarColor,
    this.secondaryToolbarColor,
  });

  final bool useCustomTabs;
  final bool showTitle;
  final bool enableUrlBarHiding;
  final int? toolbarColor;
  final int? secondaryToolbarColor;
}

/// Request to start a redirect-based authentication flow.
class RunRequest {
  RunRequest({
    required this.nonce,
    required this.url,
    required this.callbackUrlScheme,
    required this.preferEphemeral,
    required this.androidOptions,
    this.timeoutMillis,
  });

  /// Unique identifier for this redirect operation.
  ///
  /// Used to correlate the request with its callback, enabling
  /// multiple concurrent redirect flows.
  final String nonce;
  final String url;
  final String callbackUrlScheme;
  final bool preferEphemeral;
  final int? timeoutMillis;
  final AndroidOptions androidOptions;
}

/// Host API for redirect operations on Android.
@HostApi()
abstract class RedirectHostApi {
  /// Starts a redirect flow and returns the callback URL, or null if cancelled.
  @async
  String? run(RunRequest request);

  /// Cancels the redirect flow identified by [nonce].
  ///
  /// If [nonce] is empty, cancels all pending operations.
  void cancel(String nonce);

  /// Returns true if a browser that supports Custom Tabs is available.
  bool supportsCustomTabs();
}
