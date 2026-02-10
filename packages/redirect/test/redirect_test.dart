import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:redirect/redirect.dart';
import 'package:redirect_platform_interface/redirect_platform_interface.dart'
    as platform;

class MockRedirectPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements platform.RedirectPlatform {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockRedirectPlatform mockPlatform;

  setUpAll(() {
    registerFallbackValue(Uri());
    registerFallbackValue(const RedirectOptions());
  });

  setUp(() {
    mockPlatform = MockRedirectPlatform();
    platform.RedirectPlatform.instance = mockPlatform;
  });

  group('runRedirect', () {
    final testUrl = Uri.parse('https://auth.example.com/authorize');
    final successUri = Uri.parse('myapp://callback?code=abc123');

    test('delegates to platform instance', () async {
      when(
        () => mockPlatform.run(
          url: any(named: 'url'),
          options: any(named: 'options'),
        ),
      ).thenReturn(
        RedirectHandle(
          url: testUrl,
          result: Future.value(RedirectSuccess(uri: successUri)),
          cancel: () async {},
        ),
      );

      final handle = runRedirect(url: testUrl);
      final result = await handle.result;

      expect(result, isA<RedirectSuccess>());
      expect((result as RedirectSuccess).uri, equals(successUri));

      verify(
        () => mockPlatform.run(
          url: testUrl,
          options: any(named: 'options'),
        ),
      ).called(1);
    });

    test('passes options to platform', () async {
      when(
        () => mockPlatform.run(
          url: any(named: 'url'),
          options: any(named: 'options'),
        ),
      ).thenReturn(
        RedirectHandle(
          url: testUrl,
          result: Future.value(const RedirectCancelled()),
          cancel: () async {},
        ),
      );

      const options = RedirectOptions(
        timeout: Duration(seconds: 30),
        preferEphemeral: true,
      );

      runRedirect(url: testUrl, options: options);

      verify(
        () => mockPlatform.run(
          url: testUrl,
          options: options,
        ),
      ).called(1);
    });

    test('returns RedirectCancelled from platform', () async {
      when(
        () => mockPlatform.run(
          url: any(named: 'url'),
          options: any(named: 'options'),
        ),
      ).thenReturn(
        RedirectHandle(
          url: testUrl,
          result: Future.value(const RedirectCancelled()),
          cancel: () async {},
        ),
      );

      final handle = runRedirect(url: testUrl);
      final result = await handle.result;

      expect(result, isA<RedirectCancelled>());
    });

    test('returns RedirectFailure from platform', () async {
      final error = Exception('Network error');
      when(
        () => mockPlatform.run(
          url: any(named: 'url'),
          options: any(named: 'options'),
        ),
      ).thenReturn(
        RedirectHandle(
          url: testUrl,
          result: Future.value(RedirectFailure(error: error)),
          cancel: () async {},
        ),
      );

      final handle = runRedirect(url: testUrl);
      final result = await handle.result;

      expect(result, isA<RedirectFailure>());
      expect((result as RedirectFailure).error, equals(error));
    });

    test('returns RedirectPending from platform', () async {
      when(
        () => mockPlatform.run(
          url: any(named: 'url'),
          options: any(named: 'options'),
        ),
      ).thenReturn(
        RedirectHandle(
          url: testUrl,
          result: Future.value(const RedirectPending()),
          cancel: () async {},
        ),
      );

      final handle = runRedirect(url: testUrl);
      final result = await handle.result;

      expect(result, isA<RedirectPending>());
    });

    test('multiple concurrent handles each resolve independently', () async {
      var callCount = 0;

      when(
        () => mockPlatform.run(
          url: any(named: 'url'),
          options: any(named: 'options'),
        ),
      ).thenAnswer((_) {
        callCount++;
        final code = 'code_$callCount';
        return RedirectHandle(
          url: testUrl,
          result: Future.value(
            RedirectSuccess(
              uri: Uri.parse('myapp://callback?code=$code'),
            ),
          ),
          cancel: () async {},
        );
      });

      final handle1 = runRedirect(url: testUrl);
      final handle2 = runRedirect(url: testUrl);
      final handle3 = runRedirect(url: testUrl);

      final results = await Future.wait([
        handle1.result,
        handle2.result,
        handle3.result,
      ]);

      expect(results, hasLength(3));
      expect(results[0], isA<RedirectSuccess>());
      expect(results[1], isA<RedirectSuccess>());
      expect(results[2], isA<RedirectSuccess>());

      // Each handle should have a distinct code
      final codes = results
          .whereType<RedirectSuccess>()
          .map((r) => r.uri.queryParameters['code'])
          .toSet();
      expect(codes, hasLength(3));

      verify(
        () => mockPlatform.run(
          url: any(named: 'url'),
          options: any(named: 'options'),
        ),
      ).called(3);
    });

    test('cancelling one handle does not affect another', () async {
      final cancelled = <int>{};

      when(
        () => mockPlatform.run(
          url: any(named: 'url'),
          options: any(named: 'options'),
        ),
      ).thenAnswer((_) {
        final completer = Completer<RedirectResult>();
        final handleIndex = cancelled.length + 1;

        return RedirectHandle(
          url: testUrl,
          result: completer.future,
          cancel: () async {
            cancelled.add(handleIndex);
            if (!completer.isCompleted) {
              completer.complete(const RedirectCancelled());
            }
          },
        );
      });

      final handle1 = runRedirect(url: testUrl);
      final handle2 = runRedirect(url: testUrl);

      // Cancel only handle1
      await handle1.cancel();

      final result1 = await handle1.result;
      expect(result1, isA<RedirectCancelled>());
      expect(cancelled, contains(1));
      expect(cancelled, isNot(contains(2)));

      // handle2 should still be active — cancel it for cleanup
      await handle2.cancel();
      final result2 = await handle2.result;
      expect(result2, isA<RedirectCancelled>());
    });

    test('handles with different platform options work concurrently',
        () async {
      when(
        () => mockPlatform.run(
          url: any(named: 'url'),
          options: any(named: 'options'),
        ),
      ).thenAnswer((invocation) {
        return RedirectHandle(
          url: testUrl,
          result: Future.value(
            RedirectSuccess(uri: successUri),
          ),
          cancel: () async {},
        );
      });

      final handleA = runRedirect(url: testUrl);
      final handleB = runRedirect(url: testUrl);

      final resultA = await handleA.result;
      final resultB = await handleB.result;

      expect(resultA, isA<RedirectSuccess>());
      expect(resultB, isA<RedirectSuccess>());
    });

    test('web platform options can be passed', () async {
      when(
        () => mockPlatform.run(
          url: any(named: 'url'),
          options: any(named: 'options'),
        ),
      ).thenReturn(
        RedirectHandle(
          url: testUrl,
          result: Future.value(RedirectSuccess(uri: successUri)),
          cancel: () async {},
        ),
      );

      final handle = runRedirect(
        url: testUrl,
        options: const RedirectOptions(
          platformOptions: {
            WebRedirectOptions.key: WebRedirectOptions(
              mode: WebRedirectMode.hiddenIframe,
              popupWidth: 400,
              popupHeight: 600,
            ),
          },
        ),
      );

      final result = await handle.result;
      expect(result, isA<RedirectSuccess>());

      verify(
        () => mockPlatform.run(
          url: testUrl,
          options: any(named: 'options'),
        ),
      ).called(1);
    });
  });

