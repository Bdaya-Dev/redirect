import Foundation
import Testing

@testable import redirect_darwin

// MARK: - Tests

/// Native Swift tests for the redirect_darwin plugin.
///
/// These tests verify the plugin's internal logic without requiring a running
/// Flutter engine or a real browser session. `ASWebAuthenticationSession`
/// cannot be started in a headless test environment, so we test:
///
/// - Cancel and cancelAll behaviour
/// - Multiple concurrent redirect state management
/// - Request validation
/// - Nonce-based lookup correctness
///
/// Run with:
///   swift test (from the redirect_darwin/darwin/redirect_darwin/ directory)
///   - or -
///   xcrun xcodebuild test -scheme redirect_darwin -destination 'platform=macOS'
@MainActor
struct RedirectPluginTests {
    // MARK: - Cancel operations

    @Test
    func cancelByNonceOnEmptyState() throws {
        let plugin = RedirectPlugin()
        // Cancelling a nonexistent nonce should not throw.
        try plugin.cancel(nonce: "nonexistent")
    }

    @Test
    func cancelAllOnEmptyState() throws {
        let plugin = RedirectPlugin()
        // Cancelling all when nothing is pending should not throw.
        try plugin.cancel(nonce: "")
    }

    @Test
    func cancelByNonceCompletesWithNil() async {
        let plugin = RedirectPlugin()

        await confirmation("completion called") { confirmed in
            plugin.run(request: createRequest(nonce: "cancel-me")) { result in
                switch result {
                case .success(let url):
                    #expect(url == nil, "Cancelled redirect should return nil")
                case .failure(let error):
                    Issue.record("Unexpected error: \(error)")
                }
                confirmed()
            }

            // Cancel before the session can complete (it can't start in tests anyway).
            try? plugin.cancel(nonce: "cancel-me")
        }
    }

    @Test
    func cancelAllCompletesAllPending() async {
        let plugin = RedirectPlugin()
        var completionCount = 0

        for i in 0..<3 {
            plugin.run(request: createRequest(nonce: "n\(i)")) { result in
                switch result {
                case .success(let url):
                    #expect(url == nil)
                    completionCount += 1
                case .failure(let error):
                    Issue.record("Unexpected error: \(error)")
                }
            }
        }

        // Cancel all.
        try? plugin.cancel(nonce: "")

        #expect(completionCount == 3, "All 3 pending redirects should be cancelled")
    }

    @Test
    func duplicateNonceCancelsPrevious() async {
        let plugin = RedirectPlugin()
        var firstCancelled = false

        await confirmation("first completion called") { confirmed in
            plugin.run(request: createRequest(nonce: "dup")) { result in
                if case .success(nil) = result {
                    firstCancelled = true
                }
                confirmed()
            }

            // Second run with same nonce should cancel the first.
            plugin.run(request: createRequest(nonce: "dup")) { _ in }
        }

        #expect(firstCancelled, "First redirect with duplicate nonce should be cancelled")
    }

    // MARK: - Invalid URL handling

    @Test
    func invalidURLReturnsError() async {
        let plugin = RedirectPlugin()

        await confirmation("completion called") { confirmed in
            let badRequest = RunRequest(
                nonce: "bad-url",
                url: "",
                callback: CallbackConfigMessage(
                    type: .customScheme,
                    scheme: "myapp",
                    host: nil,
                    path: nil
                ),
                preferEphemeral: false,
                timeoutMillis: nil,
                additionalHeaderFields: nil
            )

            plugin.run(request: badRequest) { result in
                switch result {
                case .success:
                    Issue.record("Should have failed for empty URL")
                case .failure(let error):
                    let pigeonError = error as? PigeonError
                    #expect(pigeonError?.code == "INVALID_ARGUMENTS")
                }
                confirmed()
            }
        }
    }

    // MARK: - Helpers

    private func createRequest(
        nonce: String,
        url: String = "https://example.com/authorize",
        scheme: String = "myapp",
        preferEphemeral: Bool = false,
        timeoutMillis: Int64? = nil
    ) -> RunRequest {
        return RunRequest(
            nonce: nonce,
            url: url,
            callback: CallbackConfigMessage(
                type: .customScheme,
                scheme: scheme,
                host: nil,
                path: nil
            ),
            preferEphemeral: preferEphemeral,
            timeoutMillis: timeoutMillis,
            additionalHeaderFields: nil
        )
    }
}
