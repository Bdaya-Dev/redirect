import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

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
///   url: Uri.parse('https://example.com/start'),
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
///   url: Uri.parse('https://example.com/start'),
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
      WebRedirectMode.iframe => _runIframe(
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
    final popupOpts = webOptions.popupOptions;
    final width = popupOpts.width;
    final height = popupOpts.height;
    final left =
        popupOpts.left ?? ((web.window.screen.width - width) ~/ 2);
    final top =
        popupOpts.top ?? ((web.window.screen.height - height) ~/ 2);

    final extraFeatures = popupOpts.windowFeatures ??
        'toolbar=no,menubar=no,scrollbars=yes,resizable=yes';

    return _runWindowOpen(
      url: url,
      options: options,
      webOptions: webOptions,
      windowName: popupOpts.windowName,
      windowFeatures:
          'width=$width,height=$height,left=$left,top=$top,$extraFeatures',
      errorMessage: 'Failed to open popup window. Check popup blocker.',
    );
  }

  RedirectHandle _runNewTab({
    required Uri url,
    required RedirectOptions options,
    required WebRedirectOptions webOptions,
  }) {
    final tabOpts = webOptions.newTabOptions;

    return _runWindowOpen(
      url: url,
      options: options,
      webOptions: webOptions,
      windowName: tabOpts.windowName,
      windowFeatures: tabOpts.windowFeatures ?? '',
      errorMessage: 'Failed to open new tab. Check popup blocker.',
    );
  }

  /// Opens a browser window (popup or tab) and waits for a callback via
  /// BroadcastChannel.
  ///
  /// This is the shared implementation for both [_runPopup] and [_runNewTab],
  /// which only differ in the `window.open()` parameters.
  RedirectHandle _runWindowOpen({
    required Uri url,
    required RedirectOptions options,
    required WebRedirectOptions webOptions,
    required String windowName,
    required String windowFeatures,
    required String errorMessage,
  }) {
    final session = _initChannelSession(webOptions: webOptions);
    web.Window? openedWindow;

    void cleanup() {
      _removeCloseWatcher(session.channelName);
      openedWindow = null;
      session.cleanup();
    }

    void cancelSync() {
      if (!session.completer.isCompleted) {
        session.completer.complete(const RedirectCancelled());
      }
      openedWindow?.close();
      cleanup();
    }

    session.channel = _createBroadcastChannel(
      channelName: session.channelName,
      callbackValidator: webOptions.callbackValidator,
      completer: session.completer,
      onSuccess: () {
        openedWindow?.close();
        cleanup();
      },
    );

    // Open browser window — synchronous, in the user-gesture call stack
    // to avoid popup blockers.
    openedWindow = web.window.open(
      url.toString(),
      windowName,
      windowFeatures,
    );

    if (openedWindow == null) {
      cleanup();
      session.completer.complete(
        RedirectFailure(
          error: Exception(errorMessage),
          stackTrace: StackTrace.current,
        ),
      );
    } else {
      // Detect when the user closes the window without completing.
      _watchForClose(
        watcherId: session.channelName,
        target: openedWindow!,
        completer: session.completer,
        onClosed: cleanup,
      );
    }

    return RedirectHandle(
      url: url,
      nonce: session.nonce,
      options: options,
      result: _wrapWithTimeout(session.completer, options.timeout, cleanup),
      cancel: () async => cancelSync(),
    );
  }

  RedirectHandle _runSamePage({
    required Uri url,
    required RedirectOptions options,
  }) {
    // Generate nonce for this redirect operation.
    final nonce = generateRedirectNonce();

    // Navigate the current page to the target URL.
    // The server will eventually redirect to the callback page, which stores
    // the result in sessionStorage and navigates back to the app.
    // Use [resumePendingRedirect] after the app reloads to read the result.
    web.window.location.href = url.toString();

    // Return pending since we're navigating away.
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
    final session = _initChannelSession(webOptions: webOptions);
    web.HTMLIFrameElement? iframe;

    void cleanup() {
      iframe?.remove();
      iframe = null;
      session.cleanup();
    }

    void cancelSync() {
      if (!session.completer.isCompleted) {
        session.completer.complete(const RedirectCancelled());
      }
      cleanup();
    }

    session.channel = _createBroadcastChannel(
      channelName: session.channelName,
      callbackValidator: webOptions.callbackValidator,
      completer: session.completer,
      onSuccess: cleanup,
    );

    // Create iframe element with configurable attributes.
    final iframeOpts = webOptions.iframeOptions;
    iframe = web.HTMLIFrameElement()
      ..id = iframeOpts.id
      ..src = url.toString();

    // Visibility and dimensions.
    if (iframeOpts.hidden) {
      iframe!.style.display = 'none';
    } else {
      if (iframeOpts.width != null) {
        iframe!.width = iframeOpts.width.toString();
      }
      if (iframeOpts.height != null) {
        iframe!.height = iframeOpts.height.toString();
      }
      if (iframeOpts.style != null) {
        iframe!.style.cssText = iframeOpts.style!;
      }
    }

    // Sandbox attribute.
    if (iframeOpts.sandbox != null) {
      iframe!.setAttribute('sandbox', iframeOpts.sandbox!);
    }

    // Permissions Policy (allow attribute).
    if (iframeOpts.allow != null) {
      iframe!.allow = iframeOpts.allow!;
    }

    // Append to the configured parent element.
    final parent = web.document.querySelector(iframeOpts.parentSelector);
    (parent ?? web.document.body)?.appendChild(iframe!);

    return RedirectHandle(
      url: url,
      nonce: session.nonce,
      options: options,
      result: _wrapWithTimeout(session.completer, options.timeout, cleanup),
      cancel: () async => cancelSync(),
    );
  }

  /// Initializes the shared state for any channel-based redirect operation.
  ///
  /// Generates a unique nonce, computes the channel name, and registers it
  /// in localStorage. The returned [_ChannelSession] holds the mutable
  /// channel reference and provides a [_ChannelSession.cleanup] that closes
  /// the channel and unregisters it.
  static _ChannelSession _initChannelSession({
    required WebRedirectOptions webOptions,
  }) {
    final nonce = generateRedirectNonce();
    final channelName =
        webOptions.broadcastChannelName ?? 'redirect_$nonce';
    _registerChannel(channelName);
    return _ChannelSession(nonce: nonce, channelName: channelName);
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
  /// script (`redirect_callback.js`) or the static [handleCallback] method
  /// broadcasts the callback URL to all registered channels. Each operation
  /// listens on its own unique channel.
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
  /// `target.closed` once. If the popup was closed without completing the redirect,
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
  ///
  /// The callback page (`redirect_callback.js`) stores the result URL
  /// in sessionStorage and navigates back to the app. The app then
  /// calls [resumePendingRedirect] to read the stored result.
  static const _pendingKey = 'redirect_pending';
  static const _callbackUrlKey = 'redirect_callback_url';

  /// Checks if the app is returning from a same-page redirect.
  ///
  /// Returns `true` if the callback page has stored a result in
  /// `sessionStorage`. Use [resumePendingRedirect] to retrieve
  /// the actual result.
  static bool hasPendingRedirect() {
    return web.window.sessionStorage.getItem(_pendingKey) == 'true';
  }

  /// Resumes a pending same-page redirect by reading the callback URL
  /// from `sessionStorage`.
  ///
  /// The callback page stores the full callback URL (with query parameters,
  /// callback parameters, etc.) in `sessionStorage` and then navigates back to the
  /// app's clean URL. This avoids exposing sensitive parameters in the
  /// app's URL and prevents conflicts with the app's router.
  ///
  /// Call this early in your app's initialization (e.g. `main()`) when
  /// [hasPendingRedirect] returns `true`. It clears the pending state
  /// and returns the stored URL as a [RedirectSuccess].
  ///
  /// An optional [callbackValidator] can be provided to validate the
  /// stored URL before accepting it as a callback.
  ///
  /// Returns `null` if no pending redirect exists.
  ///
  /// ```dart
  /// void main() {
  ///   final result = RedirectWeb.resumePendingRedirect();
  ///   if (result != null) {
  ///     switch (result) {
  ///       case RedirectSuccess(:final uri):
  ///         print('Callback: \$uri');
  ///       case _:
  ///         print('Unexpected: \$result');
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

    final storedUrl = storage.getItem(_callbackUrlKey);

    // Clean up regardless of outcome.
    storage..removeItem(_pendingKey)
    ..removeItem(_callbackUrlKey);

    if (storedUrl == null || storedUrl.isEmpty) {
      return RedirectFailure(
        error: Exception(
          'Pending redirect found but no callback URL was stored.',
        ),
        stackTrace: StackTrace.current,
      );
    }

    final callbackUri = Uri.tryParse(storedUrl);
    if (callbackUri == null) {
      return RedirectFailure(
        error: Exception(
          'Stored callback URL is malformed: $storedUrl',
        ),
        stackTrace: StackTrace.current,
      );
    }

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

  /// Clears the pending redirect flag and stored URL without consuming
  /// the result.
  ///
  /// Prefer [resumePendingRedirect] which both clears and returns the
  /// result. Use this only if you need to discard a pending redirect.
  static void clearPendingRedirect() {
    web.window.sessionStorage
      ..removeItem(_pendingKey)
      ..removeItem(_callbackUrlKey);
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
  static void _registerChannel(String channelName) {
    final channels = _getChannels()..add(channelName);
    web.window.localStorage.setItem(
      _channelStorageKey,
      jsonEncode(channels),
    );
  }

  /// Removes [channelName] from the active list.
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
  }

  /// Attempts to close this window/tab.
  ///
  /// This is useful after handling a callback in a popup or new tab.
  /// Note: Browsers may prevent closing windows that weren't opened by script.
  static void closeWindow() {
    web.window.close();
  }
}

/// Mutable state for a single channel-based redirect operation.
///
/// Holds the nonce, channel name, completer, and channel reference.
/// [cleanup] closes the channel and unregisters it from localStorage.
class _ChannelSession {
  _ChannelSession({
    required this.nonce,
    required this.channelName,
  });

  final String nonce;
  final String channelName;
  final Completer<RedirectResult> completer = Completer<RedirectResult>();

  /// The active BroadcastChannel. Set after creation by the caller so that
  /// [cleanup] can close it.
  web.BroadcastChannel? channel;

  /// Closes the channel and removes it from the localStorage registry.
  void cleanup() {
    channel?.close();
    channel = null;
    RedirectWeb._unregisterChannel(channelName);
  }
}
