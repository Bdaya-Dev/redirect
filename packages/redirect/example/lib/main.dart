import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:redirect/redirect.dart';

void main() => runApp(const MyApp());

/// Builds the test redirect URL.
///
/// On web, uses an HTTP callback via callback.html since browsers
/// can't handle custom URL schemes. On other platforms, uses myapp://.
String _buildTestRedirectUrl({String code = 'test123'}) {
  if (kIsWeb) {
    final origin = Uri.base.origin;
    final callbackUrl = Uri.encodeComponent(
      '$origin/callback.html?code=$code&_scheme=myapp',
    );
    return 'https://httpbin.org/redirect-to'
        '?url=$callbackUrl&status_code=302';
  }
  return 'https://httpbin.org/redirect-to'
      '?url=myapp%3A%2F%2Fcallback%3Fcode%3D$code&status_code=302';
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Redirect Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

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

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _urlController = TextEditingController();
  final _schemeController = TextEditingController(text: 'myapp');

  /// All active + completed redirect handles.
  final List<_HandleEntry> _handles = [];

  int _handleCounter = 0;

  // Core options
  bool _preferEphemeral = false;
  int _timeoutSeconds = 120;

  // Web-specific options
  WebRedirectMode _webMode = WebRedirectMode.popup;
  int _popupWidth = 500;
  int _popupHeight = 700;

  @override
  void initState() {
    super.initState();
    _urlController.text = _buildTestRedirectUrl();
  }

  @override
  void dispose() {
    _urlController.dispose();
    _schemeController.dispose();
    super.dispose();
  }

  bool get _hasActiveHandles => _handles.any((entry) => !entry.isComplete);

  Future<void> _runRedirect() async {
    final url = Uri.tryParse(_urlController.text.trim());
    final scheme = _schemeController.text.trim();

    if (url == null) {
      _showError('Invalid URL');
      return;
    }

    if (scheme.isEmpty) {
      _showError('Callback scheme is required');
      return;
    }

    _handleCounter++;
    final label = 'Handle #$_handleCounter';

    try {
      final handle = runRedirect(
        url: url,
        callbackUrlScheme: scheme,
        options: RedirectOptions(
          timeout: Duration(seconds: _timeoutSeconds),
          preferEphemeral: _preferEphemeral,
          platformOptions: {
            if (kIsWeb)
              WebRedirectOptions.key: WebRedirectOptions(
                mode: _webMode,
                popupWidth: _popupWidth,
                popupHeight: _popupHeight,
                callbackPath: '/callback.html',
                autoRegisterServiceWorker: true,
              ),
          },
        ),
      );

      final entry = _HandleEntry(handle: handle, label: label);
      setState(() => _handles.add(entry));

      // Await result asynchronously — doesn't block launching more handles.
      final result = await handle.result;
      if (!mounted) return;
      setState(() => entry.result = result);
    } on Exception catch (e) {
      if (!mounted) return;
      final failEntry = _HandleEntry(
        handle: RedirectHandle(
          url: url,
          callbackUrlScheme: scheme,
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
    // The awaiter in _runRedirect will update the entry when the
    // cancel completes.
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
      _handles.removeWhere((entry) => entry.isComplete);
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

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
            _buildInfoCard(),
            const SizedBox(height: 16),

            // URL input
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: 'Authorization URL',
                border: OutlineInputBorder(),
                helperText: 'The URL to redirect to (e.g., sign-in or consent)',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),

            // Callback scheme
            TextField(
              controller: _schemeController,
              decoration: const InputDecoration(
                labelText: 'Callback URL Scheme',
                border: OutlineInputBorder(),
                helperText: 'Custom URL scheme to intercept (e.g., myapp)',
              ),
            ),
            const SizedBox(height: 16),

            _buildCoreOptionsCard(),
            const SizedBox(height: 16),

            if (kIsWeb) ...[
              _buildWebOptionsCard(),
              const SizedBox(height: 16),
            ],

            _buildActionButtons(),

            if (_handles.isNotEmpty) ...[
              const SizedBox(height: 24),
              _buildHandlesList(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Test Redirect Flow',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    _urlController.text = _buildTestRedirectUrl();
                  },
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Reset URL'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              kIsWeb
                  ? 'Uses httpbin.org to simulate a redirect. '
                        'The callback goes to callback.html which '
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

  Widget _buildCoreOptionsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.settings,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Core Options',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('Prefer Ephemeral Session'),
              subtitle: const Text(
                'Use private browsing mode when available',
              ),
              value: _preferEphemeral,
              onChanged: (v) {
                setState(() => _preferEphemeral = v);
              },
            ),
            ListTile(
              title: const Text('Timeout'),
              subtitle: Text('$_timeoutSeconds seconds'),
              trailing: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 200),
                child: Slider(
                  value: _timeoutSeconds.toDouble(),
                  min: 10,
                  max: 300,
                  divisions: 29,
                  label: '$_timeoutSeconds s',
                  onChanged: (v) {
                    setState(
                      () => _timeoutSeconds = v.round(),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWebOptionsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.web,
                  size: 20,
                  color: Theme.of(context).colorScheme.secondary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Web-Specific Options',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Redirect strategy
            Text(
              'Redirect Strategy',
              style: Theme.of(context).textTheme.titleSmall,
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
                  value: WebRedirectMode.hiddenIframe,
                  label: Text('Iframe'),
                  icon: Icon(Icons.visibility_off),
                ),
              ],
              selected: {_webMode},
              onSelectionChanged: (v) {
                setState(() => _webMode = v.first);
              },
            ),
            const SizedBox(height: 8),
            Text(
              switch (_webMode) {
                WebRedirectMode.popup => 'Opens a centered popup window.',
                WebRedirectMode.newTab => 'Opens in a new browser tab.',
                WebRedirectMode.samePage =>
                  'Navigates current page (returns Pending).',
                WebRedirectMode.hiddenIframe =>
                  'Silent refresh via hidden iframe.',
              },
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.secondary,
              ),
            ),

            // Popup dimensions
            if (_webMode == WebRedirectMode.popup) ...[
              const Divider(height: 24),
              Text(
                'Popup Dimensions',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Width: $_popupWidth px'),
                        Slider(
                          value: _popupWidth.toDouble(),
                          min: 300,
                          max: 800,
                          divisions: 10,
                          onChanged: (v) {
                            setState(
                              () => _popupWidth = v.round(),
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
                        Text('Height: $_popupHeight px'),
                        Slider(
                          value: _popupHeight.toDouble(),
                          min: 400,
                          max: 900,
                          divisions: 10,
                          onChanged: (v) {
                            setState(
                              () => _popupHeight = v.round(),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],

            // Same-page warning
            if (_webMode == WebRedirectMode.samePage) ...[
              const Divider(height: 24),
              _buildInfoBanner(
                color: Colors.orange,
                icon: Icons.warning_amber,
                text:
                    'Same-page mode navigates away from this '
                    'app. The result will be RedirectPending.',
              ),
            ],

            // Hidden iframe note
            if (_webMode == WebRedirectMode.hiddenIframe) ...[
              const Divider(height: 24),
              _buildInfoBanner(
                color: Colors.blue,
                icon: Icons.info,
                text:
                    'Hidden iframe is for silent refresh. '
                    'Many providers block this with '
                    'X-Frame-Options.',
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBanner({
    required Color color,
    required IconData icon,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
        ),
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

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: _runRedirect,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Run Redirect'),
          ),
        ),
        if (_hasActiveHandles) ...[
          const SizedBox(width: 8),
          FilledButton.tonalIcon(
            onPressed: _cancelAllHandles,
            icon: const Icon(Icons.cancel),
            label: const Text('Cancel All'),
          ),
        ],
      ],
    );
  }

  /// Displays all handles (active + completed) in a list.
  Widget _buildHandlesList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            'Handles (${_handles.length})',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        ..._handles.reversed.map(_buildHandleCard),
      ],
    );
  }

  Widget _buildHandleCard(_HandleEntry entry) {
    final result = entry.result;

    if (result == null) {
      // Active / in-progress
      return Card(
        child: ListTile(
          leading: const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          title: Text(entry.label),
          subtitle: Text(
            entry.handle.url.host,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: IconButton(
            icon: const Icon(Icons.cancel_outlined),
            tooltip: 'Cancel',
            onPressed: () => _cancelHandle(entry),
          ),
        ),
      );
    }

    return _buildResultCard(entry.label, result);
  }

  Widget _buildResultCard(String label, RedirectResult result) {
    return switch (result) {
      RedirectSuccess(:final uri) => _ResultCard(
        title: '$label — Success',
        color: Colors.green,
        icon: Icons.check_circle,
        children: [
          _ResultRow('Scheme', uri.scheme),
          _ResultRow('Host', uri.host),
          _ResultRow(
            'Path',
            uri.path.isEmpty ? '/' : uri.path,
          ),
          const Divider(),
          Text(
            'Query Parameters:',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          ...uri.queryParameters.entries.map(
            (e) => _ResultRow(
              e.key,
              e.value,
              canCopy: true,
            ),
          ),
          const SizedBox(height: 8),
          _ResultRow(
            'Full URI',
            uri.toString(),
            canCopy: true,
          ),
        ],
      ),
      RedirectCancelled() => _ResultCard(
        title: '$label — Cancelled',
        color: Colors.orange,
        icon: Icons.cancel,
        children: const [
          Text(
            'The redirect was cancelled by user or '
            'timed out.',
          ),
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
          _ResultRow(
            'Error',
            error.toString(),
            canCopy: true,
          ),
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
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
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
                  Clipboard.setData(
                    ClipboardData(text: value),
                  ),
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
