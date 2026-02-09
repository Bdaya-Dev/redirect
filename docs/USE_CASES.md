# Redirect — Use Cases by Platform

This document describes every use case supported by the `redirect` family of packages, organized by runtime target.

---

## Package Map

| Package | Depends on Flutter? | Purpose |
|---|---|---|
| `redirect` | Yes | Flutter federated plugin — single import for all Flutter targets |
| `redirect_core` | No | Shared types & `RedirectHandler` interface (pure Dart) |
| `redirect_platform_interface` | Yes | Flutter platform interface (extends `redirect_core`) |
| `redirect_android` | Yes | Android implementation (Custom Tabs) |
| `redirect_darwin` | Yes | iOS & macOS implementation (ASWebAuthenticationSession) |
| `redirect_desktop` | Yes | Linux & Windows implementation (loopback HTTP server) |
| `redirect_web` | Yes | Flutter web plugin (thin wrapper around `redirect_web_core`) |
| `redirect_web_core` | No | Pure Dart web implementation (popup, tab, iframe, same-page) |
| `redirect_cli` | No | Pure Dart CLI implementation (loopback HTTP server + system browser) |

---

## Shared Concepts

Every use case revolves around the same core flow:

1. Call `run()` with a **URL** (e.g. an OAuth authorization endpoint) and a **callback URL scheme**.
2. Receive a `RedirectHandle` **synchronously** (critical on web to avoid popup blockers).
3. `await handle.result` to get a sealed `RedirectResult`:

```dart
switch (result) {
  case RedirectSuccess(:final uri):
    // The callback URI with query parameters (code, state, etc.)
  case RedirectCancelled():
    // User dismissed the flow or timeout elapsed
  case RedirectPending():
    // Web same-page mode only — page navigated away
  case RedirectFailure(:final error, :final stackTrace):
    // Something went wrong
}
```

### Common Options (`RedirectOptions`)

| Option | Type | Default | Description |
|---|---|---|---|
| `timeout` | `Duration?` | `null` | Max wait time; completes with `RedirectCancelled` on expiry |
| `preferEphemeral` | `bool` | `false` | Private browser session (no shared cookies / SSO) |
| `platformOptions` | `Map<String, Object>` | `{}` | Platform-specific option objects keyed by platform identifier |

### Result Metadata

Every `RedirectResult` subtype carries an optional `metadata` map (`Map<String, dynamic>`) for arbitrary key-value data attached by platform implementations or callers.

---

## 1. Flutter Web

**Package:** `redirect` (automatically delegates to `redirect_web` → `redirect_web_core`)

**Callback scheme:** `https` (same-origin redirect back to your app)

### 1.1 OAuth / OIDC Authorization Code Flow (Popup)

The default and most common mode. A popup window opens the authorization URL; the callback is received via `BroadcastChannel`.

```dart
import 'package:redirect/redirect.dart';

void onLoginTap() {
  // MUST be called synchronously inside a user-gesture handler
  // to avoid popup blockers.
  final handle = runRedirect(
    url: Uri.parse('https://auth.example.com/authorize?client_id=...&redirect_uri=https://myapp.com/callback'),
    callbackUrlScheme: 'https',
  );

  handle.result.then((result) {
    switch (result) {
      case RedirectSuccess(:final uri):
        final code = uri.queryParameters['code'];
        // Exchange code for tokens
      case RedirectCancelled():
        // User closed the popup
      case RedirectFailure(:final error):
        // Show error
      case RedirectPending():
        break; // Not used in popup mode
    }
  });
}
```

### 1.2 OAuth in a New Tab

Opens a full browser tab instead of a sized popup. Useful when the auth provider renders poorly in small windows.

```dart
final handle = runRedirect(
  url: authUrl,
  callbackUrlScheme: 'https',
  options: RedirectOptions(
    platformOptions: {
      WebRedirectOptions.key: WebRedirectOptions(
        mode: WebRedirectMode.newTab,
      ),
    },
  ),
);
```

### 1.3 Same-Page Redirect

Navigates the current page to the auth URL. The provider redirects back to your callback URL, replacing the page entirely.

**Important:** This returns `RedirectPending` immediately. You must handle the callback yourself when the page reloads.

