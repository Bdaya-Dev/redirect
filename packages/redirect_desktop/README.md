<p align="center">
  <a href="https://github.com/Bdaya-Dev/redirect">
    <img src="https://raw.githubusercontent.com/Bdaya-Dev/redirect/main/logo.svg" alt="redirect logo" width="64" height="64">
  </a>
</p>

# redirect_desktop

[![pub](https://img.shields.io/pub/v/redirect_desktop.svg)](https://pub.dev/packages/redirect_desktop)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![style: very good analysis](https://img.shields.io/badge/style-very_good_analysis-B22C89.svg)](https://pub.dev/packages/very_good_analysis)

The **Linux & Windows** implementation of the [`redirect`](https://pub.dev/packages/redirect) plugin. Uses a loopback HTTP server (per [RFC 8252 §7.3](https://datatracker.ietf.org/doc/html/rfc8252#section-7.3)) to capture redirect callbacks.

## How it works

1. Starts a temporary HTTP server on `127.0.0.1` with a random port.
2. Opens the authorization URL in the system's default browser.
3. Waits for the authorization server to redirect to `http://127.0.0.1:PORT/`.
4. Captures the callback URI and returns it as a `RedirectSuccess`.
5. Shuts down the temporary server.

## Usage

This package is [endorsed](https://docs.flutter.dev/packages-and-plugins/developing-packages#endorsed-federated-plugin) and will be automatically included when you depend on `redirect` in a Flutter project targeting Linux or Windows.

```yaml
# Just add the main package — this is included automatically
dependencies:
  redirect: ^0.1.0
```

No platform-specific configuration is needed — the loopback server handles everything.

## License

MIT — see [LICENSE](https://github.com/Bdaya-Dev/redirect/blob/main/LICENSE).
