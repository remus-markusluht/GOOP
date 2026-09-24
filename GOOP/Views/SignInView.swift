import SwiftUI

struct SignInView: View {
    let state: GOOPConnectionState
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()
            Text("GOOP").font(.system(size: 42, weight: .black, design: .rounded)).tracking(-2)
            Text("Know how you're recovering.")
                .font(.system(size: 22, weight: .semibold, design: .rounded)).padding(.top, 18)
            Text("Connect your Google Health account to see Fitbit activity, sleep, and health metrics in one place.")
                .font(.system(size: 15, design: .rounded)).foregroundStyle(GoopStyle.muted).lineSpacing(4).padding(.top, 9)

            Button(action: action) {
                HStack(spacing: 12) {
                    Image(systemName: "g.circle.fill").font(.system(size: 21))
                    Text(state == .connecting ? "Waiting for Google…" : "Continue with Google")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                    Spacer()
                    if state == .connecting { ProgressView().tint(GoopStyle.ink) }
                }
                .foregroundStyle(GoopStyle.ink)
                .padding(17)
                .background(GoopStyle.lime, in: RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            .disabled(state == .connecting)
            .padding(.top, 26)

            if case .failed(let message) = state {
                Label(message, systemImage: "exclamationmark.circle")
                    .font(.system(size: 12, design: .rounded)).foregroundStyle(.red)
                    .lineSpacing(3).padding(.top, 14)
            }

            Text("Google will ask you to choose which health data GOOP can access. You can disconnect at any time.")
                .font(.system(size: 11, design: .rounded)).foregroundStyle(GoopStyle.muted).lineSpacing(3).padding(.top, 18)
            Spacer()
            Text("GOOP provides general wellness information, not medical advice.")
                .font(.system(size: 10, design: .rounded)).foregroundStyle(GoopStyle.muted).padding(.bottom, 26)
        }
        .padding(.horizontal, 26)
        .background(GoopStyle.canvas.ignoresSafeArea())
    }
}

struct LoadingView: View {
    var body: some View {
        VStack(spacing: 14) {
            ProgressView().tint(GoopStyle.ink)
            Text("Loading your health data").font(.system(size: 14, design: .rounded)).foregroundStyle(GoopStyle.muted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(GoopStyle.canvas.ignoresSafeArea())
    }
}
