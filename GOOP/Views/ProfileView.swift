import SwiftUI
import Combine

struct ProfileView: View {
    let snapshot: HealthSnapshot?
    let refresh: () async -> Void
    let signOut: () -> Void
    @ObservedObject private var confirmation = SignOutConfirmation()

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                PageTitle(kicker: "Your account", title: "Profile")
                SurfaceCard {
                    HStack(spacing: 14) {
                        Image(systemName: "person.crop.circle.fill").font(.system(size: 45)).foregroundStyle(GoopStyle.ink)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(snapshot?.user.name ?? "Google account").font(.system(size: 17, weight: .semibold, design: .rounded))
                            Text(snapshot?.user.email ?? "").font(.system(size: 11, design: .rounded)).foregroundStyle(GoopStyle.muted)
                        }
                        Spacer()
                    }
                }
                SurfaceCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("CONNECTED DATA").font(.system(size: 10, weight: .bold, design: .rounded)).tracking(1).foregroundStyle(GoopStyle.muted)
                        Label("Google Health", systemImage: "checkmark.circle.fill").font(.system(size: 14, weight: .medium, design: .rounded))
                        Text("GOOP reads only the activity, sleep, and health metrics you approved on Google's consent screen.")
                            .font(.system(size: 11, design: .rounded)).foregroundStyle(GoopStyle.muted).lineSpacing(3)
                    }
                }
                SurfaceCard {
                    VStack(alignment: .leading, spacing: 9) {
                        Text("HOW GOOP READINESS WORKS").font(.system(size: 10, weight: .bold, design: .rounded)).tracking(1).foregroundStyle(GoopStyle.muted)
                        Text("After seven or more days, the estimate combines sleep against an 8-hour target, HRV against your 28-day median, and resting heart rate against your 28-day median. It is a general wellness estimate, not a medical or WHOOP score.")
                            .font(.system(size: 12, design: .rounded)).lineSpacing(4)
                    }
                }
                Text("GOOP HEALTH IS FOR GENERAL WELLNESS AND IS NOT A MEDICAL DEVICE.")
                    .font(.system(size: 9, weight: .bold, design: .rounded)).tracking(0.7).foregroundStyle(GoopStyle.muted).multilineTextAlignment(.center).frame(maxWidth: .infinity)
                Button(role: .destructive) { confirmation.isPresented = true } label: {
                    Text("Disconnect Google Health").font(.system(size: 14, weight: .semibold, design: .rounded)).frame(maxWidth: .infinity).padding(15)
                        .background(GoopStyle.panel, in: RoundedRectangle(cornerRadius: 14))
                }
                .confirmationDialog("Disconnect Google Health?", isPresented: $confirmation.isPresented, titleVisibility: .visible) {
                    Button("Disconnect", role: .destructive, action: signOut)
                    Button("Cancel", role: .cancel) { }
                } message: {
                    Text("GOOP will remove its saved sign-in and stop requesting your health data.")
                }
                .padding(.bottom, 20)
            }
            .padding(.horizontal, 20).padding(.top, 14)
        }
        .background(GoopStyle.backgroundGradient)
        .toolbar { GoopRefreshToolbarButton { await refresh() } }
        .refreshable { await refresh() }
    }
}

private final class SignOutConfirmation: ObservableObject {
    @Published var isPresented = false
}
