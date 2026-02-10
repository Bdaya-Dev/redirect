import 'dart:async';

import 'package:meta/meta.dart';
import 'package:redirect_core/src/nonce.dart';
import 'package:redirect_core/src/redirect_options.dart';
import 'package:redirect_core/src/redirect_result.dart';

/// A handle to a pending redirect operation.
///
/// Returned synchronously by `RedirectHandler.run`, allowing the redirect
/// to be initiated in the user-gesture call stack (important for avoiding
/// popup blockers on web) while the result is awaited separately.
///
/// Each handle has a unique [nonce] that identifies the redirect operation
/// across Dart and native code, enabling multiple concurrent redirect flows.
///
/// Also exposes the original parameters passed to `RedirectHandler.run`,
/// so callers can inspect or log them without keeping separate references.
///
/// ## Usage
///
/// ```dart
/// // This call is synchronous — on web, a popup/tab is pre-opened
/// // immediately in the user-gesture context.
/// final handle = redirect.run(
///   url: authUrl,
/// );
///
/// // Each handle has a unique nonce (redirect request ID).
/// print(handle.nonce); // e.g. 'a3f8b2c1d4e5f6g7'
///
/// // Original parameters are available on the handle.
/// print(handle.url); // authUrl
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
  ///
  /// A unique [nonce] is generated automatically if not provided.
  /// The nonce serves as the redirect request ID, used to correlate
  /// the redirect operation across Dart and native code boundaries.
  RedirectHandle({
    required this.url,
    required this.result,
    required this.cancel,
    String? nonce,
    this.options = const RedirectOptions(),
  }) : nonce = nonce ?? generateRedirectNonce();

  /// A unique identifier for this redirect operation.
  ///
  /// This nonce is used across all platforms to correlate a redirect request
  /// with its callback. It enables multiple concurrent redirect flows by
  /// providing a stable identifier that can be passed to native code and
  /// used for channel naming on web.
  final String nonce;

  /// The URL that was opened for the redirect flow.
  final Uri url;

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
