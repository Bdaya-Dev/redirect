import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:redirect_core/redirect_core.dart';
import 'package:web/web.dart' as web;

/// Typed message sent to the Service Worker via `postMessage`.
///
/// Using an object literal constructor avoids the runtime overhead (and lack
/// of type safety) of `Map.jsify()`.  Each call produces a plain JS object
/// whose shape matches what `redirect_sw.js` expects.
extension type _ServiceWorkerMessage._(JSObject _) implements JSObject {
  external factory _ServiceWorkerMessage({
    required String type,
    String channel,
    String callbackPath,
  });
}

/// Pure Dart web implementation of [RedirectHandler].
///
/// Supports multiple redirect modes: popup, new tab, same-page, and iframe.
/// Works with any Dart web framework (Flutter, Jaspr, pure Dart, etc.).
///
/// ## Basic Usage (popup mode)
///
/// ```dart
/// final redirect = RedirectWeb();
/// final handle = redirect.run(
///   url: Uri.parse('https://auth.example.com/authorize'),
/// );
/// final result = await handle.result;
/// ```
///
/// ## Custom Web Options
///
/// Pass [WebRedirectOptions] per-call via [RedirectOptions.platformOptions]:
///
/// ```dart
/// final handle = redirect.run(
///   url: Uri.parse('https://auth.example.com/authorize'),
///   options: RedirectOptions(
///     platformOptions: {
///       WebRedirectOptions.key: WebRedirectOptions(
///         mode: WebRedirectMode.newTab,
///       ),
///     },
///   ),
/// );
/// final result = await handle.result;
/// ```
class RedirectWeb implements RedirectHandler {
  /// Creates a new web redirect handler.
  const RedirectWeb();

  @override
  RedirectHandle run({
    required Uri url,
    RedirectOptions options = const RedirectOptions(),
  }) {
    final webOptions = WebRedirectOptions.fromOptions(options);

    if (webOptions.autoRegisterServiceWorker) {
      unawaited(
        RedirectWeb.registerServiceWorker(
          callbackPath: webOptions.callbackPath ?? '/callback',
        ),
      );
    }

    return switch (webOptions.mode) {
      WebRedirectMode.popup => _runPopup(
        url: url,
        options: options,
        webOptions: webOptions,
      ),
      WebRedirectMode.newTab => _runNewTab(
        url: url,
        options: options,
        webOptions: webOptions,
      ),
      WebRedirectMode.samePage => _runSamePage(
        url: url,
        options: options,
      ),
      WebRedirectMode.hiddenIframe => _runIframe(
        url: url,
        options: options,
        webOptions: webOptions,
      ),
    };
  }

  RedirectHandle _runPopup({
    required Uri url,
    required RedirectOptions options,
    required WebRedirectOptions webOptions,
  }) {
    final completer = Completer<RedirectResult>();
    web.Window? popup;
    web.BroadcastChannel? channel;

    // Generate nonce for this redirect operation.
    final nonce = generateRedirectNonce();

    // Each operation gets a unique channel name so concurrent redirects
    // don't interfere, regardless of the protocol being used.
    final channelName =
        webOptions.broadcastChannelName ??
        'redirect_$nonce';
    _registerChannel(channelName);

    void cleanup() {
      _removeCloseWatcher(channelName);
      channel?.close();
      channel = null;
      popup = null;
      _unregisterChannel(channelName);
    }

    void cancelSync() {
      if (!completer.isCompleted) {
        completer.complete(const RedirectCancelled());
      }
      popup?.close();
      cleanup();
    }

    channel = _createBroadcastChannel(
      channelName: channelName,
      callbackValidator: webOptions.callbackValidator,
      completer: completer,
      onSuccess: () {
        popup?.close();
        cleanup();
      },
    );

    // Calculate popup position
    final width = webOptions.popupWidth;
    final height = webOptions.popupHeight;
    final left =
        webOptions.popupLeft ?? ((web.window.screen.width - width) ~/ 2);
    final top =
        webOptions.popupTop ?? ((web.window.screen.height - height) ~/ 2);

    // Open popup window — this happens synchronously in the user-gesture
    // call stack, avoiding popup blockers.
    popup = web.window.open(
      url.toString(),
      'redirect_popup',
      'width=$width,height=$height,left=$left,top=$top,'
          'toolbar=no,menubar=no,scrollbars=yes,resizable=yes',
    );

    if (popup == null) {
      cleanup();
      completer.complete(
        RedirectFailure(
          error: Exception('Failed to open popup window. Check popup blocker.'),
          stackTrace: StackTrace.current,
        ),
      );
    } else {
      // Detect when the user closes the popup without completing auth.
      _watchForClose(
        watcherId: channelName,
        target: popup!,
        completer: completer,
        onClosed: cleanup,
      );
    }

    return RedirectHandle(
      url: url,
      nonce: nonce,
      options: options,
      result: _wrapWithTimeout(completer, options.timeout, cleanup),
      cancel: () async => cancelSync(),
    );
  }

