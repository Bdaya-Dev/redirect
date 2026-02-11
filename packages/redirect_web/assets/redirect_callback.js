// redirect_callback.js — BroadcastChannel relay for redirect callbacks.
//
// Include this script on your callback page to relay the callback URL
// back to the opener via BroadcastChannel + localStorage.
//
// This script is needed when the external server sets a Cross-Origin-Opener-Policy (COOP) header
// that severs the opener ↔ popup relationship. In that case the opener
// can no longer read the popup's location, and this script bridges the
// gap via BroadcastChannel + localStorage.
//
// Usage (on your callback page):
//
//   <script src="redirect_callback.js"></script>

(function () {
  'use strict';

  var STORAGE_KEY = 'redirect_channels';
  var PENDING_KEY = 'redirect_pending';
  var CALLBACK_URL_KEY = 'redirect_callback_url';
  var callbackUrl = window.location.href;

  // --- BroadcastChannel discovery from localStorage ---

  var channels = [];
  try {
    var raw = localStorage.getItem(STORAGE_KEY);
    if (raw) channels = JSON.parse(raw);
  } catch (_) {
    // Ignore parse errors or SecurityError (e.g. opaque origin)
  }

  // Broadcast to every registered channel.
  for (var i = 0; i < channels.length; i++) {
    try {
      var ch = new BroadcastChannel(channels[i]);
      ch.postMessage(callbackUrl);
      ch.close();
    } catch (_) {
      // BroadcastChannel may not be supported in very old browsers
    }
  }

  // --- Store result for same-page redirect mode ---
  //
  // For popup/tab/iframe modes the BroadcastChannel message above is
  // the primary delivery mechanism. For same-page mode the opener IS
  // this tab, so there is no separate listener window. Instead we
  // persist the callback URL in sessionStorage and navigate back to
  // the app's origin. The app calls resumePendingRedirect() on reload
  // to read the result.
  //
  // This is harmless for popup/tab modes — the opener closes the
  // popup before the redirect below takes effect.
  try {
    sessionStorage.setItem(PENDING_KEY, 'true');
    sessionStorage.setItem(CALLBACK_URL_KEY, callbackUrl);
  } catch (_) {
    // sessionStorage may be unavailable (e.g. opaque origin)
  }

  // --- Navigate back to the app ---
  //
  // Redirect to the origin (app root) after a short delay so the
  // BroadcastChannel messages have time to dispatch. For popup/tab
  // modes the opener will close this window before the timeout fires.
  setTimeout(function () {
    try {
      // Navigate back to the app's origin URL (clean, no query params).
      window.location.href = window.location.origin + '/';
    } catch (_) {
      window.close();
    }
  }, 1500);
})();
