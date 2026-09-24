import AuthenticationServices
import Combine
import Foundation
import UIKit

@MainActor
final class GOOPSession: NSObject, ObservableObject, ASWebAuthenticationPresentationContextProviding {
    @Published private(set) var state: GOOPConnectionState = .signedOut
    @Published private(set) var snapshot: HealthSnapshot?

    private let api = GOOPAPIClient()
    private let tokenStore = SessionTokenStore()
    private var webAuthenticationSession: ASWebAuthenticationSession?

    override init() {
        super.init()
        if tokenStore.read() != nil {
            state = .loading
            Task { await refresh() }
        }
    }

    func signIn() {
        guard let startURL = URL(string: "auth/google/start", relativeTo: GOOPConfiguration.apiBaseURL)?.absoluteURL else {
            state = .failed("Set GOOP_API_BASE_URL to the HTTPS address of your GOOP server.")
            return
        }

        state = .connecting
        let auth = ASWebAuthenticationSession(url: startURL, callbackURLScheme: "goop") { [weak self] callbackURL, error in
            guard let self else { return }
            Task { @MainActor in
                if let error {
                    self.state = .failed(error.localizedDescription)
                    return
                }
                guard let callbackURL,
                      let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "code" })?.value else {
                    self.state = .failed(GOOPAPIError.missingCallbackCode.localizedDescription)
                    return
                }
                await self.finishSignIn(code: code)
            }
        }
        auth.presentationContextProvider = self
        auth.prefersEphemeralWebBrowserSession = false
        webAuthenticationSession = auth
        if !auth.start() {
            state = .failed("Could not open the secure Google sign-in window.")
            webAuthenticationSession = nil
        }
    }

    func refresh() async {
        guard let token = tokenStore.read() else {
            state = .signedOut
            snapshot = nil
            return
        }
        state = .loading
        do {
            snapshot = try await api.fetchSnapshot(sessionToken: token)
            state = .connected
        } catch {
            if let apiError = error as? GOOPAPIError, case .unauthorized = apiError {
                tokenStore.delete()
                snapshot = nil
                state = .signedOut
            } else {
                state = .failed(error.localizedDescription)
            }
        }
    }

    func signOut() {
        let token = tokenStore.read()
        tokenStore.delete()
        snapshot = nil
        state = .signedOut
        if let token { Task { await api.logout(sessionToken: token) } }
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow) ?? ASPresentationAnchor()
    }

    private func finishSignIn(code: String) async {
        do {
            let response = try await api.exchangeAuthorizationCode(code)
            try tokenStore.write(response.sessionToken)
            await refresh()
        } catch {
            state = .failed(error.localizedDescription)
        }
        webAuthenticationSession = nil
    }
}
