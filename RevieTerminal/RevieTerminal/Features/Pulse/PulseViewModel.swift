import Foundation
import SwiftUI

// Стор живой ленты токенов. Подписывается на SSE, поддерживает тот же лимит/дедуп,
// что и сервер (MAX_TOKENS, seen-set), и раздаёт токены по колонкам Pulse.
@MainActor
final class PulseViewModel: ObservableObject {
    @Published private(set) var tokens: [Token] = []
    @Published var connected = false
    @Published var solPrice: Double = 0
    @Published var solChange: Double = 0
    @Published var dexFilter: [PulseColumn: String] = [:]   // колонка -> dex ("all" или конкретный)

    private let sse = SSEClient()
    private var seen = Set<String>()
    private let maxTokens = 600
    private var solTimer: Task<Void, Never>?

    func onAppear() {
        Task { await loadInitial() }
        Task {
            await sse.start { [weak self] msg in
                Task { @MainActor in self?.handle(msg) }
            }
            await MainActor.run { self.connected = true }
        }
        startSolTimer()
    }

    func onDisappear() {
        Task { await sse.stop() }
        solTimer?.cancel()
    }

    // Первичная загрузка через REST (на случай если SSE init задержится)
    private func loadInitial() async {
        struct NewTokens: Decodable { let tokens: [Token]; let pump: Bool? }
        do {
            let r = try await APIClient.shared.get("/api/new-tokens", as: NewTokens.self)
            ingest(r.tokens, reset: true)
        } catch { /* SSE init покроет */ }
    }

    private func handle(_ msg: SSEMessage) {
        switch msg.type {
        case "init":
            if let ts = msg.tokens { ingest(ts, reset: true) }
        case "new_token":
            if let t = msg.token { upsert(t, prepend: true) }
        case "update":
            if let t = msg.token { upsert(t, prepend: false) }
        case "prices_update":
            if let ts = msg.tokens { for t in ts { upsert(t, prepend: false) } }
        default:
            break
        }
    }

    private func ingest(_ incoming: [Token], reset: Bool) {
        if reset { tokens = []; seen = [] }
        for t in incoming { upsert(t, prepend: false) }
    }

    private func upsert(_ token: Token, prepend: Bool) {
        if let idx = tokens.firstIndex(where: { $0.mint == token.mint }) {
            // обновление существующего — мёрджим (сервер шлёт обогащённые данные)
            tokens[idx] = token
            return
        }
        guard !seen.contains(token.mint) else { return }
        seen.insert(token.mint)
        if prepend { tokens.insert(token, at: 0) } else { tokens.append(token) }
        if tokens.count > maxTokens {
            let removed = tokens.removeLast()
            seen.remove(removed.mint)
        }
    }

    // Токены для конкретной колонки с применённым DEX-фильтром
    func tokens(for column: PulseColumn) -> [Token] {
        let dex = dexFilter[column] ?? "all"
        return tokens.filter { token in
            column.contains(token) && (dex == "all" || token.dex == dex)
        }
    }

    func setFilter(_ column: PulseColumn, dex: String) {
        dexFilter[column] = dex
    }

    // ─── SOL price ──────────────────────────────────────────────────────────────
    private func startSolTimer() {
        solTimer?.cancel()
        solTimer = Task {
            while !Task.isCancelled {
                await fetchSolPrice()
                try? await Task.sleep(nanoseconds: 30_000_000_000) // 30s
            }
        }
    }

    private func fetchSolPrice() async {
        struct SolPrice: Decodable { let price: Double; let change: Double }
        do {
            let r = try await APIClient.shared.get("/api/sol-price", as: SolPrice.self)
            solPrice = r.price
            solChange = r.change
        } catch { }
    }
}
