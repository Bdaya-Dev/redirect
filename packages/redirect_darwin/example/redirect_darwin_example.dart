/// Example demonstrating redirect_darwin usage.
///
/// This is the shared iOS/macOS implementation of the redirect plugin
/// using ASWebAuthenticationSession for secure redirect flows.
/// Typically used through the `redirect` package which automatically
/// selects the correct platform implementation.
///
/// ```dart
/// import 'package:redirect/redirect.dart';
///
/// final redirect = Redirect();
/// final handle = redirect.run(
///   url: Uri.parse('https://example.com/authorize'),
///   callbackUrlScheme: 'myapp',
/// );
/// final result = await handle.result;
/// ```
///
/// To use ephemeral sessions (no shared cookies):
///
/// ```dart
/// final handle = redirect.run(
///   url: authUrl,
///   callbackUrlScheme: 'myapp',
///   options: RedirectOptions(
///     platformOptions: {
///       IosRedirectOptions.key: IosRedirectOptions(
///         callback: CallbackConfig.customScheme('myapp'),
///         preferEphemeral: true,
///       ),
///     },
///   ),
/// );
/// ```
library;
