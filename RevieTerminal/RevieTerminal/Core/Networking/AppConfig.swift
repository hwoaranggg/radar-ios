import Foundation

// Конфиг приложения. ЗАМЕНИ baseURL на адрес твоего бэкенда (Railway/домен),
// и botUsername / botID на данные твоего бота (для Telegram Login Widget).
enum AppConfig {
    // Бэкенд (тот же, что обслуживает Mini App). Без слэша в конце.
    static let baseURL = URL(string: "https://your-backend-domain.up.railway.app")!

    // Username бота без @ — нужен для URL Telegram OAuth.
    static let botUsername = "your_bot_username"

    // Схема deep link для возврата из Telegram OAuth. Должна совпадать с CFBundleURLSchemes в Info.plist.
    static let callbackScheme = "revieterminal"

    // Полный redirect URI, который Telegram вернёт после логина.
    static var loginRedirectURI: String { "\(callbackScheme)://auth" }
}