  RedirectHandle _runNewTab({
    required Uri url,
    required RedirectOptions options,
    required WebRedirectOptions webOptions,
  }) {
    final completer = Completer<RedirectResult>();
    web.Window? popup;
    web.BroadcastChannel? channel;

    // Generate nonce for this redirect operation.
    final nonce = generateRedirectNonce();

    // Each operation gets a unique channel name so concurrent redirects
    // don't interfere, regardless of the protocol being used.
    final channelName =
        webOptions.broadcastChannelName ??
        'redirect_$nonce';
    _registerChannel(channelName);

    void cleanup() {
      _removeCloseWatcher(channelName);
      channel?.close();
      channel = null;
      popup = null;
      _unregisterChannel(channelName);
    }

    void cancelSync() {
      if (!completer.isCompleted) {
        completer.complete(const RedirectCancelled());
      }
      popup?.close();
      cleanup();
    }

    channel = _createBroadcastChannel(
      channelName: channelName,
      callbackValidator: webOptions.callbackValidator,
      completer: completer,
      onSuccess: () {
        popup?.close();
        cleanup();
      },
    );

    // Open new tab — synchronous, in the user-gesture call stack.
    popup = web.window.open(url.toString(), '_blank');

    if (popup == null) {
      cleanup();
      completer.complete(
        RedirectFailure(
          error: Exception('Failed to open new tab. Check popup blocker.'),
          stackTrace: StackTrace.current,
        ),
      );
    } else {
      // Detect when the user closes the tab without completing auth.
      _watchForClose(
        watcherId: channelName,
        target: popup!,
        completer: completer,
        onClosed: cleanup,
      );
    }

    return RedirectHandle(
      url: url,
      nonce: nonce,
      options: options,
      result: _wrapWithTimeout(completer, options.timeout, cleanup),
      cancel: () async => cancelSync(),
    );
  }

  RedirectHandle _runSamePage({
    required Uri url,
    required RedirectOptions options,
  }) {
    // Generate nonce for this redirect operation.
    final nonce = generateRedirectNonce();

    // Persist enough state for the reloaded app to resume.
    // sessionStorage survives same-origin navigations within a tab but
    // is not shared across tabs, which is exactly the right scope.
    web.window.sessionStorage.setItem(_pendingKey, 'true');

    // Navigate the current page
    web.window.location.href = url.toString();

    // Return pending since we're navigating away
    // The actual result must be retrieved via [resumePendingRedirect]
    // after the app reloads at the callback URL.
    return RedirectHandle(
      url: url,
      nonce: nonce,
      options: options,
      result: Future.value(const RedirectPending()),
      cancel: () async {},
    );
  }

