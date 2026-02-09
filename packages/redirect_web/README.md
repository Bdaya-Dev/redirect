<p align="center">
  <a href="https://github.com/Bdaya-Dev/redirect">
    <img src="https://raw.githubusercontent.com/Bdaya-Dev/redirect/main/logo.svg" alt="redirect logo" width="64" height="64">
  </a>
</p>

# redirect_web

[![pub](https://img.shields.io/pub/v/redirect_web.svg)](https://pub.dev/packages/redirect_web)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![style: very good analysis](https://img.shields.io/badge/style-very_good_analysis-B22C89.svg)](https://pub.dev/packages/very_good_analysis)

The **Flutter web** implementation of the [`redirect`](https://pub.dev/packages/redirect) plugin. Thin wrapper around [`redirect_web_core`](https://pub.dev/packages/redirect_web_core).

## Supported Modes

| Mode | Description |
|------|-------------|
| `WebRedirectMode.popup` | Centered popup window (default) |
| `WebRedirectMode.newTab` | New browser tab |
| `WebRedirectMode.samePage` | Current-page navigation (returns `RedirectPending`) |
| `WebRedirectMode.hiddenIframe` | Hidden iframe for silent token refresh |

## Usage

This package is [endorsed](https://docs.flutter.dev/packages-and-plugins/developing-packages#endorsed-federated-plugin), which means you can simply use `redirect` normally. This package will be automatically included in your Flutter web app.

```yaml
# Just add the main package — this is included automatically
dependencies:
  redirect: ^0.1.0
```

For **non-Flutter** Dart web apps, use [`redirect_web_core`](https://pub.dev/packages/redirect_web_core) directly.

## License

MIT — see [LICENSE](https://github.com/Bdaya-Dev/redirect/blob/main/LICENSE).
