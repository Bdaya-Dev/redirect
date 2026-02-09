<p align="center">
  <a href="https://github.com/Bdaya-Dev/redirect">
    <img src="https://raw.githubusercontent.com/Bdaya-Dev/redirect/main/logo.svg" alt="redirect logo" width="64" height="64">
  </a>
</p>

# redirect_darwin

[![pub](https://img.shields.io/pub/v/redirect_darwin.svg)](https://pub.dev/packages/redirect_darwin)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![style: very good analysis](https://img.shields.io/badge/style-very_good_analysis-B22C89.svg)](https://pub.dev/packages/very_good_analysis)

The **iOS & macOS** implementation of the [`redirect`](https://pub.dev/packages/redirect) plugin. Uses `ASWebAuthenticationSession` for secure, system-managed redirect flows.

## How it works

1. Opens the authorization URL using `ASWebAuthenticationSession`.
2. The system presents a secure browser sheet (iOS) or window (macOS).
3. Intercepts the callback URL matching `callbackUrlScheme`.
4. Returns the callback URI as a `RedirectSuccess`.

## Usage

This package is [endorsed](https://docs.flutter.dev/packages-and-plugins/developing-packages#endorsed-federated-plugin) and will be automatically included when you depend on `redirect` in a Flutter project targeting iOS or macOS.

```yaml
# Just add the main package — this is included automatically
dependencies:
  redirect: ^0.1.0
```

## Platform Configuration

For custom URL schemes, register your scheme in `Info.plist`:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>myapp</string>
        </array>
    </dict>
</array>
```

## Options

- **`preferEphemeral: true`** — Sets `prefersEphemeralWebBrowserSession` on the session, preventing cookie/session sharing with Safari.

## License

MIT — see [LICENSE](https://github.com/Bdaya-Dev/redirect/blob/main/LICENSE).
