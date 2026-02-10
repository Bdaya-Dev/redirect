import 'package:meta/meta.dart';
import 'package:redirect_core/redirect_core.dart';

/// Base options shared by Darwin (iOS/macOS) redirect implementations.
///
/// Uses `ASWebAuthenticationSession` under the hood.
///
/// Subclasses: `IosRedirectOptions`, `MacosRedirectOptions`.
@immutable
class DarwinRedirectOptions {
  /// Creates Darwin redirect options.
  const DarwinRedirectOptions({
    required this.callback,
    this.additionalHeaderFields,
  });

  /// How the platform should match callback URLs.
  ///
  /// Maps directly to `ASWebAuthenticationSession.Callback`:
  /// - [CallbackConfig.customScheme] → `.customScheme(scheme)`
  /// - [CallbackConfig.https] → `.https(host:path:)`
  ///
  /// Example:
  /// ```dart
  /// DarwinRedirectOptions(
  ///   callback: CallbackConfig.customScheme('myapp'),
  /// )
  /// ```
  final CallbackConfig callback;

  /// Additional HTTP header fields to set when loading the initial URL.
  ///
  /// Maps to `ASWebAuthenticationSession.additionalHeaderFields`.
  ///
  /// Requires iOS 17.4+ / macOS 14.4+. Ignored on older OS versions.
  final Map<String, String>? additionalHeaderFields;
}
