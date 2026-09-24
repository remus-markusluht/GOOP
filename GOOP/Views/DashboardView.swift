import SwiftUI

struct DashboardView: View {
    @ObservedObject var session: GOOPSession

    private var snapshot: HealthSnapshot? { session.snapshot }
    private var today: HealthDay? { snapshot?.days.first }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                header
                if let today {
                    recoveryCard(today)
                    HStack(spacing: 12) {
                        MetricCard(title: "Activity load", value: today.activityLoad.map(String.init) ?? "—", caption: "From active zone minutes", icon: "flame.fill")
                        MetricCard(title: "Sleep", value: sleepDuration(today.sleep?.minutesAsleep), caption: "Last recorded session", icon: "moon.zzz.fill")
                    }
                    activityCard(today)
                    coachingCard(today)
                } else {
                    NoDataMessage(title: "No synced health data yet", detail: "Open Google Health, sync your Fitbit Air, then pull down here to refresh.")
                }
                Text("GOOP estimates are for general wellness. They are not medical advice.")
                    .font(.system(size: 10, design: .rounded)).foregroundStyle(GoopStyle.muted).frame(maxWidth: .infinity).padding(.bottom, 18)
            }
            .padding(.horizontal, 20).padding(.top, 14)
        }
        .background(GoopStyle.canvas)
        .refreshable { await session.refresh() }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()).uppercased())
                    .font(.system(size: 10, weight: .bold, design: .rounded)).tracking(1.4).foregroundStyle(GoopStyle.muted)
                Text("Good morning, \(snapshot?.user.name.split(separator: " ").first.map(String.init) ?? "athlete")")
                    .font(.system(size: 24, weight: .semibold, design: .rounded)).tracking(-0.6).foregroundStyle(GoopStyle.ink)
            }
            Spacer()
            Image(systemName: "waveform.path.ecg").font(.system(size: 17, weight: .semibold)).foregroundStyle(GoopStyle.ink)
                .frame(width: 42, height: 42).background(GoopStyle.lime, in: Circle())
        }
    }

    private func recoveryCard(_ day: HealthDay) -> some View {
        let readiness = HealthScoreCalculator.readiness(current: day, history: snapshot?.days ?? [])
        return SurfaceCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Label("READINESS ESTIMATE", systemImage: "arrow.triangle.2.circlepath")
                        .font(.system(size: 10, weight: .bold, design: .rounded)).tracking(1)
                    Spacer()
                    Text(readiness == nil ? "BUILDING BASELINE" : "GOOP ESTIMATE")
                        .font(.system(size: 8, weight: .bold, design: .rounded)).tracking(0.6).foregroundStyle(GoopStyle.muted)
                }
                HStack(spacing: 18) {
                    ZStack {
                        Circle().stroke(GoopStyle.ink.opacity(0.08), lineWidth: 9)
                        if let readiness {
                            Circle().trim(from: 0, to: CGFloat(readiness) / 100)
                                .stroke(GoopStyle.lime, style: StrokeStyle(lineWidth: 9, lineCap: .round)).rotationEffect(.degrees(-90))
                        }
                        Text(readiness.map(String.init) ?? "—")
                            .font(.system(size: 32, weight: .medium, design: .rounded)).minimumScaleFactor(0.7)
                    }.frame(width: 94, height: 94)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(readiness == nil ? "Collecting your baseline" : "Your recent signals")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                        Text(readiness == nil
                             ? "GOOP needs at least seven days of sleep, HRV, and resting heart-rate history before estimating readiness."
                             : "Estimate combines sleep, HRV, and resting heart rate against your recent baseline.")
                            .font(.system(size: 11, design: .rounded)).foregroundStyle(GoopStyle.muted).lineSpacing(3)
                    }
                }
                Rectangle().fill(GoopStyle.ink.opacity(0.08)).frame(height: 1)
                HStack {
                    SmallStat(label: "RESTING HR", value: day.restingHeartRate.map(String.init) ?? "—", unit: "BPM")
                    Spacer()
                    SmallStat(label: "HRV", value: day.hrvMilliseconds.map { String(Int($0.rounded())) } ?? "—", unit: "MS")
                    Spacer()
                    SmallStat(label: "SLEEP", value: day.sleep?.minutesAsleep.map { String(format: "%.1f", Double($0) / 60) } ?? "—", unit: "HRS")
                }
            }
        }
    }

    private func activityCard(_ day: HealthDay) -> some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("ACTIVITY").font(.system(size: 10, weight: .bold, design: .rounded)).tracking(1.2).foregroundStyle(GoopStyle.muted)
                        Text("Movement recorded today").font(.system(size: 15, weight: .semibold, design: .rounded))
                    }
                    Spacer()
                    Image(systemName: "figure.walk").foregroundStyle(GoopStyle.muted)
                }
                HStack(alignment: .lastTextBaseline, spacing: 5) {
                    Text(day.steps.map { $0.formatted() } ?? "—").font(.system(size: 30, weight: .medium, design: .rounded)).tracking(-1)
                    Text("steps").font(.system(size: 12, design: .rounded)).foregroundStyle(GoopStyle.muted)
                    Spacer()
                    Text(day.activeZoneMinutes.map { "\($0) AZM" } ?? "— AZM")
                        .font(.system(size: 10, weight: .bold, design: .rounded)).foregroundStyle(GoopStyle.muted)
                }
            }
        }
    }

    private func coachingCard(_ day: HealthDay) -> some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: "sparkles").font(.system(size: 16, weight: .semibold)).frame(width: 38, height: 38).background(GoopStyle.lime, in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 5) {
                Text("GOOP NOTE").font(.system(size: 10, weight: .bold, design: .rounded)).tracking(1.1).foregroundStyle(GoopStyle.muted)
                Text(day.sleep?.minutesAsleep.map { "You logged \(sleepDuration($0)) of sleep. Use your own energy and training plan to guide today's effort." } ?? "Sleep data has not synced yet. Check Google Health after your Fitbit Air syncs.")
                    .font(.system(size: 12, design: .rounded)).lineSpacing(3)
            }
        }
        .padding(16)
        .background(GoopStyle.lime.opacity(0.18), in: RoundedRectangle(cornerRadius: 20))
    }

    private func sleepDuration(_ minutes: Int?) -> String {
        guard let minutes else { return "—" }
        return "\(minutes / 60)h \(minutes % 60)m"
    }
}
