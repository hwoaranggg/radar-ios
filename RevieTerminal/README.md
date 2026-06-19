# Revie Terminal — iOS

Нативное iOS-приложение (SwiftUI) для существующего Telegram Mini App. Слайс 1: каркас,
сетевой слой, Telegram-логин, экран Pulse (живая лента токенов).

## Открыть и собрать
1. `open RevieTerminal.xcodeproj` (Xcode 15+, iOS 16+).
2. Выбрать симулятор iPhone → ⌘R.

Зависимостей нет — только системные фреймворки (URLSession, AuthenticationServices,
Security, SwiftUI). SPM-резолв не требуется.

## Настройка перед запуском
Файл `RevieTerminal/Core/Networking/AppConfig.swift`:
- `baseURL` — адрес твоего бэкенда (тот же, что обслуживает Mini App).
- `botUsername` — username бота без `@`.
- `callbackScheme` — `revieterminal` (уже прописан в Info.plist `CFBundleURLSchemes`).

Бандл-идентификатор: `com.revie.terminal` (поменяй в настройках таргета на свой,
если будешь публиковать).

## Что работает в этом слайсе
- **Telegram Login** через `ASWebAuthenticationSession`, обмен на JWT (`/api/auth/telegram`),
  токен в Keychain, авто-восстановление сессии (`/api/auth/me`).
- **Pulse** — живая лента через SSE (`/api/new-tokens/stream`) с авто-реконнектом;
  колонки Новые/На подходе/Мигрировали, фильтр по DEX, цена SOL в шапке.
- Таб-скелет: Портфель / Ордера / Earn / Настройки (заполняются в следующих слайсах).

## Зависимость от бэкенда
Нужен патч сервера из `backend/` (см. `server.patch.md`): добавляет `/api/auth/*`,
`/api/trade/*` и делает существующие эндпоинты принимающими JWT. Без него логин не пройдёт.

## Про Telegram OAuth (важно)
`AuthService.login()` открывает `oauth.telegram.org/auth`. Telegram требует:
1. В @BotFather: `/setdomain` → домен, совпадающий с `baseURL`.
2. Параметр `bot_id` — это **числовой** ID бота (часть до `:` в BOT_TOKEN). Сейчас в коде
   стоит `botUsername` как заглушка — подставь числовой ID, либо используй фолбэк ниже.

**Фолбэк (рекомендуется, надёжнее):** размести на своём домене мини-страницу с официальным
Telegram Login Widget, которая после успешного логина делает
`window.location = "revieterminal://auth?" + new URLSearchParams(user)`. Тогда в `login()`
открывай эту страницу вместо `oauth.telegram.org`. Deep link уже обрабатывается в
`RevieTerminalApp.onOpenURL`. Готовый HTML дам в следующем слайсе, если выберешь этот путь.

## Структура
```
RevieTerminal/
  App/                 — точка входа, root-роутинг, табы
  Core/
    Networking/        — AppConfig, APIClient (JWT), SSEClient
    Auth/              — AuthService (OAuth + сессия)
    Storage/           — Keychain
  Models/              — Token, API-модели, форматтеры
  Features/
    Auth/              — LoginView
    Pulse/             — PulseView, PulseViewModel, TokenCard
  Resources/           — Theme, Info.plist
```

## Дальше (следующие слайсы)
- Экран токена: чарт (`/api/token-chart`), холдеры/поток (`/api/token-flow`),
  security-бейджи (`/api/token-security`), реальная торговля (`/api/trade/buy|sell`).
- Портфель + баланс, Ордера (SL/TP/limit), Paper-трейдинг, Earn (RP/стрики/рулетка/сундуки),
  Трекер кошельков + PnL + алерты.
