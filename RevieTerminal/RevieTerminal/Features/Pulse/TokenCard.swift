import SwiftUI

// Карточка токена в ленте Pulse. Повторяет компоновку .tok из webapp:
// аватар, символ + DEX-тег, имя, возраст, метрики (цена/MC/LIQ/объём).
struct TokenCard: View {
    let token: Token
    var onTap: () -> Void = {}

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 9) {
                    avatar
                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 6) {
                            Text(token.symbol)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.rText)
                                .lineLimit(1)
                            dexTag
                        }
                        Text(token.name)
                            .font(.system(size: 11))
                            .foregroundColor(.rText3)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 4)
                    Text(token.ageString)
                        .font(.mono(10))
                        .foregroundColor(.rText3)
                }
                metrics
            }
            .padding(11)
            .background(Color.rCard)
            .overlay(
                Rectangle()
                    .fill(Color.dexColor(token.dex))
                    .frame(width: 3)
                    .opacity(0.7),
                alignment: .leading
            )
            .clipShape(RoundedRectangle(cornerRadius: 11))
            .overlay(
                RoundedRectangle(cornerRadius: 11).stroke(Color.rBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var avatar: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(LinearGradient(colors: [Color(hex: 0x667EEA), Color(hex: 0x764BA2)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
            if let url = URL(string: token.image), !token.image.isEmpty {
                AsyncImage(url: url) { phase in
                    if case .success(let img) = phase {
                        img.resizable().scaledToFill()
                    } else {
                        Text(String(token.symbol.prefix(1)))
                            .font(.system(size: 15, weight: .bold)).foregroundColor(.white)
                    }
                }
            } else {
                Text(String(token.symbol.prefix(1)))
                    .font(.system(size: 15, weight: .bold)).foregroundColor(.white)
            }
        }
        .frame(width: 38, height: 38)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var dexTag: some View {
        Text(token.dex.uppercased())
            .font(.system(size: 9, weight: .bold))
            .padding(.horizontal, 6).padding(.vertical, 1)
            .foregroundColor(Color.dexColor(token.dex))
            .background(Color.dexColor(token.dex).opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private var metrics: some View {
        HStack(spacing: 6) {
            metric("MC", Fmt.usd(token.mc), .rText)
            metric("LIQ", Fmt.usd(token.liq), .rText)
            metric("VOL", Fmt.usd(token.vol1h), .rText)
            metric("1Ч", Fmt.pct(token.ch1h), token.ch1h >= 0 ? .rGreen : .rRed)
        }
    }

    private func metric(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 8, weight: .semibold))
                .foregroundColor(.rText3)
            Text(value)
                .font(.mono(11, weight: .semibold))
                .foregroundColor(color)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 5).padding(.horizontal, 4)
        .background(Color.rPanel2)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
