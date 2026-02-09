import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart';
import 'package:redirect_platform_interface/redirect_platform_interface.dart';

/// An implementation of [RedirectPlatform] that uses method channels.
class MethodChannelRedirect extends RedirectPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('redirect');

  @override
  RedirectHandle run({
    required Uri url,
    required String callbackUrlScheme,
    RedirectOptions options = const RedirectOptions(),
  }) {
    Future<RedirectResult> doRun() async {
      try {
        final result = await methodChannel.invokeMethod<String>(
          'run',
          <String, dynamic>{
            'url': url.toString(),
            'callbackUrlScheme': callbackUrlScheme,
            'preferEphemeral': options.preferEphemeral,
            if (options.timeout != null)
              'timeoutMillis': options.timeout!.inMilliseconds,
          },
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
      cancel: () => methodChannel.invokeMethod<void>('cancel'),
    );
  }
}
