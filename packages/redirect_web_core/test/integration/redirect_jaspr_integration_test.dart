@TestOn('vm')
library;

// Jaspr integration tests for redirect_web_core.
//
// Demonstrates how redirect_web_core integrates with Jaspr — a pure Dart
// web framework. Uses jaspr_test's `testComponents` to verify component
// rendering and interaction with all redirect result types.
//
// The component accepts a `RedirectHandler` (from redirect_core), making it
// testable with a mock handler in jaspr_test's simulated environment.
// The real browser-level redirect logic is covered by the companion
// redirect_web_integration_test.dart (dart test -p chrome).
//
// Run with:
//   cd packages/redirect_web_core
//   dart test test/integration/redirect_jaspr_integration_test.dart
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_test/jaspr_test.dart';
import 'package:redirect_core/redirect_core.dart';

// ─────────────────────────────────────────────────
// Jaspr component that drives a redirect flow
// ─────────────────────────────────────────────────

/// A Jaspr component that shows how to integrate any `RedirectHandler`
/// (including `RedirectWeb` from redirect_web_core) into a Jaspr app.
class RedirectDemo extends StatefulComponent {
  const RedirectDemo({
    required this.handler,
    required this.redirectUrl,
    this.callbackUrlScheme = 'myapp',
    this.options = const RedirectOptions(),
    super.key,
  });

  final RedirectHandler handler;
  final Uri redirectUrl;
  final String callbackUrlScheme;
  final RedirectOptions options;

  @override
  State<RedirectDemo> createState() => _RedirectDemoState();
}

class _RedirectDemoState extends State<RedirectDemo> {
  String _status = 'idle';
  String _detail = '';
  RedirectHandle? _activeHandle;

  Future<void> _startRedirect() async {
    setState(() {
      _status = 'loading';
      _detail = '';
    });

    _activeHandle = component.handler.run(
      url: component.redirectUrl,
      callbackUrlScheme: component.callbackUrlScheme,
      options: component.options,
    );

    final result = await _activeHandle!.result;

    setState(() {
      switch (result) {
        case RedirectSuccess(:final uri):
          _status = 'success';
          _detail = uri.toString();
        case RedirectCancelled():
          _status = 'cancelled';
          _detail = 'User dismissed or timed out';
        case RedirectFailure(:final error):
          _status = 'error';
          _detail = error.toString();
        case RedirectPending():
          _status = 'pending';
          _detail = 'Waiting for callback';
      }
    });
  }

  Future<void> _cancelRedirect() async {
    await _activeHandle?.cancel();
  }

  @override
  Component build(BuildContext context) {
    return div([
      p([Component.text('Status: $_status')]),
      if (_detail.isNotEmpty) p([Component.text('Detail: $_detail')]),
      button(
        const [Component.text('Start Redirect')],
        id: 'start-btn',
        onClick: _startRedirect,
      ),
      button(
        const [Component.text('Cancel')],
        id: 'cancel-btn',
        onClick: _cancelRedirect,
      ),
    ], id: 'redirect-demo');
  }
}

// ─────────────────────────────────────────────────
// Mock redirect handler for simulated testing
// ─────────────────────────────────────────────────

class _MockRedirectHandler implements RedirectHandler {
  _MockRedirectHandler({
    RedirectResult? result,
    this.delay = Duration.zero,
  }) : result = result ?? const RedirectCancelled();

  final RedirectResult result;
  final Duration delay;
  int runCount = 0;
  bool cancelCalled = false;

  @override
  RedirectHandle run({
    required Uri url,
    required String callbackUrlScheme,
    RedirectOptions options = const RedirectOptions(),
  }) {
    runCount++;

    Future<RedirectResult> doRun() async {
      if (delay > Duration.zero) {
        await Future<void>.delayed(delay);
      }
      return result;
    }

    return RedirectHandle(
      url: url,
      callbackUrlScheme: callbackUrlScheme,
      options: options,
      result: doRun(),
      cancel: () async {
        cancelCalled = true;
      },
    );
  }
}

// ─────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────

