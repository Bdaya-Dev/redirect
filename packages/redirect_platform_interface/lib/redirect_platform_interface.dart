import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:redirect_core/redirect_core.dart';

export 'package:redirect_core/redirect_core.dart';
export 'src/android_redirect_options.dart';
export 'src/darwin_redirect_options.dart';
export 'src/ios_redirect_options.dart';
export 'src/linux_redirect_options.dart';
export 'src/macos_redirect_options.dart';
export 'src/windows_redirect_options.dart';

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

  static RedirectPlatform? _instance;

  /// The default instance of [RedirectPlatform] to use.
  ///
  /// Platform-specific packages register their implementations at startup,
  /// replacing this value.
  ///
  /// Throws [StateError] if no platform implementation has been registered.
  static RedirectPlatform get instance {
    final instance = _instance;
    if (instance == null) {
      throw StateError(
        'No RedirectPlatform implementation has been registered. '
        'Ensure a platform package (redirect_android, redirect_darwin, '
        'redirect_desktop, or redirect_web) is included in your '
        'dependencies.',
      );
    }
    return instance;
  }

  /// Platform-specific plugins should set this with their own platform-specific
  /// class that extends [RedirectPlatform] when they register themselves.
  static set instance(RedirectPlatform instance) {
    PlatformInterface.verify(instance, _token);
    _instance = instance;
  }

  @override
  RedirectHandle run({
    required Uri url,
    RedirectOptions options = const RedirectOptions(),
  }) {
    throw UnimplementedError('run() has not been implemented.');
  }
}
