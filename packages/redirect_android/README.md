<p align="center">
  <a href="https://github.com/Bdaya-Dev/redirect">
    <img src="https://raw.githubusercontent.com/Bdaya-Dev/redirect/main/logo.svg" alt="redirect logo" width="64" height="64">
  </a>
</p>

# redirect_android

[![pub](https://img.shields.io/pub/v/redirect_android.svg)](https://pub.dev/packages/redirect_android)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![style: very good analysis](https://img.shields.io/badge/style-very_good_analysis-B22C89.svg)](https://pub.dev/packages/very_good_analysis)

The **Android** implementation of the [`redirect`](https://pub.dev/packages/redirect) plugin. Uses Chrome Custom Tabs for a secure, native redirect experience.

## How it works

1. Opens the authorization URL in a [Chrome Custom Tab](https://developer.chrome.com/docs/android/custom-tabs/).
2. Intercepts the callback via an intent filter matching `callbackUrlScheme`.
3. Returns the callback URI as a `RedirectSuccess`.

## Usage

This package is [endorsed](https://docs.flutter.dev/packages-and-plugins/developing-packages#endorsed-federated-plugin), which means you can simply use `redirect` normally. This package will be automatically included in your app when you do.

```yaml
# Just add the main package — this is included automatically
dependencies:
  redirect: ^0.1.0
```

## Platform Configuration

Add an intent filter for your callback scheme to `AndroidManifest.xml`:

```xml
<activity
    android:name="dev.bdaya.redirect_android.RedirectActivity"
    android:exported="true">
    <intent-filter>
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <data android:scheme="myapp" />
    </intent-filter>
</activity>
```

## License

MIT — see [LICENSE](https://github.com/Bdaya-Dev/redirect/blob/main/LICENSE).