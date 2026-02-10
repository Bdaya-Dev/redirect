/// Core types and interfaces for redirect-based flows.
///
/// This package provides platform-agnostic types and interfaces for handling
/// redirect-based flows (e.g., authorization flows, payment gateway redirects).
///
/// It can be used with:
/// - Pure Dart CLI applications
/// - Pure Dart web applications
/// - Flutter applications (via the `redirect` package)
library;

export 'src/callback_config.dart';
export 'src/http_callback_response.dart';
export 'src/nonce.dart';
export 'src/redirect.dart';
export 'src/redirect_handle.dart';
export 'src/redirect_options.dart';
export 'src/redirect_result.dart';
export 'src/server_redirect_options.dart';
export 'src/web_redirect_mode.dart';
export 'src/web_redirect_options.dart';
