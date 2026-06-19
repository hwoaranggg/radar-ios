import Foundation

// ─── Auth ──────────────────────────────────────────────────────────────────────
struct TelegramAuthResult: Codable {
    let token: String
    let uid: String
    let profile: TelegramProfile
    let hasWallet: Bool
    let address: String?
    let needStart: Bool
}

struct TelegramProfile: Codable {
    let id: String
    let first_name: String
    let last_name: String
    let username: String
    let photo_url: String
}

struct AuthMe: Codable {
    let uid: String
    let hasWallet: Bool
    let address: String?
}

// Поля Telegram Login Widget, которые приходят в callback URL и шлются на /api/auth/telegram.
struct TelegramLoginPayload: Codable {
    let id: String
    let first_name: String?
    let last_name: String?
    let username: String?
    let photo_url: String?
    let auth_date: String
    let hash: String

    func asDictionary() -> [String: String] {
        var d: [String: String] = ["id": id, "auth_date": auth_date, "hash": hash]
        if let v = first_name { d["first_name"] = v }
        if let v = last_name { d["last_name"] = v }
        if let v = username { d["username"] = v }
        if let v = photo_url { d["photo_url"] = v }
        return d
    }
}

// ─── Trade ─────────────────────────────────────────────────────────────────────
struct TradeResult: Codable {
    let ok: Bool
    let signature: String
    let explorer: String
}

// ─── Generic error envelope ──────────────────────────────────────────────────────
struct APIError: Codable { let error: String }

// ─── Форматирование чисел (повторяет fmtUsd / formatPrice фронта) ────────────────
enum Fmt {
    static func usd(_ n: Double) -> String {
        guard n != 0 else { return "$0" }
        if n >= 1e9 { return "$\(round2(n/1e9))B" }
        if n >= 1e6 { return "$\(round2(n/1e6))M" }
        if n >= 1e3 { return "$\(round2(n/1e3))K" }
        return "$\(round2(n))"
    }

    static func price(_ p: Double) -> String {
        guard p > 0 else { return "$0" }
        if p >= 1 { return "$" + round2(p) }
        if p >= 0.0001 { return "$" + trimmed(p, 6) }
        // subscript-нотация 0.0(5)4890
        let s = String(format: "%.20f", p)
        if let m = s.range(of: #"^0\.(0+)(\d+)"#, options: .regularExpression) {
            let sub = String(s[m])
            if let dot = sub.firstIndex(of: ".") {
                let frac = sub[sub.index(after: dot)...]
                let zeros = frac.prefix { $0 == "0" }.count
                let sig = frac.drop { $0 == "0" }.prefix(4)
                return "$0.0(\(zeros))\(sig)"
            }
        }
        return "$" + trimmed(p, 8)
    }

    static func pct(_ n: Double) -> String {
        (n >= 0 ? "+" : "") + round2(n) + "%"
    }

    static func amount(_ n: Double) -> String {
        if n >= 1e6 { return round2(n/1e6) + "M" }
        if n >= 1e3 { return round2(n/1e3) + "K" }
        return round2(n)
    }

    private static func round2(_ n: Double) -> String {
        String(format: "%.2f", n)
    }
    private static func trimmed(_ n: Double, _ places: Int) -> String {
        var s = String(format: "%.\(places)f", n)
        while s.contains(".") && (s.hasSuffix("0") || s.hasSuffix(".")) { s.removeLast() }
        return s
    }
}
