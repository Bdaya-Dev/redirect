// redirect_callback.js — BroadcastChannel fallback for COOP-resilient callbacks.
//
// In the DEFAULT case, you do NOT need this script. The opener reads the
// callback URL directly from the popup/tab via the Same-Origin Policy.
//
// This script is ONLY needed when the external provider (auth server,
// payment gateway, etc.) sets a Cross-Origin-Opener-Policy (COOP) header
// that severs the opener ↔ popup relationship. In that case the opener
// can no longer read the popup's location, and this script bridges the
// gap via BroadcastChannel + localStorage.
//
// Usage (on your callback page, only if needed):
//
//   <script src="redirect_callback.js"></script>
//
// Alternatively, register the Service Worker for a fully zero-file
// approach that handles COOP automatically:
//
//   RedirectWeb.registerServiceWorker();

(function () {
  'use strict';

  var STORAGE_PREFIX = 'redirect_channels_';
  var callbackUrl = window.location.href;
  var scheme = window.location.protocol.replace(':', '');

  // --- BroadcastChannel discovery from localStorage ---

  var storageKey = STORAGE_PREFIX + scheme;
  var channels = [];
  try {
    var raw = localStorage.getItem(storageKey);
    if (raw) channels = JSON.parse(raw);
  } catch (_) {
    // Ignore parse errors or SecurityError (e.g. opaque origin)
  }

  // Broadcast to every registered channel for this scheme.
  for (var i = 0; i < channels.length; i++) {
    try {
      var ch = new BroadcastChannel(channels[i]);
      ch.postMessage(callbackUrl);
      ch.close();
    } catch (_) {
      // BroadcastChannel may not be supported in very old browsers
    }
  }

  // --- Fallback: postMessage to opener ---

  if (window.opener) {
    try {
      window.opener.postMessage(
        { type: 'redirect_callback', url: callbackUrl },
        '*'
      );
    } catch (_) {
      // Cross-origin or opener already closed
    }
  }

  // --- Auto-close after a short delay ---

  setTimeout(function () {
    window.close();
  }, 1500);
})();
