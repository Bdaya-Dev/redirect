import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:math';

import 'package:redirect_core/redirect_core.dart';
import 'package:web/web.dart' as web;

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
///   callbackUrlScheme: 'https',
/// );
/// final result = await handle.result;
/// ```
///
/// ## Custom Web Options
///
/// ```dart
/// final redirect = RedirectWeb(
///   defaultWebOptions: WebRedirectOptions(mode: WebRedirectMode.newTab),
/// );
/// ```
///
/// Or per-call:
///
/// ```dart
/// final handle = redirect.runWithWebOptions(
///   url: Uri.parse('https://auth.example.com/authorize'),
///   callbackUrlScheme: 'https',
///   webOptions: WebRedirectOptions(mode: WebRedirectMode.samePage),
/// );
/// final result = await handle.result;
/// ```
class RedirectWeb implements RedirectHandler {
  /// Creates a new web redirect handler.
  ///
  /// [defaultWebOptions] specifies the default web-specific options used when
  /// calling [run]. Defaults to popup mode.
  RedirectWeb({
    this.defaultWebOptions = const WebRedirectOptions(),
  });

  /// Default web options used by [run].
  final WebRedirectOptions defaultWebOptions;

  @override
  RedirectHandle run({
    required Uri url,
    required String callbackUrlScheme,
    RedirectOptions options = const RedirectOptions(),
  }) {
    // Extract web options from platformOptions, falling back to defaults
    final webOptions = WebRedirectOptions.fromOptions(
      options,
      defaultWebOptions,
    );

    return runWithWebOptions(
      url: url,
      callbackUrlScheme: callbackUrlScheme,
      options: options,
      webOptions: webOptions,
    );
  }

  /// Runs the redirect with explicit web-specific options.
  ///
  /// This method provides full control over how the authorization URL is
  /// opened on web platforms.
  ///
  /// The returned [RedirectHandle] is created **synchronously**, pre-opening
  /// any required browser window in the current call stack. This avoids
  /// popup blockers when `run` is called from a user-gesture handler.
  RedirectHandle runWithWebOptions({
    required Uri url,
    required String callbackUrlScheme,
    RedirectOptions options = const RedirectOptions(),
    WebRedirectOptions webOptions = const WebRedirectOptions(),
  }) {
    return switch (webOptions.mode) {
      WebRedirectMode.popup => _runPopup(
        url: url,
        callbackUrlScheme: callbackUrlScheme,
        options: options,
        webOptions: webOptions,
      ),
      WebRedirectMode.newTab => _runNewTab(
        url: url,
        callbackUrlScheme: callbackUrlScheme,
        options: options,
        webOptions: webOptions,
      ),
      WebRedirectMode.samePage => _runSamePage(
        url: url,
        callbackUrlScheme: callbackUrlScheme,
        options: options,
      ),
      WebRedirectMode.hiddenIframe => _runIframe(
        url: url,
        callbackUrlScheme: callbackUrlScheme,
        options: options,
        webOptions: webOptions,
      ),
    };
  }

  RedirectHandle _runPopup({
    required Uri url,
    required String callbackUrlScheme,
    required RedirectOptions options,
    required WebRedirectOptions webOptions,
  }) {
    final completer = Completer<RedirectResult>();
    web.Window? popup;
    web.BroadcastChannel? channel;

    // Each operation gets a unique channel name so concurrent redirects
    // don't interfere, regardless of the protocol being used.
    final channelName =
        webOptions.broadcastChannelName ??
        'redirect_${callbackUrlScheme}_${_generateNonce()}';
    _registerChannel(callbackUrlScheme, channelName);

    void cleanup() {
      _removeCloseWatcher();
      channel?.close();
      channel = null;
      popup = null;
      _unregisterChannel(callbackUrlScheme, channelName);
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
      callbackUrlScheme: callbackUrlScheme,
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
        target: popup!,
        completer: completer,
        onClosed: cleanup,
      );
    }

