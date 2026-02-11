<p align="center">
  <a href="https://github.com/Bdaya-Dev/redirect">
    <img src="https://raw.githubusercontent.com/Bdaya-Dev/redirect/main/logo.svg" alt="redirect logo" width="64" height="64">
  </a>
</p>

# redirect_web_core

[![pub](https://img.shields.io/pub/v/redirect_web_core.svg)](https://pub.dev/packages/redirect_web_core)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![style: very good analysis](https://img.shields.io/badge/style-very_good_analysis-B22C89.svg)](https://pub.dev/packages/very_good_analysis)

Pure Dart web implementation of redirect-based flows. **No Flutter dependency** — works with any Dart web framework (Jaspr, vanilla `dart:js_interop`, etc.).

## Features

| Mode | Description |
|------|-------------|
| `WebRedirectMode.popup` | Centered popup window (customizable size) |
| `WebRedirectMode.newTab` | New browser tab via `BroadcastChannel` |
| `WebRedirectMode.samePage` | Same-tab navigation (returns `RedirectPending`) |
| `WebRedirectMode.iframe` | Opens in an iframe (hidden by default, configurable) |

## Installation

```yaml
dependencies:
  redirect_web_core: ^0.1.0
```

## Usage

```dart
import 'package:redirect_web_core/redirect_web_core.dart';

final handler = RedirectWeb();

final handle = handler.run(
  url: Uri.parse('https://example.com/start?...'),
  callbackUrlScheme: 'https',
  options: RedirectOptions(
    platformOptions: {
      WebRedirectOptions.key: WebRedirectOptions(
        mode: WebRedirectMode.popup,
      ),
    },
  ),
);

final result = await handle.result;
```

## Web Setup

Run `dart run redirect_web_core:setup` to copy the callback relay script
to your `web/` directory. Then include it on your callback page:

```html
<script src="redirect_callback.js"></script>
```

> **Note:** If you're using Flutter, use [`redirect`](https://pub.dev/packages/redirect) instead — it automatically delegates to this package on web.

## License

MIT — see [LICENSE](https://github.com/Bdaya-Dev/redirect/blob/main/LICENSE).
