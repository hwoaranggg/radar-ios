import SwiftUI

struct LoginView: View {
    @EnvironmentObject var auth: AuthService

    var body: some View {
        ZStack {
            Color.rBg.ignoresSafeArea()
            // фоновое свечение
            RadialGradient(colors: [Color.rAccent.opacity(0.25), .clear],
                           center: .top, startRadius: 0, endRadius: 400)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()
                logo
                Text("Revie Terminal")
                    .font(.system(size: 28, weight: .heavy))
                    .foregroundColor(.rText)
                Text("Solana DEX-терминал")
                    .font(.system(size: 14))
                    .foregroundColor(.rText2)
                Spacer()

                if let err = auth.authError {
                    Text(err)
                        .font(.system(size: 12))
                        .foregroundColor(.rRed)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Button {
                    auth.login()
                } label: {
                    HStack(spacing: 10) {
                        if auth.isWorking { ProgressView().tint(.white) }
                        Image(systemName: "paperplane.fill")
                        Text("Войти через Telegram")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .foregroundColor(.white)
                    .background(
                        LinearGradient(colors: [Color(hex: 0x2AABEE), Color(hex: 0x229ED9)],
                                       startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(auth.isWorking)
                .padding(.horizontal, 24)

                Text("Тот же аккаунт и кошелёк, что в боте")
                    .font(.system(size: 11))
                    .foregroundColor(.rText3)
                    .padding(.bottom, 40)
            }
        }
    }

    private var logo: some View {
        RoundedRectangle(cornerRadius: 18)
            .fill(LinearGradient(colors: [.rAccent, .rAccent2],
                                 startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: 76, height: 76)
            .overlay(
                Image(systemName: "square.grid.2x2.fill")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(.white)
            )
            .shadow(color: .rAccent.opacity(0.5), radius: 24)
    }
}
