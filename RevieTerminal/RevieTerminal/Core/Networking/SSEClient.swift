import Foundation

// SSE-клиент для /api/new-tokens/stream. URLSession не имеет встроенного EventSource,
// поэтому читаем поток байтов через .bytes(for:) и сами разбираем построчный протокол:
//   "data: {...}\n\n"  — событие
//   ": ping\n\n"        — heartbeat (игнорируем)
//
// Сервер шлёт типы: init, new_token, update, prices_update. Декодируем в SSEMessage.
// Авто-реконнект с экспоненциальной задержкой при разрыве.

struct SSEMessage: Decodable {
    let type: String
    let token: Token?
    let tokens: [Token]?
}

actor SSEClient {
    private var task: Task<Void, Never>?
    private var retry = 0
    private let path = "/api/new-tokens/stream"

    typealias Handler = @Sendable (SSEMessage) -> Void
    private var onMessage: Handler?

    func start(onMessage: @escaping Handler) {
        self.onMessage = onMessage
        guard task == nil else { return }
        task = Task { await loop() }
    }

    func stop() {
        task?.cancel()
        task = nil
    }

    private func loop() async {
        while !Task.isCancelled {
            do {
                try await connectOnce()
                retry = 0 // нормальное закрытие — сбрасываем счётчик
            } catch {
                // разрыв соединения — пойдём на реконнект
            }
            if Task.isCancelled { break }
            retry += 1
            let delay = min(Double(retry) * 2.0, 30.0)
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
    }

    private func connectOnce() async throws {
        guard let url = URL(string: path, relativeTo: AppConfig.baseURL) else { return }
        var req = URLRequest(url: url)
        req.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        req.timeoutInterval = .infinity
        if let token = Keychain.loadToken() {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = .infinity
        cfg.timeoutIntervalForResource = .infinity
        let session = URLSession(configuration: cfg)

        let (bytes, response) = try await session.bytes(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw APIClientError.transport("sse status")
        }

        var dataBuffer = ""
        for try await line in bytes.lines {
            if Task.isCancelled { break }
            if line.isEmpty {
                // конец события — обрабатываем накопленный data
                if !dataBuffer.isEmpty {
                    dispatch(dataBuffer)
                    dataBuffer = ""
                }
                continue
            }
            if line.hasPrefix(":") { continue }          // heartbeat / comment
            if line.hasPrefix("data:") {
                let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
                dataBuffer += payload
            }
        }
    }

    private func dispatch(_ json: String) {
        guard let data = json.data(using: .utf8),
              let msg = try? JSONDecoder().decode(SSEMessage.self, from: data) else { return }
        onMessage?(msg)
    }
}
