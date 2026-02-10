<p align="center">
  <a href="https://github.com/Bdaya-Dev/redirect">
    <img src="https://raw.githubusercontent.com/Bdaya-Dev/redirect/main/logo.svg" alt="redirect logo" width="64" height="64">
  </a>
</p>

# redirect_io

[![pub](https://img.shields.io/pub/v/redirect_io.svg)](https://pub.dev/packages/redirect_io)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![style: very good analysis](https://img.shields.io/badge/style-very_good_analysis-B22C89.svg)](https://pub.dev/packages/very_good_analysis)

Pure Dart IO implementation of redirect-based flows. Ideal for **command-line tools**, **servers**, **desktop apps**, and **non-Flutter** Dart applications.

## How it works

1. Starts a temporary loopback HTTP server on `127.0.0.1`.
2. Opens the authorization URL in the system's default browser.
3. Waits for the callback redirect to the loopback server.
4. Returns the callback URI as a `RedirectSuccess`.

## Installation

```yaml
dependencies:
  redirect_io: ^0.1.0
```

## Usage

```dart
import 'package:redirect_io/redirect_io.dart';

class MyRedirectIo extends RedirectIo {
  @override
  ServerRedirectOptions getOptions(RedirectOptions options) {
    return const ServerRedirectOptions();
  }
}

final handler = MyRedirectIo();

final handle = handler.run(
  url: Uri.parse('https://example.com/authorize?...'),
  callbackUrlScheme: 'http',
);

final result = await handle.result;

switch (result) {
  case RedirectSuccess(:final uri):
    print('Callback URI: $uri');
  case RedirectCancelled():
    print('Cancelled');
  case RedirectFailure(:final error):
    print('Error: $error');
  case RedirectPending():
    break;
}
```

See the [example](example/) for a complete working sample.

## License

MIT — see [LICENSE](https://github.com/Bdaya-Dev/redirect/blob/main/LICENSE).
