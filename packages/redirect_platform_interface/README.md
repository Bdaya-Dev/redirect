<p align="center">
  <a href="https://github.com/Bdaya-Dev/redirect">
    <img src="https://raw.githubusercontent.com/Bdaya-Dev/redirect/main/logo.svg" alt="redirect logo" width="64" height="64">
  </a>
</p>

# redirect_platform_interface

[![pub](https://img.shields.io/pub/v/redirect_platform_interface.svg)](https://pub.dev/packages/redirect_platform_interface)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![style: very good analysis](https://img.shields.io/badge/style-very_good_analysis-B22C89.svg)](https://pub.dev/packages/very_good_analysis)

A common platform interface for the [`redirect`](https://pub.dev/packages/redirect) plugin.

This interface allows platform-specific implementations of the `redirect` plugin, as well as the plugin itself, to ensure they are supporting the same interface. It extends [`redirect_core`](https://pub.dev/packages/redirect_core) with Flutter's `PlatformInterface` verification.

## Usage

To implement a new platform-specific implementation of `redirect`, extend `RedirectPlatform` with an implementation that performs the platform-specific behavior:

```dart
import 'package:redirect_platform_interface/redirect_platform_interface.dart';

class MyPlatformRedirect extends RedirectPlatform {
  @override
  RedirectHandle run({
    required Uri url,
    required String callbackUrlScheme,
    RedirectOptions options = const RedirectOptions(),
  }) {
    // Platform-specific implementation
  }
}
```

Then register it:

```dart
RedirectPlatform.instance = MyPlatformRedirect();
```

## License

MIT — see [LICENSE](https://github.com/Bdaya-Dev/redirect/blob/main/LICENSE).