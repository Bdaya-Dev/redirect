import 'dart:async';

import 'package:meta/meta.dart';
import 'package:redirect_core/redirect_core.dart';

/// IO-specific options for redirect-based flows using a loopback HTTP server.
///
/// Pass via [RedirectOptions.platformOptions] using [key]:
///
/// ```dart
/// redirect.run(
///   url: authUrl,
///   options: RedirectOptions(
///     platformOptions: {
///       IoRedirectOptions.key: IoRedirectOptions(
///         callbackUrl: Uri.parse('http://localhost:8080/callback'),
///         openBrowser: false,
///       ),
///     },
///   ),
/// );
/// ```
@immutable
class IoRedirectOptions extends ServerRedirectOptions {
  /// Creates IO redirect options.
  const IoRedirectOptions({
    super.callbackUrl,
    super.callbackValidator,
    super.httpResponseBuilder,
    super.openBrowser,
    super.portCompleter,
    super.urlBuilder,
  });

  /// The key used in [RedirectOptions.platformOptions].
  static const String key = 'io';

  /// Extracts [IoRedirectOptions] from [RedirectOptions.platformOptions].
  ///
  /// Returns [fallback] if no IO options are set (defaults to
  /// `const IoRedirectOptions()`).
  static IoRedirectOptions fromOptions(
    RedirectOptions options, [
    IoRedirectOptions fallback = const IoRedirectOptions(),
  ]) {
    return options.getPlatformOption<IoRedirectOptions>(key) ?? fallback;
  }

  /// Creates a copy with the given fields replaced.
  IoRedirectOptions copyWith({
    Uri? callbackUrl,
    CallbackValidator? callbackValidator,
    HttpResponseBuilder? httpResponseBuilder,
    bool? openBrowser,
    Completer<int>? portCompleter,
    UrlBuilder? urlBuilder,
  }) {
    return IoRedirectOptions(
      callbackUrl: callbackUrl ?? this.callbackUrl,
      callbackValidator: callbackValidator ?? this.callbackValidator,
      httpResponseBuilder: httpResponseBuilder ?? this.httpResponseBuilder,
      openBrowser: openBrowser ?? this.openBrowser,
      portCompleter: portCompleter ?? this.portCompleter,
      urlBuilder: urlBuilder ?? this.urlBuilder,
    );
  }
}