void main() {
  group('RedirectDemo component >', () {
    testComponents('renders idle state initially', (tester) async {
      tester.pumpComponent(
        RedirectDemo(
          handler: _MockRedirectHandler(),
          redirectUrl: Uri.parse('https://example.com/auth'),
        ),
      );

      // Should show idle status
      expect(find.text('Status: idle'), findsOneComponent);

      // Should have both buttons
      expect(find.tag('button'), findsNComponents(2));
    });

    testComponents('shows success after redirect completes', (tester) async {
      final handler = _MockRedirectHandler(
        result: RedirectSuccess(
          uri: Uri.parse('myapp://callback?code=auth_code_123'),
        ),
      );

      tester.pumpComponent(
        RedirectDemo(
          handler: handler,
          redirectUrl: Uri.parse('https://auth.example.com/authorize'),
        ),
      );

      // Click "Start Redirect"
      await tester.click(find.tag('button').first);

      // Status should transition to success
      expect(find.text('Status: success'), findsOneComponent);
      expect(
        find.text('Detail: myapp://callback?code=auth_code_123'),
        findsOneComponent,
      );
      expect(handler.runCount, equals(1));
    });

    testComponents('shows cancelled state', (tester) async {
      final handler = _MockRedirectHandler(
        result: const RedirectCancelled(),
      );

      tester.pumpComponent(
        RedirectDemo(
          handler: handler,
          redirectUrl: Uri.parse('https://example.com/auth'),
        ),
      );

      await tester.click(find.tag('button').first);

      expect(find.text('Status: cancelled'), findsOneComponent);
      expect(
        find.text('Detail: User dismissed or timed out'),
        findsOneComponent,
      );
    });

    testComponents('shows error state', (tester) async {
      final handler = _MockRedirectHandler(
        result: RedirectFailure(
          error: Exception('Network error'),
        ),
      );

      tester.pumpComponent(
        RedirectDemo(
          handler: handler,
          redirectUrl: Uri.parse('https://example.com/auth'),
        ),
      );

      await tester.click(find.tag('button').first);

      expect(find.text('Status: error'), findsOneComponent);
      expect(
        find.text('Detail: Exception: Network error'),
        findsOneComponent,
      );
    });

    testComponents('shows pending state for same-page redirects', (
      tester,
    ) async {
      final handler = _MockRedirectHandler(
        result: const RedirectPending(),
      );

      tester.pumpComponent(
        RedirectDemo(
          handler: handler,
          redirectUrl: Uri.parse('https://example.com/auth'),
        ),
      );

      await tester.click(find.tag('button').first);

      expect(find.text('Status: pending'), findsOneComponent);
      expect(
        find.text('Detail: Waiting for callback'),
        findsOneComponent,
      );
    });

    testComponents('passes correct URL and scheme to handler', (tester) async {
      final handler = _MockRedirectHandler(
        result: RedirectSuccess(
          uri: Uri.parse('custom://done'),
        ),
      );

      final authUrl = Uri.parse(
        'https://auth.example.com/authorize?client_id=app&scope=openid',
      );

      tester.pumpComponent(
        RedirectDemo(
          handler: handler,
          redirectUrl: authUrl,
          callbackUrlScheme: 'custom',
        ),
      );

      await tester.click(find.tag('button').first);

      expect(handler.runCount, equals(1));
      expect(find.text('Status: success'), findsOneComponent);
    });

    testComponents('forwards options to handler', (tester) async {
      final handler = _MockRedirectHandler(
        result: const RedirectCancelled(),
      );

      tester.pumpComponent(
        RedirectDemo(
          handler: handler,
          redirectUrl: Uri.parse('https://example.com/auth'),
          options: const RedirectOptions(
            timeout: Duration(seconds: 30),
            preferEphemeral: true,
          ),
        ),
      );

      await tester.click(find.tag('button').first);

      // Handler was called with the component's options
      expect(handler.runCount, equals(1));
    });

    testComponents('cancel button invokes handler cancel', (tester) async {
      final handler = _MockRedirectHandler(
        result: const RedirectCancelled(),
        delay: const Duration(seconds: 10),
      );

      tester.pumpComponent(
        RedirectDemo(
          handler: handler,
          redirectUrl: Uri.parse('https://example.com/auth'),
        ),
      );

      // Start redirect (it will delay for 10s)
      await tester.click(find.tag('button').first);

      // Click cancel
      await tester.click(find.tag('button').last);

      expect(handler.cancelCalled, isTrue);
    });

    testComponents('can run multiple redirects in sequence', (tester) async {
      final handler = _MockRedirectHandler(
        result: RedirectSuccess(
          uri: Uri.parse('myapp://callback?attempt=1'),
        ),
      );

      tester.pumpComponent(
        RedirectDemo(
          handler: handler,
          redirectUrl: Uri.parse('https://example.com/auth'),
        ),
      );

      // First redirect
      await tester.click(find.tag('button').first);
      expect(find.text('Status: success'), findsOneComponent);
      expect(handler.runCount, equals(1));

      // Second redirect
      await tester.click(find.tag('button').first);
      expect(find.text('Status: success'), findsOneComponent);
      expect(handler.runCount, equals(2));
    });

    testComponents('component renders all redirect result types', (
      tester,
    ) async {
      // Verify each RedirectResult enum value can be rendered
      for (final MapEntry(key: name, value: result) in {
        'success': RedirectSuccess(uri: Uri.parse('myapp://cb')),
        'cancelled': const RedirectCancelled(),
        'pending': const RedirectPending(),
        'error': RedirectFailure(error: Exception('fail')),
      }.entries) {
        final handler = _MockRedirectHandler(result: result);

        tester.pumpComponent(
          RedirectDemo(
            handler: handler,
            redirectUrl: Uri.parse('https://example.com'),
          ),
        );

        await tester.click(find.tag('button').first);
        expect(
          find.text('Status: $name'),
          findsOneComponent,
          reason:
              'Expected status "$name" for result type '
              '${result.runtimeType}',
        );
      }
    });
  });
}
