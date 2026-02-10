<p align="center">
  <a href="https://github.com/Bdaya-Dev/redirect">
    <img src="https://raw.githubusercontent.com/Bdaya-Dev/redirect/main/logo.svg" alt="redirect logo" width="64" height="64">
  </a>
</p>

# redirect_example

Demonstrates how to use the [`redirect`](https://pub.dev/packages/redirect) plugin for redirect-based flows across all supported platforms.

## Running the Example

```bash
# From the workspace root
cd packages/redirect/example

# Run on your platform
flutter run -d windows
flutter run -d macos
flutter run -d linux
flutter run -d chrome
flutter run -d android
flutter run -d ios
```

## Features Demonstrated

### Cross-Platform Features

- **`runRedirect()`** - Execute a redirect flow and wait for the callback

### Core Options (`RedirectOptions`)

| Option            | Description                                                 |
| ----------------- | ----------------------------------------------------------- |
| `timeout`         | Maximum time to wait for callback (cancels if exceeded)     |
| `preferEphemeral` | Use private/incognito browsing when available               |

### Web-Specific Options (`WebRedirectOptions`)

When running on web, additional options are available:

| Option            | Description                                                 |
| ----------------- | ----------------------------------------------------------- |
| **Popup Window**  | Opens a centered popup (default). Customize width/height.   |
| **New Tab**       | Opens in a new browser tab                                  |
| **Same Page**     | Navigates the current page away (returns `RedirectPending`) |
| **Hidden Iframe** | For silent refresh (may be blocked by CSP)                  |

### Result Types

| Type                | Description                                                  |
| ------------------- | ------------------------------------------------------------ |
| `RedirectSuccess`   | Contains the callback URI with all query parameters          |
| `RedirectCancelled` | User closed the popup/window or timeout occurred             |
| `RedirectPending`   | Redirect initiated but result arrives later (same-page mode) |
| `RedirectFailure`   | An error occurred (contains error and optional stack trace)  |

## Testing the Redirect Flow

The example uses httpbin.org to simulate a redirect (OAuth is a common use case):

- **Desktop/Mobile**: Redirects to `myapp://callback?code=test123`
- **Web**: Redirects to `callback.html`; the Service Worker broadcasts the result

## Platform Configuration

The `myapp://` custom URL scheme is pre-configured:

- **Android**: [AndroidManifest.xml](android/app/src/main/AndroidManifest.xml)
- **iOS**: [Info.plist](ios/Runner/Info.plist) (`CFBundleURLTypes`)
- **macOS**: [Info.plist](macos/Runner/Info.plist) (`CFBundleURLTypes`)
- **Windows/Linux**: Uses loopback HTTP server (no URL scheme needed)
- **Web**: Uses [callback.html](web/callback.html) and the Service Worker
