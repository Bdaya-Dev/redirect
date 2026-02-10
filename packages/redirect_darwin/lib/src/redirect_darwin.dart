import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:redirect_darwin/src/messages.g.dart';
import 'package:redirect_platform_interface/redirect_platform_interface.dart';

/// Shared base for the iOS and macOS redirect plugin implementations.
///
/// Uses ASWebAuthenticationSession for secure redirect flows on Apple
/// platforms.
/// Communicates with the native Swift code via Pigeon-generated
/// type-safe platform channels.
abstract class RedirectDarwinBase extends RedirectPlatform {
  /// Creates a new Darwin redirect plugin.
  ///
  /// The [api] parameter is exposed for testing only.
  RedirectDarwinBase({@visibleForTesting RedirectHostApi? api})
    : _api = api ?? RedirectHostApi();

  final RedirectHostApi _api;

  /// Extracts [DarwinRedirectOptions] from the per-redirect [options].
  DarwinRedirectOptions getDarwinOptions(RedirectOptions options);

  @override
  RedirectHandle run({
    required Uri url,
    RedirectOptions options = const RedirectOptions(),
  }) {
    // Generate nonce for this redirect operation.
    final nonce = generateRedirectNonce();

    Future<RedirectResult> doRun() async {
      try {
        final darwinOptions = getDarwinOptions(options);
        final callbackConfig = darwinOptions.callback;

        final CallbackConfigMessage callbackMessage;
        switch (callbackConfig) {
          case CustomSchemeCallbackConfig(:final scheme):
            callbackMessage = CallbackConfigMessage(
              type: CallbackType.customScheme,
              scheme: scheme,
            );
          case HttpsCallbackConfig(:final host, :final path):
            callbackMessage = CallbackConfigMessage(
              type: CallbackType.https,
              host: host,
              path: path,
            );
        }

        final result = await _api.run(
          RunRequest(
            nonce: nonce,
            url: url.toString(),
            callback: callbackMessage,
            preferEphemeral: options.preferEphemeral,
            timeoutMillis: options.timeout?.inMilliseconds,
            additionalHeaderFields:
                darwinOptions.additionalHeaderFields,
          ),
        );

        if (result == null) {
          return const RedirectCancelled();
        }

        return RedirectSuccess(uri: Uri.parse(result));
      } on PlatformException catch (e, s) {
        if (e.code == 'CANCELLED') {
          return const RedirectCancelled();
        }
        return RedirectFailure(error: e, stackTrace: s);
      }
    }

    return RedirectHandle(
      url: url,
      nonce: nonce,
      options: options,
      result: doRun(),
      cancel: () => _api.cancel(nonce),
    );
  }
}

/// The iOS implementation of [RedirectPlatform].
///
/// Uses ASWebAuthenticationSession for secure redirect flows on iOS.
class RedirectIosPlugin extends RedirectDarwinBase {
  /// Creates a new [RedirectIosPlugin] instance.
  ///
  /// The [api] parameter is exposed for testing only.
  RedirectIosPlugin({@visibleForTesting super.api});

  /// Registers this class as the default instance of [RedirectPlatform].
  static void registerWith() {
    RedirectPlatform.instance = RedirectIosPlugin();
  }

  @override
  DarwinRedirectOptions getDarwinOptions(RedirectOptions options) {
    return IosRedirectOptions.fromOptions(options);
  }
}

/// The macOS implementation of [RedirectPlatform].
///
/// Uses ASWebAuthenticationSession for secure redirect flows on macOS.
class RedirectMacosPlugin extends RedirectDarwinBase {
  /// Creates a new [RedirectMacosPlugin] instance.
  ///
  /// The [api] parameter is exposed for testing only.
  RedirectMacosPlugin({@visibleForTesting super.api});

  /// Registers this class as the default instance of [RedirectPlatform].
  static void registerWith() {
    RedirectPlatform.instance = RedirectMacosPlugin();
  }

  @override
  DarwinRedirectOptions getDarwinOptions(RedirectOptions options) {
    return MacosRedirectOptions.fromOptions(options);
  }
}
