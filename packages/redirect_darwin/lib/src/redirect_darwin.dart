import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:redirect_darwin/src/messages.g.dart';
import 'package:redirect_platform_interface/redirect_platform_interface.dart';

/// The Darwin (iOS/macOS) implementation of [RedirectPlatform].
///
/// Uses ASWebAuthenticationSession for secure redirect flows on Apple
/// platforms.
/// This class communicates with the native Swift code via Pigeon-generated
/// type-safe platform channels.
class RedirectDarwinPlugin extends RedirectPlatform {
  /// Creates a new [RedirectDarwinPlugin] instance.
  ///
  /// The [api] parameter is exposed for testing only.
  RedirectDarwinPlugin({@visibleForTesting RedirectHostApi? api})
    : _api = api ?? RedirectHostApi();

  final RedirectHostApi _api;

  /// Registers this class as the default instance of [RedirectPlatform].
  static void registerWith() {
    RedirectPlatform.instance = RedirectDarwinPlugin();
  }

  @override
  RedirectHandle run({
    required Uri url,
    required String callbackUrlScheme,
    RedirectOptions options = const RedirectOptions(),
  }) {
    Future<RedirectResult> doRun() async {
      try {
        final darwinOptions = DarwinRedirectOptions.fromOptions(options);
        final result = await _api.run(
          RunRequest(
            url: url.toString(),
            callbackUrlScheme: callbackUrlScheme,
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
      callbackUrlScheme: callbackUrlScheme,
      options: options,
      result: doRun(),
      cancel: _api.cancel,
    );
  }
}
