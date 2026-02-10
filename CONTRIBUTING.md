# Contributing

Thanks for contributing to redirect. This guide covers developer-only details.

## Repo layout

- packages/redirect - Flutter public API
- packages/redirect_core - shared types
- packages/redirect_platform_interface - platform interface
- packages/redirect_android - Android implementation (Pigeon)
- packages/redirect_darwin - iOS/macOS implementation (Pigeon)
- packages/redirect_desktop - desktop implementation
- packages/redirect_web - Flutter web wrapper
- packages/redirect_web_core - pure Dart web implementation
- packages/redirect_io - IO implementation

## Prerequisites

- Flutter SDK (stable)
- Dart SDK (matches Flutter)
- Chrome (for browser tests)
- [melos](https://melos.invertase.dev) globally activated
- Optional: chromedriver for Flutter web integration tests

```sh
dart pub global activate melos
```

## Bootstrap

```sh
melos bootstrap
```

## Formatting and analysis

```sh
melos run format:fix
melos run analyze
```

## Tests

Run all tests (VM + Chrome + Flutter):

```sh
melos run test
```

Run by category:

```sh
melos run test:dart           # All Dart VM tests
melos run test:dart:chrome    # All Dart browser tests (Chrome)
melos run test:flutter        # All Flutter tests
```

Run a single package directly:

```sh
cd packages/redirect
flutter test
```

### redirect_web_core tests

Each suite has its own melos script. Chrome must be installed for browser tests.

| Script | Environment | What it covers |
|--------|-------------|----------------|
| `test:web-assets:chrome` | Chrome | Executes `callbackJs` and `serviceWorkerJs` via `eval` — BroadcastChannel delivery, channel registration, fetch handler routing, `_scheme` override, `window.close()` scheduling, error tolerance |
| `test:jaspr` | VM | Jaspr component rendering (`testComponents`) and SSR (`testServer`) |
| `test:web-integration` | Chrome | Full redirect flows — BroadcastChannel, localStorage, iframes, popups, concurrent handles, end-to-end `handleCallback` |

Run any of them:

```sh
melos run test:web-assets:chrome
melos run test:jaspr
melos run test:web-integration
```

Or run all redirect_web_core tests at once:

```sh
melos run test:dart           # VM suites
melos run test:dart:chrome    # browser suites
```

### Flutter web integration tests

Requires chromedriver:

```sh
cd packages/redirect/example
chromedriver --port=4444
flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/redirect_web_integration_test.dart \
  -d web-server
```

Note: Browser and Flutter web tests cannot run on the Dart VM. Use `-p chrome`
or a web device.

## Web asset setup (required for web flows)

The web implementation relies on BroadcastChannel to deliver callback URLs.
This requires a Service Worker hosted at a real same-origin URL. Package
assets cannot be auto-copied to the web root.

Copy assets into your app's web/ directory:

```sh
dart run redirect_web_core:setup
```

This writes:

- web/redirect_sw.js

Then enable auto-registration in your `WebRedirectOptions`:

```dart
WebRedirectOptions(
  callbackPath: '/callback.html',
  autoRegisterServiceWorker: true,
)
```

The Service Worker is registered automatically on first redirect call.

## Fallback (no Service Worker)

If you cannot use a Service Worker, run the setup with `--with-callback`:

```sh
dart run redirect_web_core:setup --with-callback
```

Include the script on your callback page:

```html
<script src="redirect_callback.js"></script>
```

Or call from a Dart callback page:

```dart
RedirectWeb.handleCallback(Uri.base);
```

## Multi-handle support

All web flows create unique BroadcastChannel names per handle. Do not assume
only one handle is active. Tests should verify concurrent handle behavior.

## Pigeon regeneration

If you change Pigeon definitions:

```sh
cd packages/redirect_android
dart run pigeon --input pigeons/messages.dart

cd ../redirect_darwin
dart run pigeon --input pigeons/messages.dart
```

## Commit guidelines

- Keep changes focused and small
- Update tests when behavior changes
- Add or update docs for any developer workflow changes

## Questions

Open an issue or discussion on GitHub if you are unsure about any change.
