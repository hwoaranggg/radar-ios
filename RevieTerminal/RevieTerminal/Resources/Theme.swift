import SwiftUI

// Палитра из webapp/app.html (:root). Тёмная тема терминала.
extension Color {
    static let rBg       = Color(hex: 0x0A0B0F)
    static let rPanel    = Color(hex: 0x111319)
    static let rPanel2   = Color(hex: 0x161922)
    static let rCard     = Color(hex: 0x13151C)
    static let rCardHover = Color(hex: 0x181B24)
    static let rBorder   = Color(hex: 0x1F2330)
    static let rBorder2  = Color(hex: 0x2A2F3F)
    static let rText     = Color(hex: 0xEEF0F5)
    static let rText2    = Color(hex: 0x8A91A3)
    static let rText3    = Color(hex: 0x565D6F)
    static let rGreen    = Color(hex: 0x1BD96A)
    static let rGreenDim = Color(hex: 0x0D3D22)
    static let rRed      = Color(hex: 0xFF4D4D)
    static let rRedDim   = Color(hex: 0x3D1414)
    static let rAccent   = Color(hex: 0x7C5CFF)
    static let rAccent2  = Color(hex: 0x9D7BFF)
    static let rGold     = Color(hex: 0xFFB020)

    // Цвет акцента по DEX
    static func dexColor(_ dex: String) -> Color {
        switch dex {
        case "Pump":    return .rGreen
        case "Raydium": return .rAccent2
        case "Meteora": return Color(hex: 0x00D1FF)
        case "Orca":    return .rGold
        default:        return .rAccent
        }
    }

    init(hex: UInt32) {
        self.init(
            .sRGB,
            red:   Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue:  Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

extension Font {
    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}
