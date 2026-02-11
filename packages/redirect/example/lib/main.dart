import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:redirect/redirect.dart';

import 'package:redirect_example/iframe_panel_stub.dart'
    if (dart.library.js_interop) 'package:redirect_example/iframe_panel_web.dart'
    as iframe_panel;
import 'package:redirect_example/resume_pending_stub.dart'
    if (dart.library.js_interop) 'package:redirect_example/resume_pending_web.dart'
    as pending;

void main() {
  // Check for a pending same-page redirect before running the app.
  // This must happen early, before Flutter's router processes the URL.
  final pendingResult = pending.resumePending();
  runApp(MyApp(pendingResult: pendingResult));
}

/// Whether the current platform uses Custom Tabs / intent filters.
bool get _isAndroid =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

/// Whether the current platform uses ASWebAuthenticationSession (iOS/macOS).
bool get _isDarwin =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS);

/// Returns the default test URL shown in the text field.
///
/// This is only used for display — the actual URL passed to `runRedirect` is
/// built by [constructRedirectUrl] inside `_buildRedirectConfig`.
String _defaultTestUrl({String code = 'test123'}) {
  if (kIsWeb) {
    final callbackUrl = WebRedirectOptions.resolveDefaultCallbackUrl()!.replace(
      queryParameters: {'code': code},
    );
    final encodedCallback = Uri.encodeComponent(callbackUrl.toString());
    return 'https://httpbin.org/redirect-to'
        '?url=$encodedCallback&status_code=302';
  }
  return 'https://httpbin.org/redirect-to'
      '?url=myapp%3A%2F%2Fcallback%3Fcode%3D$code&status_code=302';
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.pendingResult});

  /// If non-null, the app was reloaded from a same-page redirect.
  final RedirectResult? pendingResult;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Redirect Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      home: HomePage(pendingResult: pendingResult),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Data models
// ─────────────────────────────────────────────────────────────────────────────

/// Tracks a single redirect handle and its result.
class _HandleEntry {
  _HandleEntry({
    required this.handle,
    required this.label,
    this.result,
  });

  final RedirectHandle handle;
  final String label;
  RedirectResult? result;
  bool get isComplete => result != null;
}

/// Core redirect options that apply to all platforms.
class _CoreConfig {
  const _CoreConfig({
    this.timeoutSeconds = 120,
  });

  final int? timeoutSeconds;

  _CoreConfig copyWith({
    int? Function()? timeoutSeconds,
  }) {
    return _CoreConfig(
      timeoutSeconds: timeoutSeconds != null
          ? timeoutSeconds()
          : this.timeoutSeconds,
    );
  }
}

/// Android-specific UI config.
class _AndroidConfig {
  const _AndroidConfig({
    this.scheme = 'myapp',
    this.useCustomTabs = true,
    this.showTitle = false,
    this.preferEphemeral = false,
  });

  final String scheme;
  final bool useCustomTabs;
  final bool showTitle;
  final bool preferEphemeral;

  _AndroidConfig copyWith({
    String? scheme,
    bool? useCustomTabs,
    bool? showTitle,
    bool? preferEphemeral,
  }) {
    return _AndroidConfig(
      scheme: scheme ?? this.scheme,
      useCustomTabs: useCustomTabs ?? this.useCustomTabs,
      showTitle: showTitle ?? this.showTitle,
      preferEphemeral: preferEphemeral ?? this.preferEphemeral,
    );
  }
}

/// Darwin (iOS / macOS) UI config.
class _DarwinConfig {
  const _DarwinConfig({
    this.useCustomScheme = true,
    this.scheme = 'myapp',
    this.httpsHost = 'example.com',
    this.httpsPath = '/callback',
    this.preferEphemeral = false,
  });

  final bool useCustomScheme;
  final String scheme;
  final String httpsHost;
  final String httpsPath;
  final bool preferEphemeral;

