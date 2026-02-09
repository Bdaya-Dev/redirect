import 'package:meta/meta.dart';

/// Configuration options for a redirect operation.
@immutable
class RedirectOptions {
  /// Creates redirect options.
  const RedirectOptions({
    this.timeout,
    this.preferEphemeral = false,
    this.platformOptions = const {},
  });

  /// Maximum duration to wait for the callback.
  ///
  /// If null, no timeout is applied and the operation waits indefinitely
  /// (or until cancelled/dismissed by the user).
  final Duration? timeout;

  /// Whether to prefer a private/ephemeral browser session.
  ///
  /// When true, the browser session won't share cookies or other browsing
  /// data with the user's normal browsing session.
  ///
  /// Platform behavior:
  /// - **iOS/macOS**: Sets `prefersEphemeralWebBrowserSession` to true on
  ///   `ASWebAuthenticationSession`
  /// - **Android**: Uses incognito-like mode in Custom Tabs if supported
  /// - **Web**: May open in a private window if browser supports it
  /// - **Desktop**: Always uses system browser (inherently ephemeral per
  ///   redirect since there's no session sharing)
  ///
  /// Defaults to `false` to allow SSO and session reuse.
  final bool preferEphemeral;

  /// Platform-specific options keyed by platform identifier.
  ///
  /// This allows platform implementations to receive configuration
  /// through the standard [RedirectOptions] without requiring
  /// direct dependencies on platform packages.
  ///
  /// Platform packages define their own option types and keys:
  /// - **Web**: `WebRedirectOptions` via `WebRedirectOptions.key`
  /// - **CLI**: `CliRedirectOptions` via `CliRedirectOptions.key`
  ///
  /// Example:
  /// ```dart
  /// import 'package:redirect_web_core/redirect_web_core.dart';
  ///
  /// runRedirect(
  ///   url: authUrl,
  ///   callbackUrlScheme: 'myapp',
  ///   options: RedirectOptions(
  ///     platformOptions: {
  ///       WebRedirectOptions.key: WebRedirectOptions(
  ///         mode: WebRedirectMode.newTab,
  ///       ),
  ///     },
  ///   ),
  /// );
  /// ```
  final Map<String, Object> platformOptions;

  /// Retrieves a platform-specific option by key and type.
  ///
  /// Returns null if the key is not present or the value is not of type [T].
  T? getPlatformOption<T>(String key) {
    final value = platformOptions[key];
    return value is T ? value : null;
  }

  /// Creates a copy of this options with the given fields replaced.
  RedirectOptions copyWith({
    Duration? timeout,
    bool? preferEphemeral,
    Map<String, Object>? platformOptions,
  }) {
    return RedirectOptions(
      timeout: timeout ?? this.timeout,
      preferEphemeral: preferEphemeral ?? this.preferEphemeral,
      platformOptions: platformOptions ?? this.platformOptions,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RedirectOptions &&
          runtimeType == other.runtimeType &&
          timeout == other.timeout &&
          preferEphemeral == other.preferEphemeral;

  @override
  int get hashCode => Object.hash(timeout, preferEphemeral);

  @override
  String toString() =>
      'RedirectOptions(timeout: $timeout, preferEphemeral: $preferEphemeral)';
}
