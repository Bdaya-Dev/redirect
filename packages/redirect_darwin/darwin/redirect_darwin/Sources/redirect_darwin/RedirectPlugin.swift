import Foundation
import AuthenticationServices

#if os(iOS)
import Flutter
import UIKit
#elseif os(macOS)
import FlutterMacOS
import AppKit
#endif

/// Tracks state for a single in-flight redirect operation.
private struct PendingRedirect {
    let session: ASWebAuthenticationSession
    let completion: (Result<String?, Error>) -> Void
    var timeoutWorkItem: DispatchWorkItem?
}

public class RedirectPlugin: NSObject, FlutterPlugin, RedirectHostApi,
    ASWebAuthenticationPresentationContextProviding {
    /// All in-flight redirects, keyed by nonce.
    private var pendingRedirects: [String: PendingRedirect] = [:]
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        #if os(iOS)
        let messenger = registrar.messenger()
        #elseif os(macOS)
        let messenger = registrar.messenger
        #endif
        
        let instance = RedirectPlugin()
        RedirectHostApiSetup.setUp(binaryMessenger: messenger, api: instance)
    }
    
    // MARK: - RedirectHostApi (Pigeon)
    
    func run(request: RunRequest, completion: @escaping (Result<String?, Error>) -> Void) {
        let nonce = request.nonce
        
        // If there's already a redirect with this nonce, cancel it first.
        cancelByNonce(nonce)
        
        guard let url = URL(string: request.url) else {
            completion(.failure(PigeonError(
                code: "INVALID_ARGUMENTS",
                message: "Invalid URL: \(request.url)",
                details: nil
            )))
            return
        }
        
        // Determine callback matching.
        let callbackScheme: String
        switch request.callback.type {
        case .customScheme:
            callbackScheme = request.callback.scheme ?? ""
        case .https:
            // ASWebAuthenticationSession on iOS 17.4+ supports HTTPS callbacks
            // via .https(host:path:). For older OS, we fall back to using
            // "https" as the callbackURLScheme which will match any https:// URL.
            callbackScheme = "https"
        }
        
        let session = ASWebAuthenticationSession(
            url: url,
            callbackURLScheme: callbackScheme
        ) { [weak self] callbackURL, error in
            guard let self = self else { return }
            
            guard var pending = self.pendingRedirects[nonce] else { return }
            
            // Cancel the timeout timer since the session completed
            pending.timeoutWorkItem?.cancel()
            self.pendingRedirects.removeValue(forKey: nonce)
            
            if let error = error {
                if (error as NSError).code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                    pending.completion(.success(nil)) // Cancelled
                } else {
                    pending.completion(.failure(PigeonError(
                        code: "AUTH_ERROR",
                        message: error.localizedDescription,
                        details: "\((error as NSError).code)"
                    )))
                }
            } else if let callbackURL = callbackURL {
                pending.completion(.success(callbackURL.absoluteString))
            } else {
                pending.completion(.success(nil)) // Should not happen
            }
        }
        
        session.prefersEphemeralWebBrowserSession = request.preferEphemeral
        session.presentationContextProvider = self
        
        // Set additional header fields if provided (iOS 17.4+ / macOS 14.4+)
        if let headers = request.additionalHeaderFields {
            if #available(iOS 17.4, macOS 14.4, *) {
                var validHeaders: [String: String] = [:]
                for (key, value) in headers {
                    if let key = key, let value = value {
                        validHeaders[key] = value
                    }
                }
                if !validHeaders.isEmpty {
                    session.additionalHeaderFields = validHeaders
                }
            }
        }
        
        var pending = PendingRedirect(
            session: session,
            completion: completion
        )
        
        // Schedule timeout if specified
        if let timeoutMillis = request.timeoutMillis {
            let workItem = DispatchWorkItem { [weak self] in
                self?.cancelByNonce(nonce)
            }
            pending.timeoutWorkItem = workItem
            DispatchQueue.main.asyncAfter(
                deadline: .now() + .milliseconds(Int(timeoutMillis)),
                execute: workItem
            )
        }
        
        pendingRedirects[nonce] = pending
        
        DispatchQueue.main.async {
            session.start()
        }
    }
    
    func cancel(nonce: String) throws {
        if nonce.isEmpty {
            cancelAll()
        } else {
            cancelByNonce(nonce)
        }
    }
    
    /// Cancels a single redirect operation by nonce.
    private func cancelByNonce(_ nonce: String) {
        guard var pending = pendingRedirects.removeValue(forKey: nonce) else { return }
        pending.timeoutWorkItem?.cancel()
        pending.session.cancel()
        pending.completion(.success(nil))
    }
    
    /// Cancels all pending redirect operations.
    private func cancelAll() {
        let allNonces = Array(pendingRedirects.keys)
        for nonce in allNonces {
            cancelByNonce(nonce)
        }
    }
    
    // MARK: - ASWebAuthenticationPresentationContextProviding
    
    public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        #if os(iOS)
        if let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
           let window = windowScene.windows.first(where: { $0.isKeyWindow }) {
            return window
        }
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? UIWindow()
        #elseif os(macOS)
        return NSApplication.shared.windows.first { $0.isKeyWindow } ?? NSWindow()
        #endif
    }
}
