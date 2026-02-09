import 'dart:async';

import 'package:meta/meta.dart';
import 'package:redirect_core/src/redirect_options.dart';
import 'package:redirect_core/src/redirect_result.dart';

/// A handle to a pending redirect operation.
///
/// Returned synchronously by [RedirectHandler.run], allowing the redirect
/// to be initiated in the user-gesture call stack (important for avoiding
/// popup blockers on web) while the result is awaited separately.
///
/// Also exposes the original parameters passed to [RedirectHandler.run],
/// so callers can inspect or log them without keeping separate references.
///
/// ## Usage
///
/// ```dart
/// // This call is synchronous — on web, a popup/tab is pre-opened
/// // immediately in the user-gesture context.
/// final handle = redirect.run(
///   url: authUrl,
///   callbackUrlScheme: 'myapp',
/// );
///
/// // Original parameters are available on the handle.
/// print(handle.url);               // authUrl
/// print(handle.callbackUrlScheme); // 'myapp'
///
/// // Now safe to await — the browser window is already open.
/// final result = await handle.result;
///
/// // Or cancel the operation:
/// await handle.cancel();
/// ```
@immutable
class RedirectHandle {
  /// Creates a redirect handle.
  const RedirectHandle({
    required this.url,
    required this.callbackUrlScheme,
    this.options = const RedirectOptions(),
    required this.result,
    required this.cancel,
  });

  /// The URL that was opened for the redirect flow.
  final Uri url;

  /// The URL scheme being intercepted for the callback.
  final String callbackUrlScheme;

  /// The options that were passed to the redirect operation.
  final RedirectOptions options;

  /// A future that completes with the [RedirectResult] when the redirect
  /// flow finishes (success, cancellation, or failure).
  final Future<RedirectResult> result;

  /// Cancels the pending redirect operation.
  ///
  /// If the operation is still in progress, [result] will complete with
  /// [RedirectCancelled].
  ///
  /// This is a no-op if the operation has already completed.
  final Future<void> Function() cancel;
}
