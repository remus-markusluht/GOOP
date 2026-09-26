import SwiftUI

struct ContentView: View {
    @ObservedObject var session: GOOPSession

    init(session: GOOPSession) { self.session = session }

    var body: some View {
        Group {
            switch session.state {
            case .signedOut, .connecting:
                SignInView(state: session.state, action: session.signIn)
            case .failed(let message):
                SignInView(state: .failed(message), action: session.signIn)
            case .loading:
                LoadingView()
            case .connected:
                TabView {
                    NavigationStack { DashboardView(session: session) }
                        .tabItem { Label("Today", systemImage: "circle.grid.2x2.fill") }
                    NavigationStack { WorkoutsView(snapshot: session.snapshot, refresh: { await session.refresh() }) }
                        .tabItem { Label("Train", systemImage: "figure.run") }
                    NavigationStack { TrendsView(snapshot: session.snapshot, refresh: { await session.refresh() }) }
                        .tabItem { Label("Trends", systemImage: "chart.xyaxis.line") }
                    NavigationStack { SleepView(snapshot: session.snapshot, refresh: { await session.refresh() }) }
                        .tabItem { Label("Sleep", systemImage: "moon.zzz") }
                    NavigationStack { ProfileView(snapshot: session.snapshot, refresh: { await session.refresh() }, signOut: session.signOut) }
                        .tabItem { Label("You", systemImage: "person.crop.circle") }
                }
                .tint(GoopStyle.terracotta)
                .toolbarBackground(GoopStyle.panel, for: .tabBar)
                .toolbarBackground(.visible, for: .tabBar)
            }
        }
        .background(GoopStyle.backgroundGradient.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }
}
