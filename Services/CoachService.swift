import Foundation
import Security

enum CoachError: Error, LocalizedError {
    case notConfigured
    case networkError
    case invalidResponse
    case authentication
    case rateLimited
    case unavailable

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "Live AI is not connected yet. Please finish the server setup."
        case .networkError: return "Could not connect. Check your internet connection and try again."
        case .invalidResponse: return "The coach returned an incomplete reply. Please try again."
        case .authentication: return "Could not start a secure chat session. Please try again."
        case .rateLimited: return "The chat request limit has been reached. Please try again later."
        case .unavailable: return "The coach is temporarily unavailable. Please try again."
        }
    }
}

actor CoachService {
    static let shared = CoachService()

    // Public project configuration only. The OpenAI key lives in the server's secrets.
    private let projectURL: URL?
    private let publicKey: String
    private let session: URLSession
    private var auth: AuthSession?

    init(session: URLSession = .shared) {
        self.session = session
        let environment = ProcessInfo.processInfo.environment
        let url = environment["COACH_SUPABASE_URL"]
            ?? Bundle.main.object(forInfoDictionaryKey: "CoachSupabaseURL") as? String ?? ""
        publicKey = environment["COACH_SUPABASE_PUBLIC_KEY"]
            ?? Bundle.main.object(forInfoDictionaryKey: "CoachSupabasePublicKey") as? String ?? ""
        projectURL = URL(string: url)
    }

    func sendMessages(_ messages: [[String: String]]) async throws -> String {
        guard let projectURL, projectURL.scheme == "https", !publicKey.isEmpty else {
            throw CoachError.notConfigured
        }
        let token = try await accessToken(baseURL: projectURL)
        var request = URLRequest(url: projectURL.appendingPathComponent("functions/v1/coach"))
        request.httpMethod = "POST"
        request.timeoutInterval = 90
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(publicKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "messages": messages,
            "localDate": Date().formatted(.iso8601),
            "timeZone": TimeZone.current.identifier
        ])
        let data = try await perform(request)
        guard let reply = try? JSONDecoder().decode(Reply.self, from: data),
              !reply.reply.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CoachError.invalidResponse
        }
        return reply.reply
    }

    private func accessToken(baseURL: URL) async throws -> String {
        if auth == nil { auth = loadSession(account: baseURL.absoluteString) }
        if let auth, auth.expires_at > Date().timeIntervalSince1970 + 60 {
            return auth.access_token
        }

        // The app's existing sign-in is local only. Give chat a separate anonymous
        // Supabase session instead of treating that local flag as server authentication.
        let path = auth == nil ? "auth/v1/signup" : "auth/v1/token"
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)
        if auth != nil { components?.queryItems = [URLQueryItem(name: "grant_type", value: "refresh_token")] }
        guard let url = components?.url else { throw CoachError.notConfigured }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue(publicKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject:
            auth.map { ["refresh_token": $0.refresh_token] } ?? [:])
        let data: Data
        do {
            data = try await perform(request)
        } catch CoachError.authentication {
            auth = nil
            SecItemDelete(keychainQuery(account: baseURL.absoluteString) as CFDictionary)
            throw CoachError.authentication
        }
        guard let fresh = try? JSONDecoder().decode(AuthSession.self, from: data) else {
            throw CoachError.authentication
        }
        try saveSession(fresh, account: baseURL.absoluteString)
        auth = fresh
        return fresh.access_token
    }

    private func perform(_ request: URLRequest) async throws -> Data {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw CoachError.networkError
        }
        guard let http = response as? HTTPURLResponse else { throw CoachError.invalidResponse }
        switch http.statusCode {
        case 200..<300: return data
        case 401, 403: throw CoachError.authentication
        case 429: throw CoachError.rateLimited
        case 404, 503: throw CoachError.notConfigured
        default: throw CoachError.unavailable
        }
    }

    private func keychainQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "RaceTrian.CoachSession",
            kSecAttrAccount as String: account
        ]
    }

    private func loadSession(account: String) -> AuthSession? {
        var query = keychainQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(AuthSession.self, from: data)
    }

    private func saveSession(_ value: AuthSession, account: String) throws {
        let data = try JSONEncoder().encode(value)
        let query = keychainQuery(account: account)
        let status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var item = query
            item[kSecValueData as String] = data
            item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            guard SecItemAdd(item as CFDictionary, nil) == errSecSuccess else { throw CoachError.authentication }
        } else if status != errSecSuccess {
            throw CoachError.authentication
        }
    }

    private struct Reply: Decodable { let reply: String }
    private struct AuthSession: Codable {
        let access_token: String
        let refresh_token: String
        let expires_at: TimeInterval
    }
}
