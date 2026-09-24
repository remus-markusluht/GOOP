import SwiftUI
import Combine

struct TrendsView: View {
    let snapshot: HealthSnapshot?
    @ObservedObject private var selection = TrendsSelection()
    private let metrics = ["Steps", "HRV", "Resting HR", "Sleep"]

    private var days: [HealthDay] { (snapshot?.days ?? []).sorted { $0.date < $1.date } }
    private var values: [Double?] {
        days.map { day in
            switch selection.metric {
            case "HRV": day.hrvMilliseconds
            case "Resting HR": day.restingHeartRate.map(Double.init)
            case "Sleep": day.sleep?.minutesAsleep.map(Double.init)
            default: day.steps.map(Double.init)
            }
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                PageTitle(kicker: "Your patterns", title: "Trends")
                Picker("Metric", selection: $selection.metric) {
                    ForEach(metrics, id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.segmented)

                SurfaceCard {
                    VStack(alignment: .leading, spacing: 15) {
                        Text("LAST \(days.count) DAYS").font(.system(size: 10, weight: .bold, design: .rounded)).tracking(1.1).foregroundStyle(GoopStyle.muted)
                        Text(summaryValue).font(.system(size: 30, weight: .medium, design: .rounded)).tracking(-0.8)
                        HistoryLine(values: values).frame(height: 110)
                        HStack { Text(days.first?.date ?? ""); Spacer(); Text(days.last?.date ?? "") }
                            .font(.system(size: 9, design: .rounded)).foregroundStyle(GoopStyle.muted)
                    }
                }

                if days.isEmpty {
                    NoDataMessage(title: "No trends available", detail: "Sync your Fitbit Air through Google Health to build your history.")
                } else {
                    HStack(spacing: 12) {
                        MetricCard(title: "Latest HRV", value: days.last?.hrvMilliseconds.map { "\(Int($0.rounded())) ms" } ?? "—", caption: "No invented baseline", icon: "waveform.path.ecg")
                        MetricCard(title: "Activity load", value: days.last?.activityLoad.map(String.init) ?? "—", caption: "Based on AZM", icon: "flame.fill")
                    }
                }
                Text("Charts show synced measurements only. Gaps mean no data was returned for that day.")
                    .font(.system(size: 10, design: .rounded)).foregroundStyle(GoopStyle.muted).padding(.bottom, 18)
            }
            .padding(.horizontal, 20).padding(.top, 14)
        }
        .background(GoopStyle.canvas)
    }

    private var summaryValue: String {
        guard let value = values.compactMap({ $0 }).last else { return "No data" }
        switch selection.metric {
        case "HRV": return "\(Int(value.rounded())) ms"
        case "Resting HR": return "\(Int(value.rounded())) bpm"
        case "Sleep": return "\(Int(value / 60))h \(Int(value) % 60)m"
        default: return "\(Int(value.rounded()).formatted()) steps"
        }
    }
}

private final class TrendsSelection: ObservableObject {
    @Published var metric = "Steps"
}

struct SleepView: View {
    let snapshot: HealthSnapshot?
    private var day: HealthDay? { snapshot?.days.first(where: { $0.sleep != nil }) }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                PageTitle(kicker: "Rest and restore", title: "Sleep")
                if let day, let sleep = day.sleep {
                    SurfaceCard {
                        VStack(alignment: .leading, spacing: 17) {
                            HStack {
                                Text("LAST RECORDED SESSION").font(.system(size: 10, weight: .bold, design: .rounded)).tracking(1).foregroundStyle(GoopStyle.muted)
                                Spacer()
                                Image(systemName: "moon.zzz.fill")
                            }
                            Text(formatMinutes(sleep.minutesAsleep)).font(.system(size: 40, weight: .medium, design: .rounded)).tracking(-1.5)
                            if let start = sleep.startTime, let end = sleep.endTime {
                                HStack { Text(start.formatted(date: .omitted, time: .shortened)); Spacer(); Text(end.formatted(date: .omitted, time: .shortened)) }
                                    .font(.system(size: 10, weight: .medium, design: .rounded)).foregroundStyle(GoopStyle.muted)
                            }
                        }
                    }
                    SurfaceCard {
                        VStack(alignment: .leading, spacing: 13) {
                            Text("SLEEP STAGES").font(.system(size: 10, weight: .bold, design: .rounded)).tracking(1.1).foregroundStyle(GoopStyle.muted)
                            StageRow(name: "Deep", time: formatMinutes(sleep.deepMinutes), share: fraction(sleep.deepMinutes, sleep.minutesAsleep), color: GoopStyle.ink)
                            StageRow(name: "REM", time: formatMinutes(sleep.remMinutes), share: fraction(sleep.remMinutes, sleep.minutesAsleep), color: GoopStyle.muted)
                            StageRow(name: "Light", time: formatMinutes(sleep.lightMinutes), share: fraction(sleep.lightMinutes, sleep.minutesAsleep), color: GoopStyle.lime)
                            StageRow(name: "Awake", time: formatMinutes(sleep.awakeMinutes), share: fraction(sleep.awakeMinutes, sleep.minutesInBed), color: GoopStyle.ink.opacity(0.25))
                        }
                    }
                    HStack(spacing: 12) {
                        MetricCard(title: "Resting HR", value: day.restingHeartRate.map { "\($0) bpm" } ?? "—", caption: "Synced measurement", icon: "heart.fill")
                        MetricCard(title: "HRV", value: day.hrvMilliseconds.map { "\(Int($0.rounded())) ms" } ?? "—", caption: "Synced measurement", icon: "waveform.path.ecg")
                    }
                } else {
                    NoDataMessage(title: "No sleep data yet", detail: "Sync your Fitbit Air in Google Health. GOOP will show the recorded sleep session and stages here.")
                }
                Text("Sleep stages and durations are reported by Google Health. GOOP does not diagnose sleep disorders.")
                    .font(.system(size: 10, design: .rounded)).foregroundStyle(GoopStyle.muted).padding(.bottom, 18)
            }
            .padding(.horizontal, 20).padding(.top, 14)
        }
        .background(GoopStyle.canvas)
    }

    private func fraction(_ value: Int?, _ total: Int?) -> CGFloat {
        guard let value, let total, total > 0 else { return 0 }
        return min(1, CGFloat(value) / CGFloat(total))
    }

    private func formatMinutes(_ value: Int?) -> String {
        guard let value else { return "—" }
        return "\(value / 60)h \(value % 60)m"
    }
}

private struct StageRow: View {
    let name: String
    let time: String
    let share: CGFloat
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(name).font(.system(size: 12, weight: .medium, design: .rounded)).frame(width: 42, alignment: .leading)
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(GoopStyle.ink.opacity(0.05))
                    Capsule().fill(color).frame(width: geometry.size.width * share)
                }
            }.frame(height: 6)
            Text(time).font(.system(size: 10, weight: .semibold, design: .rounded)).frame(width: 52, alignment: .trailing)
        }
    }
}
