<p align="center">
  <a href="https://github.com/Bdaya-Dev/redirect">
    <img src="https://raw.githubusercontent.com/Bdaya-Dev/redirect/main/logo.svg" alt="redirect logo" width="64" height="64">
  </a>
</p>

# redirect_core

[![pub](https://img.shields.io/pub/v/redirect_core.svg)](https://pub.dev/packages/redirect_core)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![style: very good analysis](https://img.shields.io/badge/style-very_good_analysis-B22C89.svg)](https://pub.dev/packages/very_good_analysis)

Core types and interfaces for the [redirect](https://pub.dev/packages/redirect) family of packages. **Pure Dart** — no Flutter dependency.

## What's included

| Type | Description |
|------|-------------|
| `RedirectHandler` | Abstract interface that platform implementations must satisfy |
| `RedirectHandle` | Handle to a pending redirect (holds `result` future + `cancel()`) |
| `RedirectOptions` | Configuration: `timeout`, `preferEphemeral`, `platformOptions` |
| `RedirectResult` | Sealed class: `RedirectSuccess`, `RedirectCancelled`, `RedirectPending`, `RedirectFailure` |
| `WebRedirectMode` | Enum: `popup`, `newTab`, `samePage`, `hiddenIframe` |
| `WebRedirectOptions` | Web-specific configuration (popup size, iframe ID, etc.) |

## When to use this package

- You're **building a platform implementation** for `redirect`.
- You need the **shared types** in a pure Dart package (e.g. a backend, a shared library).
- You're writing code that is **platform-agnostic** and just needs the type definitions.

If you're building a Flutter app, use [`redirect`](https://pub.dev/packages/redirect) instead.
If you're building a CLI tool, use [`redirect_io`](https://pub.dev/packages/redirect_io).

## Installation

```yaml
dependencies:
  redirect_core: ^0.1.0
```

## Usage

```dart
import 'package:redirect_core/redirect_core.dart';

// Implement the RedirectHandler interface
class MyRedirectHandler implements RedirectHandler {
  @override
  RedirectHandle run({
    required Uri url,
    required String callbackUrlScheme,
    RedirectOptions options = const RedirectOptions(),
  }) {
    // Your platform-specific implementation
  }
}
```

## License

MIT — see [LICENSE](https://github.com/Bdaya-Dev/redirect/blob/main/LICENSE).
