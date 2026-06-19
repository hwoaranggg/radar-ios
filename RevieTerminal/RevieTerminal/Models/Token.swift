import Foundation

// Точное соответствие объекту токена из server.js (функция push / buildFromPair).
// Декодируется из SSE-сообщений и /api/new-tokens.
struct Token: Codable, Identifiable, Equatable {
    let mint: String
    var name: String
    var symbol: String
    var image: String
    var dex: String
    var pairAddr: String
    var created: Double          // ms epoch
    var price: Double
    var mc: Double
    var liq: Double
    var liqSol: Double
    var vol5m: Double
    var vol1h: Double
    var vol6h: Double
    var vol24h: Double
    var ch5m: Double
    var ch1h: Double
    var ch6h: Double
    var ch24h: Double
    var txns5m: Int
    var txns1h: Int
    var txns24h: Int
    var buys5m: Int
    var sells5m: Int
    var buys1h: Int
    var sells1h: Int
    var buys24h: Int
    var sells24h: Int
    var telegram: String
    var twitter: String
    var website: String
    var source: String

    var id: String { mint }

    // Сервер не всегда присылает все поля (helius/webhook отдают неполные токены),
    // поэтому всё опциональное со значением по умолчанию через кастомный init.
    enum CodingKeys: String, CodingKey {
        case mint, name, symbol, image, dex, pairAddr, created, price, mc, liq, liqSol
        case vol5m, vol1h, vol6h, vol24h, ch5m, ch1h, ch6h, ch24h
        case txns5m, txns1h, txns24h, buys5m, sells5m, buys1h, sells1h, buys24h, sells24h
        case telegram, twitter, website, source
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        mint = try c.decode(String.self, forKey: .mint)
        name = (try? c.decode(String.self, forKey: .name)) ?? "Unknown"
        symbol = (try? c.decode(String.self, forKey: .symbol)) ?? String(mint.prefix(6))
        image = (try? c.decode(String.self, forKey: .image)) ?? ""
        dex = (try? c.decode(String.self, forKey: .dex)) ?? "DEX"
        pairAddr = (try? c.decode(String.self, forKey: .pairAddr)) ?? ""
        created = Token.num(c, .created) ?? Date().timeIntervalSince1970 * 1000
        price = Token.num(c, .price) ?? 0
        mc = Token.num(c, .mc) ?? 0
        liq = Token.num(c, .liq) ?? 0
        liqSol = Token.num(c, .liqSol) ?? 0
        vol5m = Token.num(c, .vol5m) ?? 0
        vol1h = Token.num(c, .vol1h) ?? 0
        vol6h = Token.num(c, .vol6h) ?? 0
        vol24h = Token.num(c, .vol24h) ?? 0
        ch5m = Token.num(c, .ch5m) ?? 0
        ch1h = Token.num(c, .ch1h) ?? 0
        ch6h = Token.num(c, .ch6h) ?? 0
        ch24h = Token.num(c, .ch24h) ?? 0
        txns5m = Token.int(c, .txns5m)
        txns1h = Token.int(c, .txns1h)
        txns24h = Token.int(c, .txns24h)
        buys5m = Token.int(c, .buys5m)
        sells5m = Token.int(c, .sells5m)
        buys1h = Token.int(c, .buys1h)
        sells1h = Token.int(c, .sells1h)
        buys24h = Token.int(c, .buys24h)
        sells24h = Token.int(c, .sells24h)
        telegram = (try? c.decode(String.self, forKey: .telegram)) ?? ""
        twitter = (try? c.decode(String.self, forKey: .twitter)) ?? ""
        website = (try? c.decode(String.self, forKey: .website)) ?? ""
        source = (try? c.decode(String.self, forKey: .source)) ?? "other"
    }

    private static func num(_ c: KeyedDecodingContainer<CodingKeys>, _ k: CodingKeys) -> Double? {
        if let d = try? c.decode(Double.self, forKey: k) { return d }
        if let s = try? c.decode(String.self, forKey: k) { return Double(s) }
        return nil
    }
    private static func int(_ c: KeyedDecodingContainer<CodingKeys>, _ k: CodingKeys) -> Int {
        if let i = try? c.decode(Int.self, forKey: k) { return i }
        if let d = try? c.decode(Double.self, forKey: k) { return Int(d) }
        return 0
    }

    // Возраст в формате "5м" / "2ч" / "3д"
    var ageString: String {
        let diffMs = Date().timeIntervalSince1970 * 1000 - created
        let sec = max(0, diffMs / 1000)
        if sec < 60 { return "\(Int(sec))с" }
        let min = sec / 60
        if min < 60 { return "\(Int(min))м" }
        let hr = min / 60
        if hr < 24 { return "\(Int(hr))ч" }
        return "\(Int(hr / 24))д"
    }
}

// Колонки Pulse: классификация по market cap, повторяет логику фронта
// (новые → на подходе → мигрировали). Пороговые значения — как в webapp.
enum PulseColumn: String, CaseIterable {
    case new = "Новые пары"
    case final = "На подходе"
    case migrated = "Мигрировали"

    func contains(_ t: Token) -> Bool {
        switch self {
        case .new:      return t.dex == "Pump" && t.mc < 30_000
        case .final:    return t.dex == "Pump" && t.mc >= 30_000 && t.mc < 69_000
        case .migrated: return t.dex != "Pump" || t.mc >= 69_000
        }
    }
}
