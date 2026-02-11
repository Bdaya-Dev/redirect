<p align="center">
  <a href="https://github.com/Bdaya-Dev/redirect">
    <img src="https://raw.githubusercontent.com/Bdaya-Dev/redirect/main/logo.svg" alt="redirect logo" width="96" height="96">
  </a>
</p>

<h1 align="center">redirect</h1>

<p align="center">
  A Flutter plugin to facilitate redirect-based flows.
</p>

<p align="center">
  <a href="https://opensource.org/licenses/MIT"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="License: MIT"></a>
  <a href="https://pub.dev/packages/redirect"><img src="https://img.shields.io/pub/v/redirect.svg" alt="pub.dev"></a>
  <a href="https://pub.dev/packages/very_good_analysis"><img src="https://img.shields.io/badge/style-very_good_analysis-B22C89.svg" alt="style: very good analysis"></a>
</p>

---

## What is this?

`redirect` handles the "open a URL, wait for a callback" pattern across every Flutter platform. You call `runRedirect()`, the user is sent to a browser, and your app gets back a URI when they're done. Think OAuth, SAML, payment gateways, email verification — anything where a server redirects back to your app.

The handle is returned **synchronously**, which matters on web: the browser window opens inside the user-gesture call stack, so popup blockers don't interfere.

## Platform Support

| Platform | Mechanism | Callback type |
|----------|-----------|---------------|
| Android | Chrome Custom Tabs | Custom scheme (`myapp://`) or App Links |
| iOS | ASWebAuthenticationSession | Custom scheme or Universal Links |
| macOS | ASWebAuthenticationSession | Custom scheme or Universal Links |
| Linux | Loopback HTTP server + system browser | `http://127.0.0.1:<port>/` |
| Windows | Loopback HTTP server + system browser | `http://127.0.0.1:<port>/` |
| Web | Popup, new tab, same-page redirect, or iframe | Same-origin URL |

## Installation

```yaml
dependencies:
  redirect: ^0.1.0
```

