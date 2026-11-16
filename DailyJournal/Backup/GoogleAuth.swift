import Foundation
import AuthenticationServices
import CryptoKit
import UIKit

/// Google sign-in with the system web sheet (OAuth 2.0 with PKCE). No Google SDK needed.
/// The client ID comes from Info.plist key `GoogleClientID` (an iOS OAuth client in Google Cloud).
@MainActor
final class GoogleAuth: NSObject, ObservableObject {
    static let shared = GoogleAuth()

    /// Only files this app creates are visible to it.
    static let scopes = "openid email https://www.googleapis.com/auth/drive.file"

    @Published private(set) var email: String? = UserDefaults.standard.string(forKey: "googleEmail")
    var isSignedIn: Bool { Keychain.read(Self.refreshKey) != nil }

    private var accessToken: String?
    private var accessTokenExpiry = Date.distantPast
    private var session: ASWebAuthenticationSession?

    private static let refreshKey = "googleRefreshToken"

    enum AuthError: LocalizedError {
        case notConfigured, cancelled, failed(String), signedOut
        var errorDescription: String? {
            switch self {
            case .notConfigured: "Google sign-in isn't set up in this build yet."
            case .cancelled: "Sign-in was cancelled."
            case .failed(let why): "Google sign-in failed: \(why)"
            case .signedOut: "Please sign in to Google again."
            }
        }
    }

    static var clientID: String? {
        let id = (Bundle.main.object(forInfoDictionaryKey: "GoogleClientID") as? String ?? "")
            .trimmingCharacters(in: .whitespaces)
        return id.isEmpty ? nil : id
    }

    /// "123-abc.apps.googleusercontent.com" -> "com.googleusercontent.apps.123-abc"
    private static func redirectScheme(for clientID: String) -> String {
        clientID.split(separator: ".").reversed().joined(separator: ".")
    }

    // MARK: Sign in / out

    func signIn() async throws {
        guard let clientID = Self.clientID else { throw AuthError.notConfigured }
        let scheme = Self.redirectScheme(for: clientID)
        let redirect = "\(scheme):/oauth2redirect"
        let verifier = Self.randomString()
        let challenge = Data(SHA256.hash(data: Data(verifier.utf8))).base64URL

        var comps = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        comps.queryItems = [
            .init(name: "client_id", value: clientID),
            .init(name: "redirect_uri", value: redirect),
            .init(name: "response_type", value: "code"),
            .init(name: "scope", value: Self.scopes),
            .init(name: "code_challenge", value: challenge),
            .init(name: "code_challenge_method", value: "S256"),
            .init(name: "access_type", value: "offline"),
            .init(name: "prompt", value: "consent"),
        ]

        let callback: URL = try await withCheckedThrowingContinuation { cont in
            let session = ASWebAuthenticationSession(url: comps.url!, callbackURLScheme: scheme) { url, error in
                if let url { cont.resume(returning: url) }
                else if let error = error as? ASWebAuthenticationSessionError, error.code == .canceledLogin {
                    cont.resume(throwing: AuthError.cancelled)
                } else {
                    cont.resume(throwing: AuthError.failed(error?.localizedDescription ?? "no response"))
                }
            }
            session.presentationContextProvider = self
            self.session = session
            session.start()
        }
        session = nil

        guard let code = URLComponents(url: callback, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "code" })?.value else {
            throw AuthError.failed("no code returned")
        }

        let tokens = try await tokenRequest([
            "client_id": clientID,
            "code": code,
            "code_verifier": verifier,
            "grant_type": "authorization_code",
            "redirect_uri": redirect,
        ])
        guard let refresh = tokens.refresh_token else { throw AuthError.failed("no refresh token") }
        Keychain.save(refresh, for: Self.refreshKey)
        accessToken = tokens.access_token
        accessTokenExpiry = Date().addingTimeInterval(TimeInterval(tokens.expires_in ?? 3000) - 60)

        email = try? await fetchEmail()
        UserDefaults.standard.set(email, forKey: "googleEmail")
        AppLog.info("Google sign-in done")
    }

    func signOut() {
        if let refresh = Keychain.read(Self.refreshKey) {
            var req = URLRequest(url: URL(string: "https://oauth2.googleapis.com/revoke?token=\(refresh)")!)
            req.httpMethod = "POST"
            URLSession.shared.dataTask(with: req).resume()
        }
        Keychain.delete(Self.refreshKey)
        accessToken = nil
        email = nil
        UserDefaults.standard.removeObject(forKey: "googleEmail")
        AppLog.info("Google signed out")
    }

    // MARK: Tokens

    /// A valid access token, refreshed when needed.
    func validAccessToken() async throws -> String {
        if let accessToken, Date() < accessTokenExpiry { return accessToken }
        guard let clientID = Self.clientID else { throw AuthError.notConfigured }
        guard let refresh = Keychain.read(Self.refreshKey) else { throw AuthError.signedOut }
        do {
            let tokens = try await tokenRequest([
                "client_id": clientID,
                "refresh_token": refresh,
                "grant_type": "refresh_token",
            ])
            accessToken = tokens.access_token
            accessTokenExpiry = Date().addingTimeInterval(TimeInterval(tokens.expires_in ?? 3000) - 60)
            return tokens.access_token
        } catch AuthError.failed(let why) where why.contains("invalid_grant") {
            // Access was revoked or expired: sign out so the screen asks again.
            signOut()
            throw AuthError.signedOut
        }
    }

    private struct TokenResponse: Decodable {
        let access_token: String
        let expires_in: Int?
        let refresh_token: String?
    }

    private func tokenRequest(_ form: [String: String]) async throws -> TokenResponse {
        var req = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.httpBody = form.map { "\($0.key)=\($0.value.formEncoded)" }.joined(separator: "&").data(using: .utf8)
        let (data, response) = try await URLSession.shared.data(for: req)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw AuthError.failed(String(data: data, encoding: .utf8) ?? "token error")
        }
        return try JSONDecoder().decode(TokenResponse.self, from: data)
    }

    private func fetchEmail() async throws -> String? {
        var req = URLRequest(url: URL(string: "https://openidconnect.googleapis.com/v1/userinfo")!)
        req.setValue("Bearer \(try await validAccessToken())", forHTTPHeaderField: "Authorization")
        let (data, _) = try await URLSession.shared.data(for: req)
        struct Info: Decodable { let email: String? }
        return try JSONDecoder().decode(Info.self, from: data).email
    }

    private static func randomString() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64URL
    }
}

extension GoogleAuth: ASWebAuthenticationPresentationContextProviding {
    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap(\.windows)
                .first(where: \.isKeyWindow) ?? ASPresentationAnchor()
        }
    }
}

private extension Data {
    var base64URL: String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

private extension String {
    var formEncoded: String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return addingPercentEncoding(withAllowedCharacters: allowed) ?? self
    }
}

/// Small Keychain wrapper for tokens. Stays on this device only.
enum Keychain {
    private static let service = "com.sarahu.dailyjournal.google"

    static func save(_ value: String, for account: String) {
        delete(account)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: Data(value.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    static func read(_ account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var out: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &out) == errSecSuccess, let data = out as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(_ account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
