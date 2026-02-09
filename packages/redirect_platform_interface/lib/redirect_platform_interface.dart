import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:redirect_core/redirect_core.dart';
import 'package:redirect_platform_interface/src/method_channel_redirect.dart';

export 'package:redirect_core/redirect_core.dart';

/// {@template redirect_platform}
/// The interface that implementations of redirect must implement.
///
/// Platform implementations should extend this class
/// rather than implement it as `RedirectHandler`.
///
/// Extending this class (using `extends`) ensures that the subclass will get
/// the default implementation, while platform implementations that `implements`
/// this interface will be broken by newly added [RedirectPlatform] methods.
/// {@endtemplate}
abstract class RedirectPlatform extends PlatformInterface
    implements RedirectHandler {
  /// {@macro redirect_platform}
  RedirectPlatform() : super(token: _token);

  static final Object _token = Object();

  static RedirectPlatform _instance = MethodChannelRedirect();

  /// The default instance of [RedirectPlatform] to use.
  ///
  /// Defaults to [MethodChannelRedirect].
  static RedirectPlatform get instance => _instance;

  /// Platform-specific plugins should set this with their own platform-specific
  /// class that extends [RedirectPlatform] when they register themselves.
  static set instance(RedirectPlatform instance) {
    PlatformInterface.verify(instance, _token);
    _instance = instance;
  }

  @override
  RedirectHandle run({
    required Uri url,
    required String callbackUrlScheme,
    RedirectOptions options = const RedirectOptions(),
  }) {
    throw UnimplementedError('run() has not been implemented.');
  }
}
