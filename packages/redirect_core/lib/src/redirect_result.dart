import 'package:meta/meta.dart';

/// The result of a redirect operation.
///
/// Use pattern matching to handle all possible outcomes:
/// ```dart
/// switch (result) {
///   case RedirectSuccess(:final uri):
///     print('Received callback: $uri');
///   case RedirectCancelled():
///     print('User cancelled');
///   case RedirectPending():
///     print('Result will arrive later (e.g., same-page redirect)');
///   case RedirectFailure(:final error):
///     print('Failed: $error');
/// }
/// ```
///
/// Every subtype carries an optional [metadata] map for arbitrary
/// key-value data that platform implementations or callers can attach:
///
/// ```dart
/// RedirectSuccess(uri: uri, metadata: {'provider': 'google', 'latencyMs': 230});
/// ```
@immutable
sealed class RedirectResult {
  const RedirectResult({this.metadata = const {}});

  /// Arbitrary key-value pairs attached to this result.
  ///
  /// Platform implementations can use this to surface extra information
  /// (e.g., timing data, provider identifiers) without requiring new
  /// subtypes.
  final Map<String, dynamic> metadata;
}

/// Redirect completed successfully with the callback URI.
@immutable
final class RedirectSuccess extends RedirectResult {
  /// Creates a successful redirect result.
  const RedirectSuccess({required this.uri, super.metadata});

  /// The full callback URI that was intercepted.
  final Uri uri;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RedirectSuccess &&
          runtimeType == other.runtimeType &&
          uri == other.uri &&
          _mapEquals(metadata, other.metadata);

  @override
  int get hashCode => Object.hash(uri, Object.hashAll(metadata.entries));

  @override
  String toString() => 'RedirectSuccess($uri)';
}

/// User dismissed or cancelled the redirect flow.
@immutable
final class RedirectCancelled extends RedirectResult {
  /// Creates a cancelled redirect result.
  const RedirectCancelled({super.metadata});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RedirectCancelled &&
          runtimeType == other.runtimeType &&
          _mapEquals(metadata, other.metadata);

  @override
  int get hashCode =>
      Object.hash(runtimeType, Object.hashAll(metadata.entries));

  @override
  String toString() => 'RedirectCancelled()';
}

/// The redirect was initiated but the result will arrive later.
///
/// This is returned when using redirect modes that navigate away from the
/// current context, such as same-page redirects on web. The actual result
/// must be retrieved when the callback URL is loaded.
///
/// On web with same-page mode:
/// 1. Store any necessary state before calling `run()`
/// 2. When the app reloads at the callback URL, call
///    `RedirectWeb.resumePendingRedirect()` to get the [RedirectResult]
@immutable
final class RedirectPending extends RedirectResult {
  /// Creates a pending redirect result.
  const RedirectPending({super.metadata});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RedirectPending &&
          runtimeType == other.runtimeType &&
          _mapEquals(metadata, other.metadata);

  @override
  int get hashCode =>
      Object.hash(runtimeType, Object.hashAll(metadata.entries));

  @override
  String toString() => 'RedirectPending()';
}

/// Redirect operation failed with an error.
@immutable
final class RedirectFailure extends RedirectResult {
  /// Creates a failed redirect result.
  const RedirectFailure({
    required this.error,
    this.stackTrace,
    super.metadata,
  });

  /// The error that caused the failure.
  final Object error;

  /// Optional stack trace associated with the error.
  final StackTrace? stackTrace;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RedirectFailure &&
          runtimeType == other.runtimeType &&
          error == other.error &&
          _mapEquals(metadata, other.metadata);

  @override
  int get hashCode => Object.hash(error, Object.hashAll(metadata.entries));

  @override
  String toString() => 'RedirectFailure($error)';
}

/// Shallow equality check for two maps.
bool _mapEquals(Map<String, dynamic> a, Map<String, dynamic> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (final key in a.keys) {
    if (!b.containsKey(key) || a[key] != b[key]) return false;
  }
  return true;
}
