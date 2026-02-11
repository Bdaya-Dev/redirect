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

### Platform-Specific Ephemeral Sessions

`preferEphemeral` is available on `AndroidRedirectOptions` (Ephemeral Custom Tabs, Chrome 136+) and `IosRedirectOptions` / `MacosRedirectOptions` (private ASWebAuthenticationSession).

### Web-Specific Options (`WebRedirectOptions`)

When running on web, additional options are available:

| Option            | Description                                                 |
| ----------------- | ----------------------------------------------------------- |
| **Popup Window**  | Opens a centered popup (default). Customize width/height.   |
| **New Tab**       | Opens in a new browser tab                                  |
| **Same Page**     | Navigates the current page away (returns `RedirectPending`) |
| **Iframe**        | Opens in an iframe (hidden by default, may be blocked by CSP) |

### Result Types

| Type                | Description                                                  |
| ------------------- | ------------------------------------------------------------ |
| `RedirectSuccess`   | Contains the callback URI with all query parameters          |
| `RedirectCancelled` | User closed the popup/window or timeout occurred             |
| `RedirectPending`   | Redirect initiated but result arrives later (same-page mode) |
| `RedirectFailure`   | An error occurred (contains error and optional stack trace)  |

## Testing the Redirect Flow

The example uses httpbin.org to simulate a redirect:

- **Desktop/Mobile**: Redirects to `myapp://callback?code=test123`
- **Web**: Redirects to the bundled `redirect_callback.html` asset; the callback script broadcasts the result

## Platform Configuration

The `myapp://` custom URL scheme is pre-configured:

- **Android**: [AndroidManifest.xml](android/app/src/main/AndroidManifest.xml)
- **iOS**: [Info.plist](ios/Runner/Info.plist) (`CFBundleURLTypes`)
- **macOS**: [Info.plist](macos/Runner/Info.plist) (`CFBundleURLTypes`)
- **Windows/Linux**: Uses loopback HTTP server (no URL scheme needed)
- **Web**: Uses the bundled `redirect_callback.html` asset from the `redirect_web` package (no manual setup)