    return RedirectHandle(
      url: url,
      callbackUrlScheme: callbackUrlScheme,
      options: options,
      result: _wrapWithTimeout(completer, options.timeout, cleanup),
      cancel: () async => cancelSync(),
    );
  }

  RedirectHandle _runNewTab({
    required Uri url,
    required String callbackUrlScheme,
    required RedirectOptions options,
    required WebRedirectOptions webOptions,
  }) {
    final completer = Completer<RedirectResult>();
    web.Window? popup;
    web.BroadcastChannel? channel;

    // Each operation gets a unique channel name so concurrent redirects
    // don't interfere, regardless of the protocol being used.
    final channelName =
        webOptions.broadcastChannelName ??
        'redirect_${callbackUrlScheme}_${_generateNonce()}';
    _registerChannel(callbackUrlScheme, channelName);

    void cleanup() {
      _removeCloseWatcher();
      channel?.close();
      channel = null;
      popup = null;
      _unregisterChannel(callbackUrlScheme, channelName);
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
      callbackUrlScheme: callbackUrlScheme,
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
        target: popup!,
        completer: completer,
        onClosed: cleanup,
      );
    }

    return RedirectHandle(
      url: url,
      callbackUrlScheme: callbackUrlScheme,
      options: options,
      result: _wrapWithTimeout(completer, options.timeout, cleanup),
      cancel: () async => cancelSync(),
    );
  }

  RedirectHandle _runSamePage({
    required Uri url,
    required String callbackUrlScheme,
    required RedirectOptions options,
  }) {
    // Persist enough state for the reloaded app to resume.
    // sessionStorage survives same-origin navigations within a tab but
    // is not shared across tabs, which is exactly the right scope.
    web.window.sessionStorage
      ..setItem(_pendingKey, 'true')
      ..setItem(_pendingSchemeKey, callbackUrlScheme);

    // Navigate the current page
    web.window.location.href = url.toString();

    // Return pending since we're navigating away
    // The actual result must be retrieved via [resumePendingRedirect]
    // after the app reloads at the callback URL.
    return RedirectHandle(
      url: url,
      callbackUrlScheme: callbackUrlScheme,
      options: options,
      result: Future.value(const RedirectPending()),
      cancel: () async {},
    );
  }

  RedirectHandle _runIframe({
    required Uri url,
    required String callbackUrlScheme,
    required RedirectOptions options,
    required WebRedirectOptions webOptions,
  }) {
    final completer = Completer<RedirectResult>();
    web.BroadcastChannel? channel;
    web.HTMLIFrameElement? iframe;

    // Each operation gets a unique channel name so concurrent redirects
    // don't interfere, regardless of the protocol being used.
    final channelName =
        webOptions.broadcastChannelName ??
        'redirect_${callbackUrlScheme}_${_generateNonce()}';
    _registerChannel(callbackUrlScheme, channelName);

    void cleanup() {
      channel?.close();
      channel = null;
      iframe?.remove();
      iframe = null;
      _unregisterChannel(callbackUrlScheme, channelName);
    }

    void cancelSync() {
      if (!completer.isCompleted) {
        completer.complete(const RedirectCancelled());
      }
      cleanup();
    }

    channel = _createBroadcastChannel(
      channelName: channelName,
      callbackUrlScheme: callbackUrlScheme,
      completer: completer,
      onSuccess: cleanup,
    );

    // Create hidden iframe
    final iframeId = webOptions.iframeId ?? 'redirect_iframe';
    iframe = web.document.createElement('iframe') as web.HTMLIFrameElement
      ..id = iframeId
      ..style.display = 'none'
      ..src = url.toString();

    web.document.body?.appendChild(iframe!);

    return RedirectHandle(
      url: url,
      callbackUrlScheme: callbackUrlScheme,
      options: options,
      result: _wrapWithTimeout(completer, options.timeout, cleanup),
      cancel: () async => cancelSync(),
    );
  }

  /// Creates a [web.BroadcastChannel] that completes [completer] on a matching
  /// callback message, then calls [onSuccess] to clean up resources.
  ///
  /// Each operation uses a unique channel name (see [_generateNonce]), so
  /// concurrent redirect operations are naturally isolated without relying
  /// on any protocol-specific parameters.
  ///
  /// This is the **primary** callback detection mechanism. The callback page
  /// script (`redirect_callback.js`), the Service Worker, or the static
  /// [handleCallback] method broadcasts the callback URL to all registered
  /// channels. Each operation listens on its own unique channel.
  static web.BroadcastChannel _createBroadcastChannel({
    required String channelName,
    required String callbackUrlScheme,
    required Completer<RedirectResult> completer,
    required void Function() onSuccess,
  }) {
    final channel = web.BroadcastChannel(channelName)
      ..onmessage = (web.MessageEvent event) {
        final data = event.data;
        if (data != null && !completer.isCompleted) {
          try {
            final uriString = (data as JSString).toDart;
            final uri = Uri.tryParse(uriString);
            if (uri == null || uri.scheme != callbackUrlScheme) return;

            completer.complete(RedirectSuccess(uri: uri));
            onSuccess();
          } on Object {
            // Ignore malformed messages
          }
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
  /// This is fully event-driven — no polling.
  static void _watchForClose({
    required web.Window target,
    required Completer<RedirectResult> completer,
    required void Function() onClosed,
  }) {
    void check(web.Event _) {
      if (completer.isCompleted) {
        _removeCloseWatcher();
        return;
      }
      if (target.closed) {
        completer.complete(const RedirectCancelled());
        onClosed();
      }
    }

    // Store the listener so cleanup can remove it.
    web.window.addEventListener('focus', _closeWatcherListener = check.toJS);
    web.document.addEventListener('visibilitychange', check.toJS);
  }

  /// Removes event listeners installed by [_watchForClose].
  static void _removeCloseWatcher() {
    final listener = _closeWatcherListener;
    if (listener == null) return;
    web.window.removeEventListener('focus', listener);
    web.document.removeEventListener('visibilitychange', listener);
    _closeWatcherListener = null;
  }

  /// The current close-watcher event listener, if any.
  static JSFunction? _closeWatcherListener;

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
  static const _pendingSchemeKey = 'redirect_pending_scheme';

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
  /// [hasPendingRedirect] returns `true`. It validates that the current
  /// URL matches the expected callback scheme, clears the pending state,
  /// and returns the appropriate [RedirectResult].
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
  static RedirectResult? resumePendingRedirect() {
    final storage = web.window.sessionStorage;
    if (storage.getItem(_pendingKey) != 'true') return null;

    final scheme = storage.getItem(_pendingSchemeKey);

    // Clean up regardless of outcome.
    storage
      ..removeItem(_pendingKey)
      ..removeItem(_pendingSchemeKey);

    final callbackUri = Uri.base;

    // If a scheme was stored, validate it. If not, accept any URI
    // (backward compatibility with old storage format).
    if (scheme != null && callbackUri.scheme != scheme) {
      return RedirectFailure(
        error: Exception(
          'Expected callback scheme "$scheme" but got '
          '"${callbackUri.scheme}".',
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
    web.window.sessionStorage
      ..removeItem(_pendingKey)
      ..removeItem(_pendingSchemeKey);
  }

  /// Handles the callback and sends the result to the opener via
  /// BroadcastChannel.
  ///
  /// Call this on your callback page to notify the opener window/tab of the
  /// result.
  ///
  /// If [channelName] is omitted, auto-discovers ALL active channels for
  /// [callbackUri]'s scheme from `localStorage` and broadcasts to each.
  /// Each operation listens on its own unique channel, so only the correct
  /// listener receives the message.
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

    // Broadcast to every active channel registered for this scheme.
    final channels = _getChannels(callbackUri.scheme);
    for (final name in channels) {
      web.BroadcastChannel(name)
        ..postMessage(message)
        ..close();
    }
  }

  // --- Channel registry (localStorage) ---

  /// `localStorage` key prefix for the per-scheme list of active channels.
  static const _channelStoragePrefix = 'redirect_channels_';

  /// Returns the `localStorage` key for a given [scheme].
  static String _channelStorageKey(String scheme) =>
      '$_channelStoragePrefix$scheme';

  /// Reads the list of active channel names for [scheme].
  static List<String> _getChannels(String scheme) {
    final raw = web.window.localStorage.getItem(_channelStorageKey(scheme));
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List<dynamic>).cast<String>();
    } on Object {
      return [];
    }
  }

  /// Adds [channelName] to the active list for [scheme].
  ///
  /// Also notifies the Service Worker (if registered) so it can broadcast
  /// directly from the SW context.
  static void _registerChannel(String scheme, String channelName) {
    final channels = _getChannels(scheme)..add(channelName);
    web.window.localStorage.setItem(
      _channelStorageKey(scheme),
      jsonEncode(channels),
    );
    _notifyServiceWorker('redirect_register', channelName);
  }

  /// Removes [channelName] from the active list for [scheme].
  ///
  /// Also notifies the Service Worker (if registered) to stop tracking
  /// this channel.
  static void _unregisterChannel(String scheme, String channelName) {
    final channels = _getChannels(scheme)..remove(channelName);
    if (channels.isEmpty) {
      web.window.localStorage.removeItem(_channelStorageKey(scheme));
    } else {
      web.window.localStorage.setItem(
        _channelStorageKey(scheme),
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
        {'type': type, 'channel': channelName}.jsify(),
      );
    } on Object {
      // No SW registered or not supported — fine, the callback page
      // script or handleCallback will handle it.
    }
  }

  /// Generates a short random nonce for unique channel naming.
  static String _generateNonce() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rng = Random.secure();
    return List.generate(12, (_) => chars[rng.nextInt(chars.length)]).join();
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
  /// `web/` directory.
  ///
  /// ```dart
  /// void main() {
  ///   // Register once at app startup:
  ///   RedirectWeb.registerServiceWorker(callbackPath: '/auth/callback');
  ///
  ///   // Then use RedirectWeb as normal.
  /// }
  /// ```
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
        {
          'type': 'redirect_config',
          'callbackPath': callbackPath,
        }.jsify(),
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
