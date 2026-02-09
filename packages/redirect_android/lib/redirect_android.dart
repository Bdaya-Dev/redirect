import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:redirect_android/src/android_redirect_options.dart';
import 'package:redirect_android/src/messages.g.dart';
import 'package:redirect_platform_interface/redirect_platform_interface.dart';

export 'src/android_redirect_options.dart';

/// The Android implementation of [RedirectPlatform].
///
/// Uses Chrome Custom Tabs for secure redirect flows on Android.
class RedirectAndroidPlugin extends RedirectPlatform {
  /// Creates a new [RedirectAndroidPlugin] instance.
  ///
  /// The [api] parameter is exposed for testing only.
  RedirectAndroidPlugin({@visibleForTesting RedirectHostApi? api})
    : _api = api ?? RedirectHostApi();

  final RedirectHostApi _api;

  /// Registers this class as the default instance of [RedirectPlatform].
  static void registerWith() {
    RedirectPlatform.instance = RedirectAndroidPlugin();
  }

  @override
  RedirectHandle run({
    required Uri url,
    required String callbackUrlScheme,
    RedirectOptions options = const RedirectOptions(),
  }) {
    Future<RedirectResult> doRun() async {
      try {
        final androidOptions = AndroidRedirectOptions.fromOptions(options);
        final preferEphemeral =
            androidOptions.preferEphemeral ?? options.preferEphemeral;

        final result = await _api.run(
          RunRequest(
            url: url.toString(),
            callbackUrlScheme: callbackUrlScheme,
            preferEphemeral: preferEphemeral,
            timeoutMillis: options.timeout?.inMilliseconds,
            androidOptions: AndroidOptions(
              useCustomTabs: androidOptions.useCustomTabs,
              showTitle: androidOptions.showTitle,
              enableUrlBarHiding: androidOptions.enableUrlBarHiding,
              toolbarColor: androidOptions.toolbarColor,
              secondaryToolbarColor: androidOptions.secondaryToolbarColor,
            ),
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
