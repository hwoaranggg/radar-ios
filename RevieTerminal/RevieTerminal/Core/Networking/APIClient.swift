import Foundation

enum APIClientError: LocalizedError {
    case http(Int, String)
    case decoding(String)
    case transport(String)
    case unauthorized

    var errorDescription: String? {
        switch self {
        case .http(let code, let msg): return "HTTP \(code): \(msg)"
        case .decoding(let m): return "Ошибка декодирования: \(m)"
        case .transport(let m): return "Сеть: \(m)"
        case .unauthorized: return "Не авторизован"
        }
    }
}

// Тонкий HTTP-клиент над URLSession. Подставляет Bearer JWT, кодирует/декодирует JSON,
// разворачивает серверный { error } в типизированную ошибку.
actor APIClient {
    static let shared = APIClient()

    private let session: URLSession
    private let baseURL = AppConfig.baseURL

    init() {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 20
        cfg.waitsForConnectivity = true
        session = URLSession(configuration: cfg)
    }

    private func makeRequest(_ path: String, method: String, body: Encodable?) throws -> URLRequest {
        guard let url = URL(string: path, relativeTo: baseURL) else {
            throw APIClientError.transport("bad url \(path)")
        }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = Keychain.loadToken() {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            req.httpBody = try JSONEncoder().encode(AnyEncodable(body))
        }
        return req
    }

    func get<T: Decodable>(_ path: String, as type: T.Type) async throws -> T {
        try await send(makeRequest(path, method: "GET", body: nil), as: type)
    }

    func post<T: Decodable>(_ path: String, body: Encodable? = nil, as type: T.Type) async throws -> T {
        try await send(makeRequest(path, method: "POST", body: body), as: type)
    }

    private func send<T: Decodable>(_ req: URLRequest, as type: T.Type) async throws -> T {
        let data: Data, response: URLResponse
        do {
            (data, response) = try await session.data(for: req)
        } catch {
            throw APIClientError.transport(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else {
            throw APIClientError.transport("no response")
        }
        if http.statusCode == 401 { throw APIClientError.unauthorized }

        // Сервер часто отдаёт { error } даже с кодом 200 (старые хэндлеры). Проверяем.
        if let apiErr = try? JSONDecoder().decode(APIError.self, from: data), !apiErr.error.isEmpty {
            throw APIClientError.http(http.statusCode, apiErr.error)
        }
        guard (200..<300).contains(http.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? "error"
            throw APIClientError.http(http.statusCode, msg)
        }
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw APIClientError.decoding(error.localizedDescription)
        }
    }
}

// Стирание типа для кодирования произвольного Encodable как тела запроса.
struct AnyEncodable: Encodable {
    private let encodeFunc: (Encoder) throws -> Void
    init(_ wrapped: Encodable) { encodeFunc = wrapped.encode }
    func encode(to encoder: Encoder) throws { try encodeFunc(encoder) }
}
