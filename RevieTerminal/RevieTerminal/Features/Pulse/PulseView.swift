import SwiftUI

// Главный экран Pulse. На мобильном — сегментированный выбор колонки
// (Новые / На подходе / Мигрировали) вместо трёх колонок десктопа.
struct PulseView: View {
    @StateObject private var vm = PulseViewModel()
    @State private var selectedColumn: PulseColumn = .new
    @State private var selectedToken: Token?

    var body: some View {
        VStack(spacing: 0) {
            header
            columnPicker
            dexFilterBar
            tokenList
        }
        .background(Color.rBg.ignoresSafeArea())
        .onAppear { vm.onAppear() }
        .onDisappear { vm.onDisappear() }
        .sheet(item: $selectedToken) { token in
            // Детальный экран токена — следующий слайс. Пока — заглушка с базовой инфой.
            TokenQuickSheet(token: token)
        }
    }

    private var header: some View {
        HStack {
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.rGreen)
                    .frame(width: 7, height: 7)
                    .shadow(color: .rGreen, radius: 4)
                Text("Pulse")
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundColor(.rText)
            }
            Spacer()
            HStack(spacing: 7) {
                Circle()
                    .fill(LinearGradient(colors: [Color(hex: 0x9945FF), Color(hex: 0x14F195)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 18, height: 18)
                    .overlay(Text("◎").font(.system(size: 9)).foregroundColor(.white))
                Text(vm.solPrice > 0 ? Fmt.usd(vm.solPrice) : "$—")
                    .font(.mono(13, weight: .semibold))
                    .foregroundColor(.rText)
                Text(Fmt.pct(vm.solChange))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(vm.solChange >= 0 ? .rGreen : .rRed)
            }
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(Color.rPanel2)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(Color.rPanel)
    }

    private var columnPicker: some View {
        HStack(spacing: 6) {
            ForEach(PulseColumn.allCases, id: \.self) { col in
                Button {
                    withAnimation(.easeOut(duration: 0.15)) { selectedColumn = col }
                } label: {
                    VStack(spacing: 3) {
                        Text(col.rawValue)
                            .font(.system(size: 13, weight: .semibold))
                        Text("\(vm.tokens(for: col).count)")
                            .font(.mono(11))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .foregroundColor(selectedColumn == col ? .white : .rText2)
                    .background(selectedColumn == col ? Color.rAccent : Color.rPanel2)
                    .clipShape(RoundedRectangle(cornerRadius: 9))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(Color.rPanel)
    }

    private var dexFilterBar: some View {
        let dexes = ["all", "Pump", "Raydium", "Meteora", "Orca"]
        let active = vm.dexFilter[selectedColumn] ?? "all"
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(dexes, id: \.self) { dex in
                    Button { vm.setFilter(selectedColumn, dex: dex) } label: {
                        Text(dex == "all" ? "Все" : dex)
                            .font(.system(size: 11, weight: .semibold))
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .foregroundColor(active == dex ? .white : .rText2)
                            .background(active == dex ? Color.rAccent : Color.rPanel2)
                            .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.rBorder, lineWidth: 1))
                            .clipShape(RoundedRectangle(cornerRadius: 7))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
        }
        .padding(.vertical, 8)
        .background(Color.rPanel)
        .overlay(Rectangle().fill(Color.rBorder).frame(height: 1), alignment: .bottom)
    }

    private var tokenList: some View {
        let items = vm.tokens(for: selectedColumn)
        return Group {
            if items.isEmpty {
                VStack(spacing: 10) {
                    if vm.connected {
                        Image(systemName: "tray").font(.system(size: 32)).foregroundColor(.rText3)
                        Text("Ждём новые токены…").font(.system(size: 13)).foregroundColor(.rText3)
                    } else {
                        ProgressView().tint(.rAccent)
                        Text("Подключение…").font(.system(size: 13)).foregroundColor(.rText3)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(items) { token in
                            TokenCard(token: token) { selectedToken = token }
                        }
                    }
                    .padding(.horizontal, 10).padding(.top, 8).padding(.bottom, 24)
                }
            }
        }
    }
}

// Временная карточка-шит до полноценного экрана токена (следующий слайс).
struct TokenQuickSheet: View {
    let token: Token
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("\(token.symbol)")
                    .font(.system(size: 22, weight: .heavy)).foregroundColor(.rText)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark").foregroundColor(.rText2)
                }
            }
            Text(token.name).font(.system(size: 14)).foregroundColor(.rText2)
            Text(token.mint).font(.mono(11)).foregroundColor(.rText3).textSelection(.enabled)

            HStack(spacing: 8) {
                stat("Цена", Fmt.price(token.price))
                stat("MC", Fmt.usd(token.mc))
                stat("LIQ", Fmt.usd(token.liq))
            }
            Text("Полный экран токена — торговля, чарт, холдеры — в следующем слайсе.")
                .font(.system(size: 12)).foregroundColor(.rText3)
            Spacer()
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.rPanel.ignoresSafeArea())
        .presentationDetents([.medium])
    }

    private func stat(_ l: String, _ v: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(l).font(.system(size: 9, weight: .semibold)).foregroundColor(.rText3)
            Text(v).font(.mono(14, weight: .semibold)).foregroundColor(.rText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(11).background(Color.rPanel2).clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
