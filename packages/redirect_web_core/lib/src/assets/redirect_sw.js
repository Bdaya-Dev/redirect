// redirect_sw.js — Service Worker for zero-config redirect callback handling.
//
// When registered, this Service Worker intercepts navigation requests to the
// configured callback path and broadcasts the full URL to all active redirect
// channels via BroadcastChannel — directly from the SW context.
//
// It does NOT serve a synthetic page. The actual navigation proceeds normally
// (the consumer's own callback page loads, or if none exists the popup gets
// closed by the opener before the 404 is visible).
//
// Channel names are sent to the SW via postMessage from the Dart side.
// If the SW restarts and loses its in-memory set, the poller and/or
// callback-page script fallbacks still work.
//
// Registration (from Dart):
//
//   RedirectWeb.registerServiceWorker();
//
// Or from JS:
//
//   navigator.serviceWorker.register('redirect_sw.js');

var callbackPath = '/callback';
var channels = new Set();

// --- Configuration and channel registration via postMessage ---

self.addEventListener('message', function (event) {
  var data = event.data;
  if (!data || !data.type) return;

  switch (data.type) {
    case 'redirect_config':
      if (data.callbackPath) callbackPath = data.callbackPath;
      break;
    case 'redirect_register':
      if (data.channel) channels.add(data.channel);
      break;
    case 'redirect_unregister':
      if (data.channel) channels.delete(data.channel);
      break;
  }
});

// --- Install: activate immediately, don't wait for open tabs ---

self.addEventListener('install', function () {
  self.skipWaiting();
});

self.addEventListener('activate', function (event) {
  event.waitUntil(self.clients.claim());
});

// --- Intercept navigation requests to the callback path ---

self.addEventListener('fetch', function (event) {
  var url = new URL(event.request.url);

  // Only act on same-origin navigation requests to the callback path.
  if (
    event.request.mode !== 'navigate' ||
    url.origin !== self.location.origin ||
    url.pathname !== callbackPath
  ) {
    return;
  }

  // Broadcast the callback URL to every registered channel.
  // Each operation listens on its own unique channel, so only the
  // correct listener picks up the result.
  channels.forEach(function (name) {
    try {
      var ch = new BroadcastChannel(name);
      ch.postMessage(url.href);
      ch.close();
    } catch (_) {
      // BroadcastChannel not supported — fall through to poller
    }
  });

  // Do NOT call event.respondWith — let the navigation proceed normally.
  // The consumer's callback page (if any) loads as usual. If there is no
  // page, the popup will be closed by the opener before the user sees
  // the 404.
});
