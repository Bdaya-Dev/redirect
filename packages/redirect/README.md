<p align="center">
  <a href="https://github.com/Bdaya-Dev/redirect">
    <img src="https://raw.githubusercontent.com/Bdaya-Dev/redirect/main/logo.svg" alt="redirect logo" width="96" height="96">
  </a>
</p>

<h1 align="center">redirect</h1>

<p align="center">
  A Flutter plugin to facilitate redirect-based flows — OAuth, OIDC, payment gateways, and more.
</p>

<p align="center">
  <a href="https://opensource.org/licenses/MIT"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="License: MIT"></a>
  <a href="https://pub.dev/packages/redirect"><img src="https://img.shields.io/pub/v/redirect.svg" alt="pub.dev"></a>
  <a href="https://pub.dev/packages/very_good_analysis"><img src="https://img.shields.io/badge/style-very_good_analysis-B22C89.svg" alt="style: very good analysis"></a>
</p>

---

## Features

- **One-line API** — Call `runRedirect()` and get a result. That's it.
- **Cross-platform** — Android, iOS, macOS, Linux, Windows, and Web from a single import.
- **Popup-blocker safe** — Returns a `RedirectHandle` synchronously so the browser window opens in the user-gesture call stack.
- **Sealed results** — Exhaustive pattern matching with `RedirectSuccess`, `RedirectCancelled`, `RedirectPending`, and `RedirectFailure`.
- **Configurable** — Timeout, ephemeral sessions, and platform-specific options (web popup size, iframe, new tab, same-page redirect).

## Platform Support

| Platform | Mechanism |
|----------|-----------|
| Android | Chrome Custom Tabs |
| iOS / macOS | ASWebAuthenticationSession |
| Linux / Windows | Loopback HTTP server + system browser |
| Web | Popup / New tab / Same-page / Hidden iframe |

## Installation

```yaml
dependencies:
  redirect: ^0.1.0
```

Platform implementations are [endorsed](https://docs.flutter.dev/packages-and-plugins/developing-packages#endorsed-federated-plugin) and included automatically.

## Usage

```dart
import 'package:redirect/redirect.dart';

void onLoginTap() {
  // Synchronous — opens browser immediately (no popup blockers)
  final handle = runRedirect(
    url: Uri.parse('https://accounts.google.com/o/oauth2/v2/auth?...'),
    callbackUrlScheme: 'myapp',
  );

  handle.result.then((result) {
    switch (result) {
      case RedirectSuccess(:final uri):
        final code = uri.queryParameters['code'];
        // Exchange authorization code for tokens
      case RedirectCancelled():
        print('User cancelled');
      case RedirectFailure(:final error):
        print('Error: $error');
      case RedirectPending():
        // Web same-page mode only
        break;
    }
  });
}
```

### Options

```dart
final handle = runRedirect(
  url: authUrl,
  callbackUrlScheme: 'myapp',
  options: RedirectOptions(
    timeout: Duration(minutes: 5),     // Auto-cancel after 5 min
    preferEphemeral: true,             // Private/incognito session
  ),
);
```

### Cancel a Redirect

```dart
final handle = runRedirect(url: authUrl, callbackUrlScheme: 'myapp');

// Later...
await handle.cancel(); // result completes with RedirectCancelled
```

### Web-Specific Options

```dart
import 'package:redirect/redirect.dart';

final handle = runRedirect(
  url: authUrl,
  callbackUrlScheme: 'https',
  options: RedirectOptions(
    platformOptions: {
      WebRedirectOptions.key: WebRedirectOptions(
        mode: WebRedirectMode.newTab, // or .popup, .samePage, .hiddenIframe
        popupWidth: 600,
        popupHeight: 800,
      ),
    },
  ),
);
```

## Callback URL Schemes by Platform

| Platform | Scheme | Example |
|----------|--------|---------|
| Android / iOS | Custom scheme | `myapp://callback` |
| Android / iOS | Universal Links | `https://example.com/callback` |
| Web | Same-origin | `https://yourapp.com/callback` |
| Desktop | Loopback | `http://127.0.0.1:PORT/` |

## Architecture

This is a **federated plugin**. The main `redirect` package delegates to platform-specific implementations:

```
redirect (Flutter plugin — you import this)
├── redirect_platform_interface (Flutter platform interface)
│   └── redirect_core (shared types — pure Dart)
├── redirect_android (Android — Custom Tabs)
├── redirect_darwin (iOS & macOS — ASWebAuthenticationSession)
├── redirect_desktop (Linux & Windows — loopback server)
└── redirect_web → redirect_web_core (Web — popup/tab/iframe)
```

For **pure Dart** (no Flutter), use `redirect_cli` or `redirect_web_core` directly.

## Additional Resources

- [Use Cases](https://github.com/Bdaya-Dev/redirect/blob/main/docs/USE_CASES.md) — Comprehensive platform-specific examples
- [Example App](https://github.com/Bdaya-Dev/redirect/tree/main/packages/redirect/example) — Runnable Flutter demo
- [API Reference](https://pub.dev/documentation/redirect/latest/) — Generated dartdoc

## License

MIT — see [LICENSE](https://github.com/Bdaya-Dev/redirect/blob/main/LICENSE) for details.

---

<p align="center">
  Built with 💙 by <a href="https://github.com/Bdaya-Dev">Bdaya Dev</a>
</p>
