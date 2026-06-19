import Foundation
import AuthenticationServices
import SwiftUI

// Управляет сессией: запускает Telegram OAuth через ASWebAuthenticationSession,
// меняет подписанный payload на JWT через /api/auth/telegram, хранит токен в Keychain,
// публикует состояние авторизации для UI.
@MainActor
final class AuthService: NSObject, ObservableObject {
    @Published var isAuthenticated = false
    @Published var address: String?
    @Published var needStart = false
    @Published var profile: TelegramProfile?
    @Published var authError: String?
    @Published var isWorking = false

    private var webSession: ASWebAuthenticationSession?

    // При старте проверяем сохранённый JWT через /api/auth/me.
    func bootstrap() async {
        guard Keychain.loadToken() != nil else { isAuthenticated = false; return }
        do {
            let me = try await APIClient.shared.get("/api/auth/me", as: AuthMe.self)
            address = me.address
            needStart = !me.hasWallet
            isAuthenticated = true
        } catch {
            // токен протух/невалиден
            Keychain.clear()
            isAuthenticated = false
        }
    }

    // Запуск Telegram OAuth. Telegram отдаёт поля логина в query callback URL,
    // мы собираем их в payload и шлём на бэкенд для проверки подписи.
    func login() {
        authError = nil
        // Telegram OAuth endpoint. origin/return совпадают с привязанным доменом бота (/setdomain).
        // Используем oauth.telegram.org/auth — он редиректит обратно на return_to с полями логина.
        var comps = URLComponents(string: "https://oauth.telegram.org/auth")!
        comps.queryItems = [
            .init(name: "bot_id", value: AppConfig.botUsername),       // см. примечание ниже
            .init(name: "origin", value: AppConfig.baseURL.absoluteString),
            .init(name: "return_to", value: AppConfig.loginRedirectURI),
            .init(name: "request_access", value: "write"),
        ]
        guard let url = comps.url else { authError = "bad login url"; return }

        let session = ASWebAuthenticationSession(
            url: url,
            callbackURLScheme: AppConfig.callbackScheme
        ) { [weak self] callbackURL, error in
            Task { @MainActor in
                guard let self else { return }
                if let error {
                    if (error as? ASWebAuthenticationSessionError)?.code != .canceledLogin {
                        self.authError = error.localizedDescription
                    }
                    return
                }
                guard let callbackURL else { self.authError = "no callback"; return }
                await self.handleCallback(callbackURL)
            }
        }
        session.presentationContextProvider = self
        session.prefersEphemeralWebBrowserSession = false
        webSession = session
        session.start()
    }

    // Парсим поля Telegram из callback URL и обмениваем на JWT.
    private func handleCallback(_ url: URL) async {
        guard let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let items = comps.queryItems else { authError = "bad callback"; return }

        var dict: [String: String] = [:]
        for item in items { if let v = item.value { dict[item.name] = v } }

        guard dict["id"] != nil, dict["hash"] != nil, dict["auth_date"] != nil else {
            authError = "Telegram не вернул данные логина"; return
        }
        await exchange(dict)
    }

    // Обмен payload → JWT (бэкенд проверяет подпись).
    func exchange(_ payload: [String: String]) async {
        isWorking = true
        defer { isWorking = false }
        struct Body: Encodable {
            let fields: [String: String]
            func encode(to encoder: Encoder) throws {
                var c = encoder.container(keyedBy: DynamicKey.self)
                for (k, v) in fields { try c.encode(v, forKey: DynamicKey(k)) }
            }
        }
        do {
            let result = try await APIClient.shared.post("/api/auth/telegram", body: Body(fields: payload), as: TelegramAuthResult.self)
            Keychain.saveToken(result.token)
            address = result.address
            needStart = result.needStart
            profile = result.profile
            isAuthenticated = true
        } catch {
            authError = error.localizedDescription
        }
    }

    func logout() {
        Keychain.clear()
        isAuthenticated = false
        address = nil
        profile = nil
    }
}

extension AuthService: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.first { $0.activationState == .foregroundActive } as? UIWindowScene
        return windowScene?.windows.first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
}

// Ключ для кодирования словаря с произвольными строковыми ключами.
struct DynamicKey: CodingKey {
    var stringValue: String
    var intValue: Int? { nil }
    init(_ s: String) { stringValue = s }
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { return nil }
}