Platform implementations are [endorsed](https://docs.flutter.dev/packages-and-plugins/developing-packages#endorsed-federated-plugin) and pulled in automatically — no need to add them individually.

Requires Dart `^3.10.0` and Flutter `>=3.38.0`.

## Quick Start

```dart
import 'package:redirect/redirect.dart';

void onLoginTap() {
  final handle = runRedirect(
    url: Uri.parse('https://example.com/authorize?redirect_uri=myapp://callback'),
    options: RedirectOptions(
      platformOptions: {
        AndroidRedirectOptions.key: AndroidRedirectOptions(callbackUrlScheme: 'myapp'),
        IosRedirectOptions.key: IosRedirectOptions(callback: CallbackConfig.customScheme('myapp')),
        MacosRedirectOptions.key: MacosRedirectOptions(callback: CallbackConfig.customScheme('myapp')),
      },
    ),
  );

  handle.result.then((result) {
    switch (result) {
      case RedirectSuccess(:final uri):
        final code = uri.queryParameters['code'];
        // exchange code for token, etc.
      case RedirectCancelled():
        // user closed the browser
      case RedirectFailure(:final error):
        // something went wrong
      case RedirectPending():
        // web same-page mode only — the page navigated away,
        // check for the result on reload
    }
  });
}
```

`runRedirect()` returns a `RedirectHandle` with two things: a `Future<RedirectResult> result` and a `cancel()` function.

`RedirectResult` is a sealed class — the compiler will enforce that you handle every case.

## Building URLs Per Platform

Writing per-platform `platformOptions` maps by hand gets verbose. `constructRedirectUrl` detects the current platform and calls the right builder, returning both the URL and the options ready to pass to `runRedirect()`:

```dart
final (:url, :options) = constructRedirectUrl(
  fallback: (_) => RedirectUrlConfig(
    url: Uri.parse('https://example.com/authorize?redirect_uri=myapp://callback'),
  ),
  onAndroid: (_) => RedirectUrlConfig(
    url: Uri.parse('https://example.com/authorize?redirect_uri=myapp://callback'),
    platformOptions: {
      AndroidRedirectOptions.key: AndroidRedirectOptions(
        callbackUrlScheme: 'myapp',
        preferEphemeral: true,  // Ephemeral Custom Tabs (Chrome 136+)
      ),
    },
  ),
  onDarwin: (platform) => RedirectUrlConfig(
    url: Uri.parse('https://example.com/authorize?redirect_uri=myapp://callback'),
    platformOptions: {
      if (platform == RedirectPlatformType.ios)
        IosRedirectOptions.key: IosRedirectOptions(
          callback: CallbackConfig.customScheme('myapp'),
          preferEphemeral: true,  // private ASWebAuthenticationSession
        )
      else
        MacosRedirectOptions.key: MacosRedirectOptions(
          callback: CallbackConfig.customScheme('myapp'),
          preferEphemeral: true,
        ),
    },
  ),
  onDesktop: (_) => RedirectUrlConfig(
    // Desktop URL is built dynamically — the actual redirect_uri
    // includes the ephemeral port assigned at runtime.
    url: Uri.parse('https://example.com/authorize'),
    platformOptions: {
      LinuxRedirectOptions.key: LinuxRedirectOptions(
        urlBuilder: (port) => Uri.parse(
          'https://example.com/authorize?redirect_uri=http://127.0.0.1:$port/callback',
        ),
      ),
      WindowsRedirectOptions.key: WindowsRedirectOptions(
        urlBuilder: (port) => Uri.parse(
          'https://example.com/authorize?redirect_uri=http://127.0.0.1:$port/callback',
        ),
      ),
    },
  ),
  onWeb: (_) => RedirectUrlConfig(
    url: Uri.parse(
      'https://example.com/authorize'
      '?redirect_uri=${Uri.encodeComponent("${Uri.base.origin}/assets/packages/redirect_web/assets/redirect_callback.html")}',
    ),
    platformOptions: {
      WebRedirectOptions.key: WebRedirectOptions(mode: WebRedirectMode.popup),
    },
  ),
  timeout: Duration(minutes: 5),  // default for all platforms
);

final handle = runRedirect(url: url, options: options);
```

`timeout` can be set in two places: on `constructRedirectUrl` as a default, or on individual `RedirectUrlConfig`s to override per platform. Config values take precedence — if the selected builder sets `timeout: Duration(seconds: 30)`, that wins over the top-level `timeout: Duration(minutes: 5)`. `preferEphemeral` is set directly on platform options that support it (`AndroidRedirectOptions`, `IosRedirectOptions`, `MacosRedirectOptions`).

Each builder receives the specific `RedirectPlatformType`, so group callbacks can distinguish their platforms. Resolution order per platform:

| Platform | Tries in order |
|----------|---------------|
| Android | `onAndroid` → `onMobile` → `fallback` |
| iOS | `onIos` → `onDarwin` → `onMobile` → `fallback` |
| macOS | `onMacos` → `onDarwin` → `fallback` |
| Linux | `onLinux` → `onDesktop` → `fallback` |
| Windows | `onWindows` → `onDesktop` → `fallback` |
| Web | `onWeb` → `fallback` |

## Platform Setup

### Android

Register a callback activity in your `AndroidManifest.xml`:

```xml
<activity
  android:name="com.bdayadev.redirect_android.CallbackActivity"
  android:exported="true">
  <intent-filter>
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="myapp" />
  </intent-filter>
</activity>
```

Then pass the matching scheme in your options:

```dart
AndroidRedirectOptions(callbackUrlScheme: 'myapp')
```

Chrome Custom Tabs are used by default. You can customize them:

```dart
AndroidRedirectOptions(
  callbackUrlScheme: 'myapp',
  useCustomTabs: true,        // default
  showTitle: true,
  enableUrlBarHiding: true,
  toolbarColor: 0xFF2196F3,   // ARGB
  preferEphemeral: true,      // Ephemeral Custom Tabs (Chrome 136+)
)
```

### iOS & macOS

Both platforms use `ASWebAuthenticationSession` under the hood.

Provide a `CallbackConfig` — either a custom scheme or an HTTPS host+path:

```dart
// Custom scheme
IosRedirectOptions(callback: CallbackConfig.customScheme('myapp'))

// Universal Links
MacosRedirectOptions(
  callback: CallbackConfig.https(host: 'example.com', path: '/callback'),
)
```

Set `preferEphemeral: true` on `IosRedirectOptions` or `MacosRedirectOptions` to use a private browsing session (no shared cookies with Safari):\n\n```dart\nIosRedirectOptions(\n  callback: CallbackConfig.customScheme('myapp'),\n  preferEphemeral: true,\n)\n```

On iOS 17.4+ / macOS 14.4+, you can pass additional HTTP headers:

```dart
IosRedirectOptions(
  callback: CallbackConfig.customScheme('myapp'),
  additionalHeaderFields: {'X-Custom': 'value'},
)
```

### Linux & Windows

No native setup needed. The plugin spins up a local HTTP server on an ephemeral port and opens the system browser. When the server receives the callback request, it serves a styled "Redirect Complete" HTML page and resolves the result.

The platform options inherit from `ServerRedirectOptions`, so you can customize the server behavior:

```dart
WindowsRedirectOptions(
  callbackValidator: (uri) => uri.queryParameters.containsKey('code'),
  httpResponseBuilder: (request) => HttpCallbackResponse(
    body: '<html><body>Done! You can close this tab.</body></html>',
  ),
)
```

You can also get the assigned port via `portCompleter` and build the redirect URL dynamically with `urlBuilder`:

```dart
final portCompleter = Completer<int>();

final handle = runRedirect(
  url: Uri.parse('https://example.com/authorize'), // placeholder
  options: RedirectOptions(
    platformOptions: {
      LinuxRedirectOptions.key: LinuxRedirectOptions(
        portCompleter: portCompleter,
        urlBuilder: (port) => Uri.parse(
          'https://example.com/authorize?redirect_uri=http://127.0.0.1:$port/callback',
        ),
      ),
    },
  ),
);
```

### Web

The plugin ships a callback HTML page as a Flutter asset. After `flutter build web`, it's available at:

```
assets/packages/redirect_web/assets/redirect_callback.html
```

Use this path as your redirect URI on the server side. The callback page uses a `BroadcastChannel` to relay the callback URL back to your app — no polling involved.

#### Modes

```dart
WebRedirectOptions(mode: WebRedirectMode.popup)    // default
WebRedirectOptions(mode: WebRedirectMode.newTab)
WebRedirectOptions(mode: WebRedirectMode.samePage)
WebRedirectOptions(mode: WebRedirectMode.iframe)
```

**Popup** — Opens a sized window. Closes automatically after the callback is received.

```dart
WebRedirectOptions(
  mode: WebRedirectMode.popup,
  popupOptions: PopupOptions(
    width: 600,
    height: 800,
    windowName: 'login_popup',
  ),
)
```

**New tab** — Opens in a new browser tab. Same mechanism as popup, different presentation.

**Same page** — Navigates the current tab to the URL. `result` resolves to `RedirectPending` immediately because the page is about to unload. On reload, retrieve the result:

```dart
import 'package:redirect_web_core/redirect_web_core.dart';

void main() {
  if (RedirectWeb.hasPendingRedirect()) {
    final result = RedirectWeb.resumePendingRedirect();
    // result is a RedirectSuccess with the callback URI
  }
  runApp(MyApp());
}
```

**Iframe** — Loads the redirect in a hidden (or visible) iframe. Useful for silent token renewal.

```dart
WebRedirectOptions(
  mode: WebRedirectMode.iframe,
  iframeOptions: IframeOptions(
    hidden: true,     // default
    sandbox: 'allow-same-origin allow-scripts allow-forms',
  ),
)
```

## Cancellation

Every handle can be cancelled at any time:

```dart
final handle = runRedirect(url: authorizeUrl, options: options);

// later...
await handle.cancel();
// handle.result completes with RedirectCancelled()
```

## Timeout

Auto-cancel after a duration:

```dart
RedirectOptions(
  timeout: Duration(minutes: 5),
)
```

The result will be `RedirectCancelled()` if the timeout fires before a callback arrives.

## Concurrent Redirects

You can run multiple redirects at the same time. Each one gets a unique nonce and its own independent lifecycle:

```dart
final handle1 = runRedirect(url: url1, options: opts1);
final handle2 = runRedirect(url: url2, options: opts2);

// cancel one without affecting the other
await handle1.cancel();
final result2 = await handle2.result;
```

## Architecture

This is a [federated plugin](https://docs.flutter.dev/packages-and-plugins/developing-packages#federated-plugins). You only import `redirect` — the platform packages are wired in automatically.

```
redirect                            <- you import this
├── redirect_platform_interface     <- PlatformInterface base class
│   └── redirect_core              <- shared types (pure Dart, no Flutter)
├── redirect_android               <- Chrome Custom Tabs (Pigeon)
├── redirect_darwin                <- ASWebAuthenticationSession (Pigeon, shared Darwin source)
├── redirect_desktop               <- delegates to redirect_io
│   └── redirect_io               <- loopback HTTP server (pure Dart)
└── redirect_web                   <- Flutter web plugin wrapper + callback assets
    └── redirect_web_core          <- BroadcastChannel-based impl (pure Dart)
```

The pure-Dart packages (`redirect_io`, `redirect_web_core`) can be used without Flutter — useful for CLI tools, Dart backends, or non-Flutter web frameworks like Jaspr.

## Additional Resources

- [Example App](https://github.com/Bdaya-Dev/redirect/tree/main/packages/redirect/example) — runnable Flutter demo with per-platform configuration UI
- [API Reference](https://pub.dev/documentation/redirect/latest/)

## License

MIT — see [LICENSE](https://github.com/Bdaya-Dev/redirect/blob/main/LICENSE).

---

<p align="center">
  Built with 💙 by <a href="https://github.com/Bdaya-Dev">Bdaya Dev</a>
</p>