```dart
import 'package:redirect/redirect.dart';

// Step 1 — initiate (on your login page)
void onLoginTap() {
  // Persist any state you need before navigating away
  // window.sessionStorage.setItem('my_state', stateValue);

  final handle = runRedirect(
    url: authUrl,
    callbackUrlScheme: 'https',
    options: RedirectOptions(
      platformOptions: {
        WebRedirectOptions.key: WebRedirectOptions(
          mode: WebRedirectMode.samePage,
        ),
      },
    ),
  );

  // handle.result completes with RedirectPending — the page navigates away
}

// Step 2 — handle the callback (on your callback page or same page)
// Call RedirectWeb.resumePendingRedirect() on reload to get the result
```

### 1.4 Silent Token Refresh (Hidden Iframe)

Performs a background token refresh without any visible UI. Requires the auth server to support `prompt=none` and to allow iframe embedding.

```dart
final handle = runRedirect(
  url: Uri.parse('https://auth.example.com/authorize?prompt=none&...'),
  callbackUrlScheme: 'https',
  options: RedirectOptions(
    timeout: Duration(seconds: 10),
    platformOptions: {
      WebRedirectOptions.key: WebRedirectOptions(
        mode: WebRedirectMode.hiddenIframe,
      ),
    },
  ),
);

final result = await handle.result;
// RedirectSuccess → extract new tokens
// RedirectCancelled → timeout, user needs interactive login
// RedirectFailure → iframe blocked or auth error
```

### 1.5 Custom Popup Dimensions

```dart
WebRedirectOptions(
  mode: WebRedirectMode.popup,
  popupWidth: 600,
  popupHeight: 800,
  popupLeft: 100,
  popupTop: 50,
)
```

### 1.6 Custom BroadcastChannel Name

Useful when running multiple redirect flows or when the default channel name (`redirect_{scheme}`) conflicts.

```dart
WebRedirectOptions(
  broadcastChannelName: 'my_custom_channel',
)
```

### 1.7 Payment Gateway Redirect (Web)

Any URL-based flow that eventually redirects back to your origin works identically:

```dart
final handle = runRedirect(
  url: Uri.parse('https://payments.stripe.com/checkout/session_xyz'),
  callbackUrlScheme: 'https', // redirects back to https://myapp.com/payment/complete
);
```

---

## 2. Flutter Native (Android, iOS, macOS, Linux, Windows)

**Package:** `redirect` (automatically delegates to the correct platform package)

### Callback Schemes by Platform

| Platform | Mechanism | Typical Scheme |
|---|---|---|
| Android | Custom Tabs + Intent filter | `myapp` (custom) or `https` (App Links) |
| iOS | ASWebAuthenticationSession | `myapp` (custom) or `https` (Universal Links) |
| macOS | ASWebAuthenticationSession | `myapp` (custom) or `https` (Universal Links) |
| Linux | Loopback HTTP server + system browser | `http` (loopback) |
| Windows | Loopback HTTP server + system browser | `http` (loopback) |

### 2.1 OAuth / OIDC Authorization Code Flow (Mobile)

```dart
import 'package:redirect/redirect.dart';

Future<void> login() async {
  final handle = runRedirect(
    url: Uri.parse(
      'https://auth.example.com/authorize'
      '?client_id=my_client'
      '&redirect_uri=myapp://callback'
      '&response_type=code'
      '&scope=openid profile',
    ),
    callbackUrlScheme: 'myapp',
  );

  final result = await handle.result;

  switch (result) {
    case RedirectSuccess(:final uri):
      final code = uri.queryParameters['code'];
      // Exchange code for tokens via your backend
    case RedirectCancelled():
      // User swiped away the in-app browser
    case RedirectFailure(:final error):
      // Handle error
    case RedirectPending():
      break; // Not used on native
  }
}
```

### 2.2 Ephemeral Session (No SSO)

Prevents the system browser from sharing cookies with the user's normal browsing session. Useful for "log in as different user" flows.

```dart
final handle = runRedirect(
  url: authUrl,
  callbackUrlScheme: 'myapp',
  options: RedirectOptions(preferEphemeral: true),
);
```

- **iOS/macOS:** Sets `prefersEphemeralWebBrowserSession = true` on `ASWebAuthenticationSession`.
- **Android:** Requests incognito mode in Custom Tabs (if supported).
- **Desktop:** No effect (loopback server is inherently stateless).

