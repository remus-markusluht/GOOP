import SwiftUI

struct DashboardView: View {
    @ObservedObject var session: GOOPSession

    private var snapshot: HealthSnapshot? { session.snapshot }
    private var today: HealthDay? {
        snapshot?.days.first { $0.date == GoopStyle.localDateKey }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                header
                if let today {
                    NavigationLink {
                        ReadinessDetailView(day: today, history: snapshot?.days ?? [])
                    } label: {
                        recoveryCard(today)
                    }
                    .buttonStyle(GoopCardPressStyle())
                    HStack(spacing: 12) {
                        NavigationLink {
                            MetricDetailView(metric: .activeZoneMinutes, snapshot: snapshot)
                        } label: {
                            MetricCard(title: "Zone minutes", value: today.activeZoneMinutes.map(String.init) ?? "—", caption: "Google Health total", icon: "flame.fill", interactionHint: "View trend")
                        }
                        .buttonStyle(GoopCardPressStyle())
                        NavigationLink {
                            MetricDetailView(metric: .sleep, snapshot: snapshot)
                        } label: {
                            MetricCard(title: "Sleep", value: sleepDuration(today.sleep?.minutesAsleep), caption: "Latest session", icon: "moon.zzz.fill", interactionHint: "View sleep data")
                        }
                        .buttonStyle(GoopCardPressStyle())
                    }
                    NavigationLink {
                        MetricDetailView(metric: .steps, snapshot: snapshot)
                    } label: {
                        activityCard(today)
                    }
                    .buttonStyle(GoopCardPressStyle())
                    coachingCard(today)
                } else {
                    NoDataMessage(title: "No synced health data yet", detail: "Open Google Health, sync your Fitbit Air, then pull down here to refresh.")
                }
                Text("GOOP estimates are for general wellness. They are not medical advice.")
                    .font(.system(size: 10, design: .rounded)).foregroundStyle(GoopStyle.muted).frame(maxWidth: .infinity).padding(.bottom, 18)
            }
            .padding(.horizontal, 20).padding(.top, 14)
        }
        .background(GoopStyle.backgroundGradient)
        .toolbar { GoopRefreshToolbarButton { await session.refresh() } }
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
            GoopBrandMark(size: 42)
        }
    }

    private func recoveryCard(_ day: HealthDay) -> some View {
        let readiness = HealthScoreCalculator.readiness(current: day, history: snapshot?.days ?? [])
        return VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline) {
                Text("READINESS")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(1.5)
                    .foregroundStyle(GoopStyle.ink)
                Spacer()
                Text("GOOP ESTIMATE")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(GoopStyle.muted)
            }
            HStack(alignment: .center, spacing: 18) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(readiness.map(String.init) ?? "—")
                        .font(.system(size: 54, weight: .medium, design: .rounded))
                        .tracking(-2.5)
                        .foregroundStyle(GoopStyle.ink)
                        .contentTransition(.numericText())
                    if readiness != nil {
                        Text("/100")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(GoopStyle.muted)
                    }
                }
                .fixedSize(horizontal: true, vertical: false)

                Rectangle()
                    .fill(GoopStyle.line)
                    .frame(width: 1, height: 46)

                VStack(alignment: .leading, spacing: 5) {
                    Text(readiness == nil ? "Building your baseline" : "Daily recovery")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(GoopStyle.ink)
                    Text(readiness == nil
                         ? "More sleep and recovery history is needed before GOOP can estimate readiness."
                         : "Based on sleep, HRV, and resting heart rate compared with your recent readings.")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(GoopStyle.muted)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Rectangle().fill(GoopStyle.line).frame(height: 1)

            HStack(alignment: .top) {
                SmallStat(label: "RESTING HR", value: day.restingHeartRate.map(String.init) ?? "—", unit: "BPM")
                Spacer(minLength: 8)
                SmallStat(label: "HRV", value: day.hrvMilliseconds.map { String(Int($0.rounded())) } ?? "—", unit: "MS")
                Spacer(minLength: 8)
                SmallStat(label: "SLEEP", value: day.sleep?.minutesAsleep.map { String(format: "%.1f", Double($0) / 60) } ?? "—", unit: "HRS")
            }

            HStack(spacing: 7) {
                Text("See what shaped this estimate")
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 9, weight: .bold))
            }
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(GoopStyle.terracotta)
            .padding(.top, 1)
        }
        .foregroundStyle(GoopStyle.ink)
        .padding(20)
        .background(GoopStyle.panelGradient, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(GoopStyle.terracotta.opacity(0.24), lineWidth: 1))
    }

    private func activityCard(_ day: HealthDay) -> some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("TODAY’S MOVEMENT").font(.system(size: 10, weight: .bold, design: .rounded)).tracking(1.2).foregroundStyle(GoopStyle.muted)
                        Text("Steps and zone minutes").font(.system(size: 15, weight: .semibold, design: .rounded))
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
                HStack {
                    Text("Open daily movement")
                    Spacer()
                    Image(systemName: "arrow.up.right")
                }
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(GoopStyle.terracotta)
            }
        }
    }

    private func coachingCard(_ day: HealthDay) -> some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: "sparkles").font(.system(size: 16, weight: .semibold)).foregroundStyle(GoopStyle.ink).frame(width: 38, height: 38).background(GoopStyle.ember, in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 5) {
                Text("GOOP NOTE").font(.system(size: 10, weight: .bold, design: .rounded)).tracking(1.1).foregroundStyle(GoopStyle.muted)
                Text(day.sleep?.minutesAsleep.map { "You logged \(sleepDuration($0)) of sleep. Use your own energy and training plan to guide today's effort." } ?? "Sleep data has not synced yet. Check Google Health after your Fitbit Air syncs.")
                    .font(.system(size: 12, design: .rounded)).lineSpacing(3)
            }
        }
        .padding(16)
        .background(GoopStyle.panelGradient, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(GoopStyle.line, lineWidth: 1))
    }

    private func sleepDuration(_ minutes: Int?) -> String {
        guard let minutes else { return "—" }
        return "\(minutes / 60)h \(minutes % 60)m"
    }
}
