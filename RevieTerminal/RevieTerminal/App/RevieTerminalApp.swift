import SwiftUI

@main
struct RevieTerminalApp: App {
    @StateObject private var auth = AuthService()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(auth)
                .preferredColorScheme(.dark)
                .task { await auth.bootstrap() }
                .onOpenURL { url in
                    // Возврат из Telegram OAuth по deep link (revieterminal://auth?...)
                    Task { await handleOpenURL(url) }
                }
        }
    }

    @MainActor
    private func handleOpenURL(_ url: URL) async {
        guard url.scheme == AppConfig.callbackScheme else { return }
        guard let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let items = comps.queryItems else { return }
        var dict: [String: String] = [:]
        for item in items { if let v = item.value { dict[item.name] = v } }
        if dict["id"] != nil, dict["hash"] != nil {
            await auth.exchange(dict)
        }
    }
}

struct RootView: View {
    @EnvironmentObject var auth: AuthService

    var body: some View {
        Group {
            if auth.isAuthenticated {
                MainTabView()
            } else {
                LoginView()
            }
        }
        .animation(.easeInOut(duration: 0.25), value: auth.isAuthenticated)
    }
}

// Таб-скелет. В этом слайсе живой только Pulse; остальные вкладки — следующие слайсы.
struct MainTabView: View {
    @EnvironmentObject var auth: AuthService

    var body: some View {
        TabView {
            PulseView()
                .tabItem { Label("Pulse", systemImage: "bolt.fill") }

            PlaceholderTab(title: "Портфель", systemImage: "briefcase.fill")
                .tabItem { Label("Портфель", systemImage: "briefcase.fill") }

            PlaceholderTab(title: "Ордера", systemImage: "list.bullet.rectangle")
                .tabItem { Label("Ордера", systemImage: "list.bullet.rectangle") }

            PlaceholderTab(title: "Earn", systemImage: "gift.fill")
                .tabItem { Label("Earn", systemImage: "gift.fill") }

            SettingsTab()
                .tabItem { Label("Ещё", systemImage: "ellipsis") }
        }
        .tint(.rAccent)
    }
}

struct PlaceholderTab: View {
    let title: String
    let systemImage: String
    var body: some View {
        ZStack {
            Color.rBg.ignoresSafeArea()
            VStack(spacing: 12) {
                Image(systemName: systemImage).font(.system(size: 40)).foregroundColor(.rText3)
                Text(title).font(.system(size: 18, weight: .bold)).foregroundColor(.rText)
                Text("Следующий слайс").font(.system(size: 13)).foregroundColor(.rText3)
            }
        }
    }
}

struct SettingsTab: View {
    @EnvironmentObject var auth: AuthService
    var body: some View {
        ZStack {
            Color.rBg.ignoresSafeArea()
            VStack(spacing: 16) {
                if let addr = auth.address {
                    VStack(spacing: 6) {
                        Text("Кошелёк").font(.system(size: 11)).foregroundColor(.rText3)
                        Text(addr).font(.mono(12)).foregroundColor(.rText)
                            .lineLimit(1).truncationMode(.middle)
                            .textSelection(.enabled)
                    }
                    .padding(16).background(Color.rPanel2).clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 24)
                }
                if auth.needStart {
                    Text("Открой бота в Telegram и нажми Start, чтобы создать кошелёк.")
                        .font(.system(size: 13)).foregroundColor(.rGold)
                        .multilineTextAlignment(.center).padding(.horizontal, 32)
                }
                Button {
                    auth.logout()
                } label: {
                    Text("Выйти")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .foregroundColor(.rRed)
                        .background(Color.rRedDim.opacity(0.4))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 24)
                Spacer()
            }
            .padding(.top, 60)
        }
    }
}
