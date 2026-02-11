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
    this.preferEphemeral = false,
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

  /// Whether to prefer a private/ephemeral browser session.
  ///
  /// When true, sets `prefersEphemeralWebBrowserSession` to true on
  /// `ASWebAuthenticationSession`, preventing cookie and session data
  /// from being shared with Safari.
  ///
  /// Defaults to `false` to allow SSO and session reuse.
  final bool preferEphemeral;

  /// Additional HTTP header fields to set when loading the initial URL.
  ///
  /// Maps to `ASWebAuthenticationSession.additionalHeaderFields`.
  ///
  /// Requires iOS 17.4+ / macOS 14.4+. Ignored on older OS versions.
  final Map<String, String>? additionalHeaderFields;
}