  _DarwinConfig copyWith({
    bool? useCustomScheme,
    String? scheme,
    String? httpsHost,
    String? httpsPath,
    bool? preferEphemeral,
  }) {
    return _DarwinConfig(
      useCustomScheme: useCustomScheme ?? this.useCustomScheme,
      scheme: scheme ?? this.scheme,
      httpsHost: httpsHost ?? this.httpsHost,
      httpsPath: httpsPath ?? this.httpsPath,
      preferEphemeral: preferEphemeral ?? this.preferEphemeral,
    );
  }

  CallbackConfig toCallbackConfig() {
    if (useCustomScheme) return CallbackConfig.customScheme(scheme);
    return CallbackConfig.https(host: httpsHost, path: httpsPath);
  }
}

/// Web-specific UI config.
class _WebConfig {
  const _WebConfig({
    this.mode = WebRedirectMode.popup,
    this.popupWidth = 500,
    this.popupHeight = 700,
    this.showIframePanel = false,
  });

  final WebRedirectMode mode;
  final int popupWidth;
  final int popupHeight;
  final bool showIframePanel;

  _WebConfig copyWith({
    WebRedirectMode? mode,
    int? popupWidth,
    int? popupHeight,
    bool? showIframePanel,
  }) {
    return _WebConfig(
      mode: mode ?? this.mode,
      popupWidth: popupWidth ?? this.popupWidth,
      popupHeight: popupHeight ?? this.popupHeight,
      showIframePanel: showIframePanel ?? this.showIframePanel,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HomePage — thin orchestrator, delegates UI to child widgets
// ─────────────────────────────────────────────────────────────────────────────

class HomePage extends StatefulWidget {
  const HomePage({super.key, this.pendingResult});

  /// If non-null, the app was reloaded from a same-page redirect.
  final RedirectResult? pendingResult;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _urlController = TextEditingController();

  /// All active + completed redirect handles.
  final List<_HandleEntry> _handles = [];
  int _handleCounter = 0;

  // ── Platform configs ──────────────────────────────────────────
  var _core = const _CoreConfig();
  var _android = const _AndroidConfig();
  var _darwin = const _DarwinConfig();
  var _web = const _WebConfig();

  @override
  void initState() {
    super.initState();
    _urlController.text = _defaultTestUrl();

    if (widget.pendingResult != null) {
      _handleCounter++;
      final entry = _HandleEntry(
        handle: RedirectHandle(
          url: Uri.base,
          result: Future.value(widget.pendingResult),
          cancel: () async {},
        ),
        label: 'Handle #$_handleCounter (resumed)',
        result: widget.pendingResult,
      );
      _handles.add(entry);
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  bool get _hasActiveHandles => _handles.any((e) => !e.isComplete);

  // ── Actions ───────────────────────────────────────────────────

  /// Uses [constructRedirectUrl] to build the URL and options for
  /// the current platform, then launches the redirect.
  Future<void> _runRedirect() async {
    final inputUrl = Uri.tryParse(_urlController.text.trim());
    if (inputUrl == null) {
      _showError('Invalid URL');
      return;
    }

    _handleCounter++;
    final label = 'Handle #$_handleCounter';

    try {
      final (:url, :options) = _buildRedirectConfig(inputUrl);

      final handle = runRedirect(url: url, options: options);

      final entry = _HandleEntry(handle: handle, label: label);
      setState(() => _handles.add(entry));

      final result = await handle.result;
      if (!mounted) return;
      setState(() => entry.result = result);
    } on Exception catch (e) {
      if (!mounted) return;
      final failEntry = _HandleEntry(
        handle: RedirectHandle(
          url: inputUrl,
          result: Future.value(
            RedirectFailure(error: e, stackTrace: StackTrace.current),
          ),
          cancel: () async {},
        ),
        label: label,
        result: RedirectFailure(error: e, stackTrace: StackTrace.current),
      );
      setState(() => _handles.add(failEntry));
    }
  }

  Future<void> _cancelHandle(_HandleEntry entry) async {
    await entry.handle.cancel();
  }

  Future<void> _cancelAllHandles() async {
    for (final entry in _handles) {
      if (!entry.isComplete) {
        await entry.handle.cancel();
      }
    }
  }

  void _clearCompleted() {
    setState(() {
      _handles.removeWhere((e) => e.isComplete);
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  // ── Redirect config builder (uses constructRedirectUrl) ──────

  ({Uri url, RedirectOptions options}) _buildRedirectConfig(Uri inputUrl) {
    return constructRedirectUrl(
      timeout: _core.timeoutSeconds != null
          ? Duration(seconds: _core.timeoutSeconds!)
          : null,
      fallback: (_) => RedirectUrlConfig(url: inputUrl),
      onAndroid: (_) => RedirectUrlConfig(
        url: inputUrl,
        platformOptions: {
          AndroidRedirectOptions.key: AndroidRedirectOptions(
            callbackUrlScheme: _android.scheme,
            preferEphemeral: _android.preferEphemeral,
            useCustomTabs: _android.useCustomTabs,
            showTitle: _android.showTitle,
          ),
        },
      ),
      onDarwin: (platform) => RedirectUrlConfig(
        url: inputUrl,
        platformOptions: {
          if (platform == RedirectPlatformType.ios)
            IosRedirectOptions.key: IosRedirectOptions(
              callback: _darwin.toCallbackConfig(),
              preferEphemeral: _darwin.preferEphemeral,
            )
          else
            MacosRedirectOptions.key: MacosRedirectOptions(
              callback: _darwin.toCallbackConfig(),
              preferEphemeral: _darwin.preferEphemeral,
            ),
        },
      ),
      onDesktop: (_) => RedirectUrlConfig(
        url: inputUrl,
        platformOptions: {
          WindowsRedirectOptions.key: const WindowsRedirectOptions(),
          LinuxRedirectOptions.key: const LinuxRedirectOptions(),
        },
      ),
      onWeb: (_) => RedirectUrlConfig(
        url: inputUrl,
        platformOptions: {
          WebRedirectOptions.key: WebRedirectOptions(
            mode: _web.mode,
            popupOptions: PopupOptions(
              width: _web.popupWidth,
              height: _web.popupHeight,
            ),
            iframeOptions: const IframeOptions(
              hidden: false,
              parentSelector: '#iframe-container-body',
              style: 'width: 100%; height: 100%; border: none;',
            ),
          ),
        },
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Redirect Plugin'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (_handles.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              tooltip: 'Clear completed',
              onPressed: _clearCompleted,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _InfoCard(
              onResetUrl: () {
                _urlController.text = _defaultTestUrl();
              },
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: 'Redirect URL',
                border: OutlineInputBorder(),
                helperText: 'The URL to redirect to (e.g., sign-in or consent)',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),

            _CoreOptionsCard(
              config: _core,
              onChanged: (v) => setState(() => _core = v),
            ),
            const SizedBox(height: 16),

            if (_isAndroid) ...[
              _AndroidOptionsCard(
                config: _android,
                onChanged: (v) => setState(() => _android = v),
              ),
              const SizedBox(height: 16),
            ],

            if (_isDarwin) ...[
              _DarwinOptionsCard(
                config: _darwin,
                onChanged: (v) => setState(() => _darwin = v),
              ),
              const SizedBox(height: 16),
            ],

            if (kIsWeb) ...[
              _WebOptionsCard(
                config: _web,
                onChanged: (v) {
                  setState(() => _web = v);
                  iframe_panel.setIframePanelVisible(v.showIframePanel);
                },
              ),
              const SizedBox(height: 16),
            ],

            _ActionButtons(
              onRun: _runRedirect,
              onCancelAll: _hasActiveHandles ? _cancelAllHandles : null,
            ),

            if (_handles.isNotEmpty) ...[
              const SizedBox(height: 24),
              _HandlesList(
                handles: _handles,
                onCancel: _cancelHandle,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Extracted child widgets — each only rebuilds when its own props change.
// Prefer StatelessWidget over helper methods per official guidance.
// ─────────────────────────────────────────────────────────────────────────────

/// A reusable card header row with an icon, title, and optional trailing.
class _CardHeader extends StatelessWidget {
  const _CardHeader({
    required this.icon,
    required this.title,
    this.iconColor,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final Color? iconColor;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final color = iconColor ?? Theme.of(context).colorScheme.primary;
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// A colored info banner with an icon and text.
class _InfoBanner extends StatelessWidget {
  const _InfoBanner({
    required this.color,
    required this.icon,
    required this.text,
  });

  final Color color;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Info card
// ─────────────────────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.onResetUrl});

  final VoidCallback onResetUrl;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CardHeader(
              icon: Icons.info_outline,
              title: 'Test Redirect Flow',
              trailing: TextButton.icon(
                onPressed: onResetUrl,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Reset URL'),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              kIsWeb
                  ? 'Uses httpbin.org to simulate a redirect. '
                        'The callback goes to the bundled '
                        'redirect_callback.html asset which '
                        'sends the result back via BroadcastChannel.\n\n'
                        'You can launch multiple concurrent handles '
                        'to test parallel redirect flows.'
                  : 'Uses httpbin.org to simulate a redirect '
                        'back to the myapp:// custom URL scheme.\n\n'
                        'Multiple handles can run concurrently — each '
                        'has its own isolated channel.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Core options card
// ─────────────────────────────────────────────────────────────────────────────

class _CoreOptionsCard extends StatelessWidget {
  const _CoreOptionsCard({
    required this.config,
    required this.onChanged,
  });

  final _CoreConfig config;
  final ValueChanged<_CoreConfig> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _CardHeader(icon: Icons.settings, title: 'Core Options'),
            const SizedBox(height: 8),
            ListTile(
              title: const Text('Timeout'),
              subtitle: Text(
                config.timeoutSeconds != null
                    ? '${config.timeoutSeconds} seconds'
                    : 'Disabled',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (config.timeoutSeconds != null)
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 200),
                      child: Slider(
                        value: config.timeoutSeconds!.toDouble(),
                        min: 10,
                        max: 300,
                        divisions: 29,
                        label: '${config.timeoutSeconds} s',
                        onChanged: (v) {
                          onChanged(
                            config.copyWith(
                              timeoutSeconds: () => v.round(),
                            ),
                          );
                        },
                      ),
                    ),
                  Switch(
                    value: config.timeoutSeconds != null,
                    onChanged: (v) {
                      onChanged(
                        config.copyWith(
                          timeoutSeconds: () => v ? 120 : null,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Android options card
// ─────────────────────────────────────────────────────────────────────────────

class _AndroidOptionsCard extends StatefulWidget {
  const _AndroidOptionsCard({
    required this.config,
    required this.onChanged,
  });

  final _AndroidConfig config;
  final ValueChanged<_AndroidConfig> onChanged;

  @override
  State<_AndroidOptionsCard> createState() => _AndroidOptionsCardState();
}

class _AndroidOptionsCardState extends State<_AndroidOptionsCard> {
  late final TextEditingController _schemeController;

  @override
  void initState() {
    super.initState();
    _schemeController = TextEditingController(text: widget.config.scheme);
  }

  @override
  void dispose() {
    _schemeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _CardHeader(icon: Icons.android, title: 'Android Options'),
            const SizedBox(height: 12),
            TextField(
              controller: _schemeController,
              decoration: const InputDecoration(
                labelText: 'Callback URL Scheme',
                border: OutlineInputBorder(),
                helperText:
                    'Must match <data android:scheme="..."/> '
                    'in AndroidManifest.xml',
              ),
              onChanged: (v) {
                widget.onChanged(widget.config.copyWith(scheme: v));
              },
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('Use Custom Tabs'),
              subtitle: const Text('Chrome Custom Tabs vs plain intent'),
              value: widget.config.useCustomTabs,
              onChanged: (v) {
                widget.onChanged(widget.config.copyWith(useCustomTabs: v));
              },
            ),
            SwitchListTile(
              title: const Text('Show Title'),
              subtitle: const Text('Display page title in toolbar'),
              value: widget.config.showTitle,
              onChanged: (v) {
                widget.onChanged(widget.config.copyWith(showTitle: v));
              },
            ),
            SwitchListTile(
              title: const Text('Prefer Ephemeral Session'),
              subtitle: const Text(
                'Use Ephemeral Custom Tabs (Chrome 136+)',
              ),
              value: widget.config.preferEphemeral,
              onChanged: (v) {
                widget.onChanged(
                  widget.config.copyWith(preferEphemeral: v),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Darwin (iOS / macOS) options card
// ─────────────────────────────────────────────────────────────────────────────

class _DarwinOptionsCard extends StatefulWidget {
  const _DarwinOptionsCard({
    required this.config,
    required this.onChanged,
  });

  final _DarwinConfig config;
  final ValueChanged<_DarwinConfig> onChanged;

  @override
  State<_DarwinOptionsCard> createState() => _DarwinOptionsCardState();
}

class _DarwinOptionsCardState extends State<_DarwinOptionsCard> {
  late final TextEditingController _schemeController;
  late final TextEditingController _hostController;
  late final TextEditingController _pathController;

  @override
  void initState() {
    super.initState();
    _schemeController = TextEditingController(text: widget.config.scheme);
    _hostController = TextEditingController(text: widget.config.httpsHost);
    _pathController = TextEditingController(text: widget.config.httpsPath);
  }

  @override
  void dispose() {
    _schemeController.dispose();
    _hostController.dispose();
    _pathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final platformLabel = defaultTargetPlatform == TargetPlatform.iOS
        ? 'iOS'
        : 'macOS';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CardHeader(
              icon: Icons.apple,
              title: '$platformLabel Options',
            ),
            const SizedBox(height: 12),
            Text(
              'Callback Matching',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: true,
                  label: Text('Custom Scheme'),
                  icon: Icon(Icons.link),
                ),
                ButtonSegment(
                  value: false,
                  label: Text('HTTPS'),
                  icon: Icon(Icons.lock),
                ),
              ],
              selected: {widget.config.useCustomScheme},
              onSelectionChanged: (v) {
                widget.onChanged(
                  widget.config.copyWith(useCustomScheme: v.first),
                );
              },
            ),
            const SizedBox(height: 12),
            if (widget.config.useCustomScheme)
              TextField(
                controller: _schemeController,
                decoration: const InputDecoration(
                  labelText: 'URL Scheme',
                  border: OutlineInputBorder(),
                  helperText: 'e.g., myapp',
                ),
                onChanged: (v) {
                  widget.onChanged(widget.config.copyWith(scheme: v));
                },
              )
            else ...[
              TextField(
                controller: _hostController,
                decoration: const InputDecoration(
                  labelText: 'Host',
                  border: OutlineInputBorder(),
                  helperText: 'e.g., example.com',
                ),
                onChanged: (v) {
                  widget.onChanged(widget.config.copyWith(httpsHost: v));
                },
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _pathController,
                decoration: const InputDecoration(
                  labelText: 'Path',
                  border: OutlineInputBorder(),
                  helperText: 'e.g., /callback',
                ),
                onChanged: (v) {
                  widget.onChanged(widget.config.copyWith(httpsPath: v));
                },
              ),
            ],
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('Prefer Ephemeral Session'),
              subtitle: const Text(
                'Private session (no shared cookies with Safari)',
              ),
              value: widget.config.preferEphemeral,
              onChanged: (v) {
                widget.onChanged(
                  widget.config.copyWith(preferEphemeral: v),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Web options card
// ─────────────────────────────────────────────────────────────────────────────

class _WebOptionsCard extends StatelessWidget {
  const _WebOptionsCard({
    required this.config,
    required this.onChanged,
  });

  final _WebConfig config;
  final ValueChanged<_WebConfig> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CardHeader(
              icon: Icons.web,
              title: 'Web-Specific Options',
              iconColor: theme.colorScheme.secondary,
            ),
            const SizedBox(height: 12),

            // Redirect strategy
            Text(
              'Redirect Strategy',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            SegmentedButton<WebRedirectMode>(
              segments: const [
                ButtonSegment(
                  value: WebRedirectMode.popup,
                  label: Text('Popup'),
                  icon: Icon(Icons.open_in_new),
                ),
                ButtonSegment(
                  value: WebRedirectMode.newTab,
                  label: Text('New Tab'),
                  icon: Icon(Icons.tab),
                ),
                ButtonSegment(
                  value: WebRedirectMode.samePage,
                  label: Text('Same Page'),
                  icon: Icon(Icons.arrow_forward),
                ),
                ButtonSegment(
                  value: WebRedirectMode.iframe,
                  label: Text('Iframe'),
                  icon: Icon(Icons.web_asset),
                ),
              ],
              selected: {config.mode},
              onSelectionChanged: (v) {
                onChanged(config.copyWith(mode: v.first));
              },
            ),
            const SizedBox(height: 8),
            Text(
              switch (config.mode) {
                WebRedirectMode.popup => 'Opens a centered popup window.',
                WebRedirectMode.newTab => 'Opens in a new browser tab.',
                WebRedirectMode.samePage =>
                  'Navigates current page (returns Pending).',
                WebRedirectMode.iframe =>
                  'Opens in an iframe in the side panel.',
              },
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.secondary,
              ),
            ),

            // Popup dimensions
            if (config.mode == WebRedirectMode.popup) ...[
              const Divider(height: 24),
              Text(
                'Popup Dimensions',
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Width: ${config.popupWidth} px'),
                        Slider(
                          value: config.popupWidth.toDouble(),
                          min: 300,
                          max: 800,
                          divisions: 10,
                          onChanged: (v) {
                            onChanged(
                              config.copyWith(popupWidth: v.round()),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Height: ${config.popupHeight} px'),
                        Slider(
                          value: config.popupHeight.toDouble(),
                          min: 400,
                          max: 900,
                          divisions: 10,
                          onChanged: (v) {
                            onChanged(
                              config.copyWith(popupHeight: v.round()),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],

            // Same-page info
            if (config.mode == WebRedirectMode.samePage) ...[
              const Divider(height: 24),
              const _InfoBanner(
                color: Colors.orange,
                icon: Icons.warning_amber,
                text:
                    'Same-page mode navigates away from this app. '
                    'The server redirects to the bundled callback page, '
                    'which stores the result in sessionStorage and '
                    'navigates back to the app. Call '
                    'resumePendingRedirect() on startup to read the '
                    'stored result.',
              ),
            ],

            // Iframe panel toggle
            if (config.mode == WebRedirectMode.iframe) ...[
              const Divider(height: 24),
              Row(
                children: [
                  Text(
                    'Iframe Panel',
                    style: theme.textTheme.titleSmall,
                  ),
                  const Spacer(),
                  Switch(
                    value: config.showIframePanel,
                    onChanged: (v) {
                      onChanged(config.copyWith(showIframePanel: v));
                    },
                  ),
                ],
              ),
            ],

            // Iframe note
            if (config.mode == WebRedirectMode.iframe) ...[
              const Divider(height: 24),
              const _InfoBanner(
                color: Colors.blue,
                icon: Icons.info,
                text:
                    'Iframe mode (visible in side panel). '
                    'Many servers block iframe embedding '
                    'via X-Frame-Options or CSP.',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Action buttons
// ─────────────────────────────────────────────────────────────────────────────

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({
    required this.onRun,
    this.onCancelAll,
  });

  final VoidCallback onRun;
  final VoidCallback? onCancelAll;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: onRun,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Run Redirect'),
          ),
        ),
        if (onCancelAll != null) ...[
          const SizedBox(width: 8),
          FilledButton.tonalIcon(
            onPressed: onCancelAll,
            icon: const Icon(Icons.cancel),
            label: const Text('Cancel All'),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Handles list
// ─────────────────────────────────────────────────────────────────────────────

class _HandlesList extends StatelessWidget {
  const _HandlesList({
    required this.handles,
    required this.onCancel,
  });

  final List<_HandleEntry> handles;
  final ValueChanged<_HandleEntry> onCancel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            'Handles (${handles.length})',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        ...handles.reversed.map(
          (entry) => _HandleCard(entry: entry, onCancel: onCancel),
        ),
      ],
    );
  }
}

class _HandleCard extends StatelessWidget {
  const _HandleCard({
    required this.entry,
    required this.onCancel,
  });

  final _HandleEntry entry;
  final ValueChanged<_HandleEntry> onCancel;

  @override
  Widget build(BuildContext context) {
    final result = entry.result;

    if (result == null) {
      return Card(
        child: ListTile(
          leading: const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          title: Text(entry.label),
          subtitle: Text(
            '${entry.handle.url.host}  •  ${entry.handle.nonce}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: IconButton(
            icon: const Icon(Icons.cancel_outlined),
            tooltip: 'Cancel',
            onPressed: () => onCancel(entry),
          ),
        ),
      );
    }

    return _ResultCardFromResult(label: entry.label, result: result);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Result display widgets
// ─────────────────────────────────────────────────────────────────────────────

class _ResultCardFromResult extends StatelessWidget {
  const _ResultCardFromResult({
    required this.label,
    required this.result,
  });

  final String label;
  final RedirectResult result;

  @override
  Widget build(BuildContext context) {
    return switch (result) {
      RedirectSuccess(:final uri) => _ResultCard(
        title: '$label — Success',
        color: Colors.green,
        icon: Icons.check_circle,
        children: [
          _ResultRow('Scheme', uri.scheme),
          _ResultRow('Host', uri.host),
          _ResultRow('Path', uri.path.isEmpty ? '/' : uri.path),
          const Divider(),
          Text(
            'Query Parameters:',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          ...uri.queryParameters.entries.map(
            (e) => _ResultRow(e.key, e.value, canCopy: true),
          ),
          const SizedBox(height: 8),
          _ResultRow('Full URI', uri.toString(), canCopy: true),
        ],
      ),
      RedirectCancelled() => _ResultCard(
        title: '$label — Cancelled',
        color: Colors.orange,
        icon: Icons.cancel,
        children: const [
          Text('The redirect was cancelled by user or timed out.'),
        ],
      ),
      RedirectPending() => _ResultCard(
        title: '$label — Pending',
        color: Colors.blue,
        icon: Icons.hourglass_empty,
        children: const [
          Text(
            'Redirect initiated but result will arrive '
            'later. This typically occurs with same-page '
            'redirects on web.',
          ),
        ],
      ),
      RedirectFailure(:final error, :final stackTrace) => _ResultCard(
        title: '$label — Failed',
        color: Colors.red,
        icon: Icons.error,
        children: [
          _ResultRow('Error', error.toString(), canCopy: true),
          if (stackTrace != null && kDebugMode) ...[
            const SizedBox(height: 8),
            ExpansionTile(
              title: const Text('Stack Trace'),
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  color: Colors.grey[200],
                  child: SelectableText(
                    stackTrace.toString(),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    };
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.title,
    required this.color,
    required this.icon,
    required this.children,
  });

  final String title;
  final Color color;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow(
    this.label,
    this.value, {
    this.canCopy = false,
  });

  final String label;
  final String value;
  final bool canCopy;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: TextStyle(
                fontFamily: 'monospace',
                color: Colors.grey[700],
              ),
            ),
          ),
          if (canCopy)
            IconButton(
              icon: const Icon(Icons.copy, size: 16),
              onPressed: () {
                unawaited(
                  Clipboard.setData(ClipboardData(text: value)),
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Copied: $label'),
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
              tooltip: 'Copy',
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }
}
