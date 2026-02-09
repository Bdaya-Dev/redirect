import 'package:redirect_platform_interface/redirect_platform_interface.dart';
import 'package:redirect_web_core/redirect_web_core.dart' as core;

// Re-export web-specific types for convenience
export 'package:redirect_web_core/redirect_web_core.dart'
    show RedirectWeb, WebRedirectMode, WebRedirectOptions;

/// The Flutter web implementation of [RedirectPlatform].
///
/// This is a thin wrapper around [core.RedirectWeb] from `redirect_web_core`
/// that handles Flutter plugin registration.
///
/// For non-Flutter Dart web applications, use `redirect_web_core` directly.
class RedirectWebPlugin extends RedirectPlatform {
  /// Creates a new web redirect plugin.
  ///
  /// [defaultWebOptions] specifies the default web-specific options.
  RedirectWebPlugin({
    core.WebRedirectOptions defaultWebOptions =
        const core.WebRedirectOptions(),
  }) : _core = core.RedirectWeb(defaultWebOptions: defaultWebOptions);

  /// The underlying pure Dart web implementation.
  final core.RedirectWeb _core;

  /// Registers this class as the default instance of [RedirectPlatform].
  static void registerWith([Object? registrar]) {
    RedirectPlatform.instance = RedirectWebPlugin();
  }

  @override
  RedirectHandle run({
    required Uri url,
    required String callbackUrlScheme,
    RedirectOptions options = const RedirectOptions(),
  }) {
    return _core.run(
      url: url,
      callbackUrlScheme: callbackUrlScheme,
      options: options,
    );
  }
}
