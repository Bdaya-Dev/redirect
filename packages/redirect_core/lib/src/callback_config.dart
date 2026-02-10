import 'package:meta/meta.dart';

/// Describes how the platform should match callback URLs.
///
/// Mirrors Apple's `ASWebAuthenticationSession.Callback` (iOS 17.4+),
/// providing both custom-scheme and HTTPS (Universal/App Links) matching.
///
/// Used by Darwin platform options. Other platforms use their own
/// callback matching mechanisms (e.g., Android uses manifest intent
/// filters; web/IO use a `callbackValidator` function).
///
/// ```dart
/// // Custom scheme: matches myapp://...
/// const callback = CallbackConfig.customScheme('myapp');
///
/// // HTTPS: matches https://auth.example.com/callback
/// const callback = CallbackConfig.https(
///   host: 'auth.example.com',
///   path: '/callback',
/// );
/// ```
@immutable
sealed class CallbackConfig {
  const CallbackConfig();

  /// Matches URLs with the given custom scheme.
  ///
  /// Example: `CallbackConfig.customScheme('myapp')` matches `myapp://...`
  const factory CallbackConfig.customScheme(String scheme) =
      CustomSchemeCallbackConfig;

  /// Matches HTTPS URLs with the given host and path.
  ///
  /// Example:
  /// ```dart
  /// CallbackConfig.https(
  ///   host: 'auth.example.com',
  ///   path: '/callback',
  /// )
  /// ```
  /// matches `https://auth.example.com/callback?code=...`
  const factory CallbackConfig.https({
    required String host,
    required String path,
  }) = HttpsCallbackConfig;

  /// Whether the given [uri] matches this callback configuration.
  bool matchesUrl(Uri uri);
}

/// Matches URLs by custom scheme (e.g., `myapp://callback`).
@immutable
final class CustomSchemeCallbackConfig extends CallbackConfig {
  /// Creates a custom scheme callback config.
  const CustomSchemeCallbackConfig(this.scheme);

  /// The custom URL scheme to match.
  final String scheme;

  @override
  bool matchesUrl(Uri uri) => uri.scheme == scheme;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CustomSchemeCallbackConfig && scheme == other.scheme;

  @override
  int get hashCode => scheme.hashCode;

  @override
  String toString() => 'CallbackConfig.customScheme($scheme)';
}

/// Matches HTTPS URLs by host and path.
@immutable
final class HttpsCallbackConfig extends CallbackConfig {
  /// Creates an HTTPS callback config.
  const HttpsCallbackConfig({required this.host, required this.path});

  /// The host to match (e.g., `auth.example.com`).
  final String host;

  /// The path to match (e.g., `/callback`).
  final String path;

  @override
  bool matchesUrl(Uri uri) =>
      uri.scheme == 'https' && uri.host == host && uri.path == path;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HttpsCallbackConfig && host == other.host && path == other.path;

  @override
  int get hashCode => Object.hash(host, path);

  @override
  String toString() => 'CallbackConfig.https(host: $host, path: $path)';
}