  group('RedirectHandle', () {
    test('exposes all constructor parameters', () {
      final handle = RedirectHandle(
        url: Uri.parse('https://example.com/auth'),
        options: const RedirectOptions(
          timeout: Duration(seconds: 30),
          preferEphemeral: true,
        ),
        result: Future.value(const RedirectCancelled()),
        cancel: () async {},
      );

      expect(handle.url, equals(Uri.parse('https://example.com/auth')));
      expect(handle.options.timeout, equals(const Duration(seconds: 30)));
      expect(handle.options.preferEphemeral, isTrue);
    });

    test('auto-generates a unique nonce', () {
      final handle1 = RedirectHandle(
        url: Uri.parse('https://example.com/auth'),
        result: Future.value(const RedirectCancelled()),
        cancel: () async {},
      );
      final handle2 = RedirectHandle(
        url: Uri.parse('https://example.com/auth'),
        result: Future.value(const RedirectCancelled()),
        cancel: () async {},
      );

      expect(handle1.nonce, isNotEmpty);
      expect(handle2.nonce, isNotEmpty);
      expect(handle1.nonce, isNot(equals(handle2.nonce)));
    });

    test('accepts an explicit nonce', () {
      final handle = RedirectHandle(
        url: Uri.parse('https://example.com/auth'),
        nonce: 'my-custom-nonce',
        result: Future.value(const RedirectCancelled()),
        cancel: () async {},
      );

      expect(handle.nonce, equals('my-custom-nonce'));
    });

    test('cancel completes result with RedirectCancelled', () async {
      final completer = Completer<RedirectResult>();

      final handle = RedirectHandle(
        url: Uri.parse('https://example.com/auth'),
        result: completer.future,
        cancel: () async {
          if (!completer.isCompleted) {
            completer.complete(const RedirectCancelled());
          }
        },
      );

      await handle.cancel();
      final result = await handle.result;
      expect(result, isA<RedirectCancelled>());
    });

    test('double-cancel is idempotent', () async {
      var cancelCount = 0;
      final completer = Completer<RedirectResult>();

      final handle = RedirectHandle(
        url: Uri.parse('https://example.com/auth'),
        result: completer.future,
        cancel: () async {
          cancelCount++;
          if (!completer.isCompleted) {
            completer.complete(const RedirectCancelled());
          }
        },
      );

      await handle.cancel();
      await handle.cancel();
      await handle.cancel();

      final result = await handle.result;
      expect(result, isA<RedirectCancelled>());
      expect(cancelCount, equals(3)); // cancel() called 3 times
    });
  });
}
