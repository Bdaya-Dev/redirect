import 'package:redirect_core/redirect_core.dart';
import 'package:redirect_web_core/redirect_web_core.dart';

/// Resumes a pending same-page redirect on web, if any.
RedirectResult? resumePending() {
  if (RedirectWeb.hasPendingRedirect()) {
    return RedirectWeb.resumePendingRedirect();
  }
  return null;
}
