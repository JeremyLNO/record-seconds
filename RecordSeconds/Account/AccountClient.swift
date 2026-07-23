import Foundation

/// Optional CrazyBeeLabs account — entirely separate from app licensing. Talks to the
/// native mobile auth endpoints on crazybeelabs.com (bearer-token based, not the
/// browser session/cookie flow the website itself uses).
@MainActor
final class AccountClient: ObservableObject {
    static let shared = AccountClient()

    private static let baseURL = URL(string: "https://crazybeelabs.com")!
    private static let tokenKey = "token"
    private static let emailKey = "email"

    @Published private(set) var email: String?
    @Published private(set) var isWorking = false

    private init() {
        email = KeychainStore.get(Self.emailKey)
    }

    var isSignedIn: Bool { email != nil }

    func register(email: String, password: String, name: String) async throws {
        try await authenticate(path: "api/auth/mobile/register", body: ["email": email, "password": password, "name": name], email: email)
    }

    func login(email: String, password: String) async throws {
        try await authenticate(path: "api/auth/mobile/login", body: ["email": email, "password": password], email: email)
    }

    func signOut() {
        KeychainStore.delete(Self.tokenKey)
        KeychainStore.delete(Self.emailKey)
        email = nil
    }

    private func authenticate(path: String, body: [String: String], email: String) async throws {
        isWorking = true
        defer { isWorking = false }

        var request = URLRequest(url: Self.baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let message = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? String
            throw AccountError.server(message ?? L.t("account_error_generic"))
        }
        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let token = json["token"] as? String
        else {
            throw AccountError.server(L.t("account_error_generic"))
        }
        KeychainStore.set(token, forKey: Self.tokenKey)
        KeychainStore.set(email, forKey: Self.emailKey)
        self.email = email
    }
}

enum AccountError: LocalizedError {
    case server(String)
    var errorDescription: String? {
        switch self {
        case .server(let message): return message
        }
    }
}