  RedirectHandle _runIframe({
    required Uri url,
    required RedirectOptions options,
    required WebRedirectOptions webOptions,
  }) {
    final completer = Completer<RedirectResult>();
    web.BroadcastChannel? channel;
    web.HTMLIFrameElement? iframe;

    // Generate nonce for this redirect operation.
    final nonce = generateRedirectNonce();

    // Each operation gets a unique channel name so concurrent redirects
    // don't interfere, regardless of the protocol being used.
    final channelName =
        webOptions.broadcastChannelName ??
        'redirect_$nonce';
    _registerChannel(channelName);

    void cleanup() {
      channel?.close();
      channel = null;
      iframe?.remove();
      iframe = null;
      _unregisterChannel(channelName);
    }

    void cancelSync() {
      if (!completer.isCompleted) {
        completer.complete(const RedirectCancelled());
      }
      cleanup();
    }

    channel = _createBroadcastChannel(
      channelName: channelName,
      callbackValidator: webOptions.callbackValidator,
      completer: completer,
      onSuccess: cleanup,
    );

    // Create hidden iframe with sandbox restrictions.
    final iframeId = webOptions.iframeId ?? 'redirect_iframe';
    iframe = web.HTMLIFrameElement()
      ..id = iframeId
      ..style.display = 'none'
      ..setAttribute('sandbox', 'allow-same-origin allow-scripts allow-forms')
      ..src = url.toString();

    web.document.body?.appendChild(iframe!);

    return RedirectHandle(
      url: url,
      nonce: nonce,
      options: options,
      result: _wrapWithTimeout(completer, options.timeout, cleanup),
      cancel: () async => cancelSync(),
    );
  }

  /// Creates a [web.BroadcastChannel] that completes [completer] on a matching
  /// callback message, then calls [onSuccess] to clean up resources.
  ///
  /// Each operation uses a unique channel name
  /// (via [generateRedirectNonce]), so concurrent redirect
  /// operations are naturally isolated without relying
  /// on any protocol-specific parameters.
  ///
  /// This is the **primary** callback detection mechanism. The callback page
  /// script (`redirect_callback.js`), the Service Worker, or the static
  /// [handleCallback] method broadcasts the callback URL to all registered
  /// channels. Each operation listens on its own unique channel.
  static web.BroadcastChannel _createBroadcastChannel({
    required String channelName,
    required Completer<RedirectResult> completer,
    required void Function() onSuccess,
    WebCallbackValidator? callbackValidator,
  }) {
    final channel = web.BroadcastChannel(channelName)
      ..onmessage = (web.MessageEvent event) {
        final data = event.data;
        if (data == null || !data.isA<JSString>() || completer.isCompleted) {
          return;
        }
        try {
          final uriString = (data as JSString).toDart;
          final uri = Uri.tryParse(uriString);
          if (uri == null) return;

          // If a validator is provided, check the URI. Since the validator
          // can be async (FutureOr<bool>), we handle both branches.
          if (callbackValidator != null) {
            final result = callbackValidator(uri);
            if (result is bool) {
              if (!result) return;
              completer.complete(RedirectSuccess(uri: uri));
              onSuccess();
            } else {
              // Async validator
              unawaited(result.then((isValid) {
                if (isValid && !completer.isCompleted) {
                  completer.complete(RedirectSuccess(uri: uri));
                  onSuccess();
                }
              }));
            }
          } else {
            // No validator — accept all valid URIs.
            completer.complete(RedirectSuccess(uri: uri));
            onSuccess();
          }
        } on Object {
          // Ignore malformed messages
        }
      }.toJS;

    return channel;
  }

  /// Watches for a popup/tab being closed by the user via event listeners.
  ///
  /// When the parent window regains focus or becomes visible again, checks
  /// `target.closed` once. If the popup was closed without completing auth,
  /// completes with [RedirectCancelled] and calls [onClosed].
  ///
  /// This is fully event-driven — no polling. Each call is identified by
  /// [watcherId] so multiple concurrent redirects can coexist without
  /// overwriting each other's listeners.
  static void _watchForClose({
    required String watcherId,
    required web.Window target,
    required Completer<RedirectResult> completer,
    required void Function() onClosed,
  }) {
    void check(web.Event _) {
      if (completer.isCompleted) {
        _removeCloseWatcher(watcherId);
        return;
      }
      if (target.closed) {
        completer.complete(const RedirectCancelled());
        onClosed();
      }
    }

    // Store the listener keyed by watcher ID so concurrent redirects
    // don't interfere with each other.
    final jsCheck = check.toJS;
    _closeWatcherListeners[watcherId] = jsCheck;
    web.window.addEventListener('focus', jsCheck);
    web.document.addEventListener('visibilitychange', jsCheck);
  }

