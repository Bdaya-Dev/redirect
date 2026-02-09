import Foundation
import AuthenticationServices

#if os(iOS)
import Flutter
import UIKit
#elseif os(macOS)
import FlutterMacOS
import AppKit
#endif

public class RedirectPlugin: NSObject, FlutterPlugin, RedirectHostApi,
    ASWebAuthenticationPresentationContextProviding {
    private var session: ASWebAuthenticationSession?
    private var pendingCompletion: ((Result<String?, Error>) -> Void)?
    private var timeoutWorkItem: DispatchWorkItem?
    
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
        // Cancel any existing session
        cancelInternal()
        
        guard let url = URL(string: request.url) else {
            completion(.failure(PigeonError(
                code: "INVALID_ARGUMENTS",
                message: "Invalid URL: \(request.url)",
                details: nil
            )))
            return
        }
        
        pendingCompletion = completion
        
        session = ASWebAuthenticationSession(
            url: url,
            callbackURLScheme: request.callbackUrlScheme
        ) { [weak self] callbackURL, error in
            guard let self = self else { return }
            
            // Cancel the timeout timer since the session completed
            self.timeoutWorkItem?.cancel()
            self.timeoutWorkItem = nil
            
            guard self.pendingCompletion != nil else { return }
            
            if let error = error {
                if (error as NSError).code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                    self.pendingCompletion?(.success(nil)) // Cancelled
                } else {
                    self.pendingCompletion?(.failure(PigeonError(
                        code: "AUTH_ERROR",
                        message: error.localizedDescription,
                        details: "\((error as NSError).code)"
                    )))
                }
            } else if let callbackURL = callbackURL {
                self.pendingCompletion?(.success(callbackURL.absoluteString))
            } else {
                self.pendingCompletion?(.success(nil)) // Should not happen
            }
            
            self.pendingCompletion = nil
            self.session = nil
        }
        
        session?.prefersEphemeralWebBrowserSession = request.preferEphemeral
        session?.presentationContextProvider = self
        
        // Schedule timeout if specified
        if let timeoutMillis = request.timeoutMillis {
            let workItem = DispatchWorkItem { [weak self] in
                guard let self = self, self.pendingCompletion != nil else { return }
                self.session?.cancel()
                self.session = nil
                self.pendingCompletion?(.success(nil)) // Treated as cancellation
                self.pendingCompletion = nil
            }
            timeoutWorkItem = workItem
            DispatchQueue.main.asyncAfter(
                deadline: .now() + .milliseconds(Int(timeoutMillis)),
                execute: workItem
            )
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.session?.start()
        }
    }
    
    func cancel() throws {
        cancelInternal()
    }
    
    /// Shared cancellation logic used by both `cancel()` and `run()` (to
    /// cancel a prior session before starting a new one).
    private func cancelInternal() {
        timeoutWorkItem?.cancel()
        timeoutWorkItem = nil
        session?.cancel()
        session = nil
        if let cb = pendingCompletion {
            cb(.success(nil))
            pendingCompletion = nil
        }
    }
    
    // MARK: - ASWebAuthenticationPresentationContextProviding
    
    public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        #if os(iOS)
        // Use the modern scene-based API (UIApplication.shared.windows is
        // deprecated since iOS 15).
        if let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
           let window = windowScene.windows.first(where: { $0.isKeyWindow }) {
            return window
        }
        // Fallback for edge cases where no foreground scene is found yet.
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? UIWindow()
        #elseif os(macOS)
        return NSApplication.shared.windows.first { $0.isKeyWindow } ?? NSWindow()
        #endif
    }
}
