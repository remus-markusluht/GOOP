import Foundation

enum GOOPConfiguration {
    static let apiBaseURL: URL = {
        let configured = Bundle.main.object(forInfoDictionaryKey: "GOOP_API_BASE_URL") as? String
        return URL(string: configured ?? "http://127.0.0.1:8787")!
    }()
}

enum GOOPAPIError: LocalizedError {
    case invalidResponse
    case server(String)
    case unauthorized
    case missingCallbackCode

    var errorDescription: String? {
        switch self {
        case .invalidResponse: "The GOOP server returned an invalid response."
        case .server(let message): message
        case .unauthorized: "Your sign-in expired. Please sign in again."
        case .missingCallbackCode: "Google sign-in did not return an authorization code."
        }
    }
}

struct SessionResponse: Decodable {
    let sessionToken: String
    let user: GOOPUser
}

struct GOOPAPIClient {
    private let baseURL = GOOPConfiguration.apiBaseURL
    private let session = URLSession.shared

    func exchangeAuthorizationCode(_ code: String) async throws -> SessionResponse {
        var request = URLRequest(url: baseURL.appending(path: "auth/exchange"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(ExchangeRequest(code: code))
        return try await send(request)
    }

    func fetchSnapshot(sessionToken: String) async throws -> HealthSnapshot {
        var request = URLRequest(url: baseURL.appending(path: "v1/snapshot"))
        request.setValue("Bearer \(sessionToken)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(HealthSnapshot.self, from: data)
    }

    func logout(sessionToken: String) async {
        var request = URLRequest(url: baseURL.appending(path: "v1/logout"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(sessionToken)", forHTTPHeaderField: "Authorization")
        _ = try? await session.data(for: request)
    }

    private func send<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let response = response as? HTTPURLResponse else { throw GOOPAPIError.invalidResponse }
        if response.statusCode == 401 { throw GOOPAPIError.unauthorized }
        guard (200..<300).contains(response.statusCode) else {
            let payload = try? JSONDecoder().decode(ErrorResponse.self, from: data)
            throw GOOPAPIError.server(payload?.error ?? "GOOP request failed (\(response.statusCode)).")
        }
    }
}

private struct ExchangeRequest: Encodable {
    let code: String
}

private struct ErrorResponse: Decodable {
    let error: String?
}