  /// Removes event listeners installed by [_watchForClose] for [watcherId].
  static void _removeCloseWatcher(String watcherId) {
    final listener = _closeWatcherListeners.remove(watcherId);
    if (listener == null) return;
    web.window.removeEventListener('focus', listener);
    web.document.removeEventListener('visibilitychange', listener);
  }

  /// Active close-watcher listeners keyed by watcher ID.
  static final Map<String, JSFunction> _closeWatcherListeners = {};

  static Future<RedirectResult> _wrapWithTimeout(
    Completer<RedirectResult> completer,
    Duration? timeout,
    void Function() cleanup,
  ) {
    if (timeout != null) {
      return completer.future.timeout(
        timeout,
        onTimeout: () {
          cleanup();
          return const RedirectCancelled();
        },
      );
    }
    return completer.future;
  }

  // --- Static helpers for callback pages ---

  /// `sessionStorage` keys for same-page redirect state.
  static const _pendingKey = 'redirect_pending';

  /// Checks if the app is returning from a same-page redirect.
  ///
  /// Returns `true` if [WebRedirectMode.samePage] was used and the user
  /// has been redirected back. Use [resumePendingRedirect] to retrieve
  /// the actual result.
  static bool hasPendingRedirect() {
    return web.window.sessionStorage.getItem(_pendingKey) == 'true';
  }

  /// Resumes a pending same-page redirect by reading `Uri.base`.
  ///
  /// Call this early in your app's initialization (e.g. `main()`) when
  /// [hasPendingRedirect] returns `true`. It clears the pending state
  /// and returns the current URL as a [RedirectSuccess].
  ///
  /// An optional [callbackValidator] can be provided to validate the
  /// current URL before accepting it as a callback.
  ///
  /// Returns `null` if no pending redirect exists.
  ///
  /// ```dart
  /// void main() {
  ///   final result = RedirectWeb.resumePendingRedirect();
  ///   if (result != null) {
  ///     switch (result) {
  ///       case RedirectSuccess(:final uri):
  ///         print('Callback: $uri');
  ///       case _:
  ///         print('Unexpected: $result');
  ///     }
  ///     return;
  ///   }
  ///   // Normal app startup...
  /// }
  /// ```
  static RedirectResult? resumePendingRedirect({
    bool Function(Uri)? callbackValidator,
  }) {
    final storage = web.window.sessionStorage;
    if (storage.getItem(_pendingKey) != 'true') return null;

    // Clean up regardless of outcome.
    storage.removeItem(_pendingKey);

    final callbackUri = Uri.base;

    if (callbackValidator != null && !callbackValidator(callbackUri)) {
      return RedirectFailure(
        error: Exception(
          'Callback URL validation failed for: $callbackUri',
        ),
        stackTrace: StackTrace.current,
      );
    }

    return RedirectSuccess(uri: callbackUri);
  }

  /// Clears the pending redirect flag without consuming the result.
  ///
  /// Prefer [resumePendingRedirect] which both clears and returns the
  /// result. Use this only if you need to discard a pending redirect.
  static void clearPendingRedirect() {
    web.window.sessionStorage.removeItem(_pendingKey);
  }

  /// Handles the callback and sends the result to the opener via
  /// BroadcastChannel.
  ///
  /// Call this on your callback page to notify the opener window/tab of the
  /// result.
  ///
  /// If [channelName] is omitted, auto-discovers ALL active channels from
  /// `localStorage` and broadcasts to each. Each operation listens on its
  /// own unique channel, so only the correct listener receives the message.
  ///
  /// ```dart
  /// // On your callback page (e.g., /callback):
  /// void main() {
  ///   // Auto-discovers and broadcasts to all active channels:
  ///   RedirectWeb.handleCallback(Uri.base);
  ///
  ///   // Or with an explicit channel name:
  ///   RedirectWeb.handleCallback(Uri.base, channelName: 'my_channel');
  /// }
  /// ```
  static void handleCallback(Uri callbackUri, {String? channelName}) {
    final message = callbackUri.toString().toJS;

    if (channelName != null) {
      web.BroadcastChannel(channelName)
        ..postMessage(message)
        ..close();
      return;
    }

    // Broadcast to every active channel.
    final channels = _getChannels();
    for (final name in channels) {
      web.BroadcastChannel(name)
        ..postMessage(message)
        ..close();
    }
  }