### 2.3 Universal Links / App Links (HTTPS Callback)

Use `https` as the callback scheme when your app is configured with Universal Links (iOS/macOS) or App Links (Android):

```dart
final handle = runRedirect(
  url: Uri.parse(
    'https://auth.example.com/authorize'
    '?redirect_uri=https://myapp.com/.well-known/callback',
  ),
  callbackUrlScheme: 'https',
);
```

### 2.4 Desktop OAuth (Linux / Windows)

On desktop, the plugin starts a loopback HTTP server (per [RFC 8252 §7.3](https://www.rfc-editor.org/rfc/rfc8252#section-7.3)) and opens the system browser:

```dart
final handle = runRedirect(
  url: Uri.parse(
    'https://auth.example.com/authorize'
    '?client_id=desktop_client'
    '&redirect_uri=http://localhost:0/callback' // port resolved at runtime
    '&response_type=code',
  ),
  callbackUrlScheme: 'http',
);
```

The `redirect_uri` sent to the auth server is constructed automatically by the desktop implementation with the actual port.

### 2.5 Payment Gateway Redirect (Native)

Works identically to OAuth — the user is shown a payment page and the provider redirects back to your app's custom scheme:

```dart
final handle = runRedirect(
  url: Uri.parse('https://checkout.stripe.com/pay/session_xyz'),
  callbackUrlScheme: 'myapp', // myapp://payment/complete?status=success
);
```

### 2.6 Timeout

Cancel the flow automatically after a duration:

```dart
final handle = runRedirect(
  url: authUrl,
  callbackUrlScheme: 'myapp',
  options: RedirectOptions(timeout: Duration(minutes: 5)),
);
// Completes with RedirectCancelled() after 5 minutes if no callback received
```

### 2.7 Programmatic Cancellation

```dart
final handle = runRedirect(
  url: authUrl,
  callbackUrlScheme: 'myapp',
);

// Later, e.g. on a "Cancel" button tap:
await handle.cancel();
// handle.result completes with RedirectCancelled()
```

---

## 3. Dart Web (Non-Flutter)

**Package:** `redirect_web_core` (no Flutter dependency)

Works with **any** Dart web framework — Jaspr, pure Dart, AngularDart, etc.

### 3.1 OAuth Popup

```dart
import 'package:redirect_web_core/redirect_web_core.dart';

final redirect = RedirectWeb();

void onLoginClick() {
  final handle = redirect.run(
    url: Uri.parse('https://auth.example.com/authorize?client_id=...'),
    callbackUrlScheme: 'https',
  );

  handle.result.then((result) {
    switch (result) {
      case RedirectSuccess(:final uri):
        final code = uri.queryParameters['code'];
        print('Authorization code: $code');
      case RedirectCancelled():
        print('User closed the popup');
      case RedirectFailure(:final error):
        print('Error: $error');
      case RedirectPending():
        break;
    }
  });
}
```

### 3.2 New Tab Mode

```dart
final redirect = RedirectWeb(
  defaultWebOptions: WebRedirectOptions(mode: WebRedirectMode.newTab),
);

final handle = redirect.run(
  url: authUrl,
  callbackUrlScheme: 'https',
);
```

### 3.3 Same-Page Redirect

```dart
final redirect = RedirectWeb();

// Initiate — page navigates away
final handle = redirect.runWithWebOptions(
  url: authUrl,
  callbackUrlScheme: 'https',
  webOptions: WebRedirectOptions(mode: WebRedirectMode.samePage),
);
// handle.result → RedirectPending

// On callback page load:
final result = RedirectWeb.resumePendingRedirect();
if (result != null) {
  switch (result) {
    case RedirectSuccess(:final uri):
      // Parse uri for code, state, etc.
      break;
    case _:
      // Handle failure
      break;
  }
}
```

### 3.4 Hidden Iframe (Silent Refresh)

```dart
final redirect = RedirectWeb();

final handle = redirect.runWithWebOptions(
  url: Uri.parse('https://auth.example.com/authorize?prompt=none&...'),
  callbackUrlScheme: 'https',
  options: RedirectOptions(timeout: Duration(seconds: 10)),
  webOptions: WebRedirectOptions(mode: WebRedirectMode.hiddenIframe),
);

final result = await handle.result;
```

### 3.5 Callback Page Setup

In most cases, **no JavaScript is needed on the callback page.** The opener
reads the callback URL directly from the popup/tab window via the Same-Origin
Policy. Your callback page just needs to *exist* — it can be plain HTML:

```html
<!DOCTYPE html>
<html><body><p>&#x2713; Complete. You can close this window.</p></body></html>
```

#### When do you need more?

If the external provider (auth server, payment gateway, etc.) sets a
`Cross-Origin-Opener-Policy` (COOP) header, the browser severs the opener's
reference to the popup. Two options:

##### Option A: Service Worker (COOP fast-path)

Register the Service Worker once at app startup. It broadcasts the callback
URL directly from the SW context via BroadcastChannel — no HTML served, no
callback page needed. Your own page (if any) still loads normally:

```dart
import 'package:redirect_web_core/redirect_web_core.dart';

void main() {
  RedirectWeb.registerServiceWorker(callbackPath: '/callback');

  // Use RedirectWeb as normal...
}
```

Copy `redirect_sw.js` from
`package:redirect_web_core/src/assets/redirect_sw.js` into your `web/` directory.

##### Option B: Script tag (COOP fallback)

Add `redirect_callback.js` to your callback page. It discovers all active
channels from `localStorage` and broadcasts via BroadcastChannel:

```html
<!DOCTYPE html>
<html><body>
  <p>&#x2713; Complete. You can close this window.</p>
  <script src="redirect_callback.js"></script>
</body></html>
```

Copy `redirect_callback.js` from
`package:redirect_web_core/src/assets/redirect_callback.js` into your `web/`
directory.

##### Option C: Dart callback page (full control)

```dart
import 'package:redirect_web_core/redirect_web_core.dart';

void main() {
  // Auto-discovers channels and broadcasts to all active operations.
  RedirectWeb.handleCallback(Uri.base);

  // Close this popup/tab
  RedirectWeb.closeWindow();
}
```

### 3.6 Per-Call Web Options via `platformOptions`

Instead of using `runWithWebOptions`, you can pass web options through the generic `platformOptions` map:

```dart
final handle = redirect.run(
  url: authUrl,
  callbackUrlScheme: 'https',
  options: RedirectOptions(
    platformOptions: {
      WebRedirectOptions.key: WebRedirectOptions(
        mode: WebRedirectMode.newTab,
        broadcastChannelName: 'my_channel',
      ),
    },
  ),
);
```

---

## 4. Dart CLI

**Package:** `redirect_cli` (no Flutter dependency)

Ideal for command-line tools, backend servers, development scripts, and any non-UI Dart application.

### How It Works

1. Starts a **loopback HTTP server** on `localhost` (per [RFC 8252](https://www.rfc-editor.org/rfc/rfc8252)).
2. Opens the **system browser** with the authorization URL. The `redirect_uri` query parameter is automatically rewritten to point to the loopback server.
3. Waits for the auth provider to redirect back to the loopback server.
4. Returns the callback URI as a `RedirectSuccess`.
5. Shows a styled HTML success/error page in the browser.

### 4.1 OAuth CLI Login

```dart
import 'package:redirect_cli/redirect_cli.dart';

void main() async {
  final redirect = RedirectCli();

  final handle = redirect.run(
    url: Uri.parse(
      'https://auth.example.com/authorize'
      '?client_id=cli_client'
      '&response_type=code'
      '&scope=openid',
    ),
    callbackUrlScheme: 'myapp',
    options: RedirectOptions(timeout: Duration(minutes: 2)),
  );

  print('Browser opened. Complete the login to continue...');

  final result = await handle.result;

  switch (result) {
    case RedirectSuccess(:final uri):
      final code = uri.queryParameters['code'];
      print('Authorization code: $code');
    case RedirectCancelled():
      print('Timed out or cancelled');
    case RedirectFailure(:final error):
      print('Error: $error');
    case RedirectPending():
      break; // Not used in CLI
  }
}
```

### 4.2 Fixed Port

Required when the auth provider only allows pre-registered redirect URIs with a specific port:

```dart
final redirect = RedirectCli(
  cliOptions: CliRedirectOptions(port: 8080),
);
// Redirect URI: http://localhost:8080/callback
```

### 4.3 Port Range

Try a range of ports; the first available one is used:

```dart
final redirect = RedirectCli(
  cliOptions: CliRedirectOptions(
    portRange: (start: 8080, end: 8090),
  ),
);
```

### 4.4 Auto Port (Default)

When neither `port` nor `portRange` is specified, an OS-assigned available port is used (port `0`).

### 4.5 Custom Callback Path

```dart
CliRedirectOptions(callbackPath: '/auth/callback')
// Redirect URI: http://localhost:{port}/auth/callback
```

### 4.6 Custom HTML Responses

Brand the success/error pages shown in the browser:

```dart
CliRedirectOptions(
  successHtml: '<html><body><h1>Logged in!</h1></body></html>',
  errorHtml: '<html><body><h1>Login failed: {{error}}</h1></body></html>',
)
```

The `{{error}}` placeholder in `errorHtml` is replaced with the HTML-escaped error string from the auth server.

### 4.7 Manual Browser Launch

Disable automatic browser opening — useful for headless environments or SSH sessions where you print the URL for the user to copy:

```dart
final redirect = RedirectCli(
  cliOptions: CliRedirectOptions(openBrowser: false),
);

final handle = redirect.run(
  url: authUrl,
  callbackUrlScheme: 'myapp',
);

print('Open this URL in your browser:');
print(redirect.callbackUrl); // available after run() starts the server
```

### 4.8 Per-Call CLI Options via `platformOptions`

```dart
final handle = redirect.run(
  url: authUrl,
  callbackUrlScheme: 'myapp',
  options: RedirectOptions(
    platformOptions: {
      CliRedirectOptions.key: CliRedirectOptions(
        port: 9090,
        openBrowser: false,
      ),
    },
  ),
);
```

### 4.9 Server-Side / Backend Token Exchange

A backend Dart server can use `redirect_cli` to initiate admin-consent or service-account
flows where a human must approve in a browser:

```dart
final redirect = RedirectCli(
  cliOptions: CliRedirectOptions(
    openBrowser: false, // server can't open a browser
    port: 3000,
  ),
);

final handle = redirect.run(
  url: adminConsentUrl,
  callbackUrlScheme: 'http',
);

print('Ask the admin to visit: $adminConsentUrl');

final result = await handle.result;
```

### 4.10 Authorization Error Handling

When the auth server returns an error response (e.g. `?error=access_denied`), the CLI handler:
- Shows the error HTML page in the browser.
- Completes with `RedirectFailure` containing an `AuthorizationException` with the `error` and optional `error_description` from the query parameters.

```dart
case RedirectFailure(:final error):
  if (error is AuthorizationException) {
    print('Auth error: ${error.error}');       // e.g. "access_denied"
    print('Description: ${error.description}'); // e.g. "User denied consent"
  }
```

---

## Summary Matrix

| Use Case | Flutter Web | Flutter Native | Dart Web | Dart CLI |
|---|:---:|:---:|:---:|:---:|
| OAuth / OIDC code flow | ✅ | ✅ | ✅ | ✅ |
| Payment gateway redirect | ✅ | ✅ | ✅ | — |
| Popup window | ✅ | — | ✅ | — |
| New tab | ✅ | — | ✅ | — |
| Same-page redirect | ✅ | — | ✅ | — |
| Hidden iframe (silent refresh) | ✅ | — | ✅ | — |
| System browser (Custom Tabs / ASWebAuthenticationSession) | — | ✅ (mobile) | — | — |
| Loopback HTTP server | — | ✅ (desktop) | — | ✅ |
| Ephemeral session | ✅ | ✅ | — | — |
| Timeout | ✅ | ✅ | ✅ | ✅ |
| Programmatic cancellation | ✅ | ✅ | ✅ | ✅ |
| Custom port / port range | — | — | — | ✅ |
| Custom HTML responses | — | — | — | ✅ |
| Manual browser launch | — | — | — | ✅ |
| Callback page handler | ✅ | — | ✅ | — |
| BroadcastChannel customization | ✅ | — | ✅ | — |
| Universal Links / App Links | — | ✅ | — | — |