  // --- Channel registry (localStorage) ---

  /// `localStorage` key for the list of active channels.
  static const _channelStorageKey = 'redirect_channels';

  /// Reads the list of active channel names.
  static List<String> _getChannels() {
    final raw = web.window.localStorage.getItem(_channelStorageKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List<dynamic>).cast<String>();
    } on Object {
      return [];
    }
  }

  /// Adds [channelName] to the active list.
  ///
  /// Also notifies the Service Worker (if registered) so it can broadcast
  /// directly from the SW context.
  static void _registerChannel(String channelName) {
    final channels = _getChannels()..add(channelName);
    web.window.localStorage.setItem(
      _channelStorageKey,
      jsonEncode(channels),
    );
    _notifyServiceWorker('redirect_register', channelName);
  }

  /// Removes [channelName] from the active list.
  ///
  /// Also notifies the Service Worker (if registered) to stop tracking
  /// this channel.
  static void _unregisterChannel(String channelName) {
    final channels = _getChannels()..remove(channelName);
    if (channels.isEmpty) {
      web.window.localStorage.removeItem(_channelStorageKey);
    } else {
      web.window.localStorage.setItem(
        _channelStorageKey,
        jsonEncode(channels),
      );
    }
    _notifyServiceWorker('redirect_unregister', channelName);
  }

  /// Sends a channel registration/unregistration message to the active
  /// Service Worker, if one exists. Fails silently.
  static void _notifyServiceWorker(String type, String channelName) {
    try {
      final controller = web.window.navigator.serviceWorker.controller;
      if (controller == null) return;
      controller.postMessage(
        _ServiceWorkerMessage(type: type, channel: channelName),
      );
    } on Object {
      // No SW registered or not supported — fine, the callback page
      // script or handleCallback will handle it.
    }
  }

  /// Attempts to close this window/tab.
  ///
  /// This is useful after handling a callback in a popup or new tab.
  /// Note: Browsers may prevent closing windows that weren't opened by script.
  static void closeWindow() {
    web.window.close();
  }

  // --- Service Worker helpers ---

  /// Registers the redirect Service Worker.
  ///
  /// Once registered, the Service Worker intercepts navigation requests to
  /// [callbackPath] (defaults to `"/callback"`) and broadcasts the callback
  /// URL to all active redirect channels directly from the SW context via
  /// BroadcastChannel. It does **not** serve any HTML — the consumer's own
  /// callback page (if any) loads normally.
  ///
  /// This provides a fast-path for COOP-resilient callback handling without
  /// requiring any JavaScript on the callback page.
  ///
  /// The [scriptUrl] defaults to `"redirect_sw.js"`. Place the file
  /// (from `package:redirect_web_core/src/assets/redirect_sw.js`) in your
  /// `web/` directory. You can copy it with:
  ///
  /// ```sh
  /// dart run redirect_web_core:setup
  /// ```
  ///
  /// Prefer setting [WebRedirectOptions.autoRegisterServiceWorker] to `true`
  /// instead of calling this method manually. The SW will be registered
  /// automatically on the first redirect call.
  static Future<void> registerServiceWorker({
    String scriptUrl = 'redirect_sw.js',
    String callbackPath = '/callback',
  }) async {
    final navigator = web.window.navigator;
    final container = navigator.serviceWorker;

    final registration = await container.register(scriptUrl.toJS).toDart;

    // Wait for the worker to become active, then configure it.
    void configure(web.ServiceWorker worker) {
      worker.postMessage(
        _ServiceWorkerMessage(
          type: 'redirect_config',
          callbackPath: callbackPath,
        ),
      );
    }

    final active = registration.active;
    if (active != null) {
      configure(active);
    } else {
      // Worker is installing or waiting — listen for state changes.
      final installing = registration.installing ?? registration.waiting;
      if (installing != null) {
        installing.onstatechange = (web.Event _) {
          final current = registration.active;
          if (current != null) {
            configure(current);
          }
        }.toJS;
      }
    }
  }
}
