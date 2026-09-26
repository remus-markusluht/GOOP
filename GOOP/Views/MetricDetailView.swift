import SwiftUI

struct MetricDetailView: View {
    let metric: DetailMetric
    let snapshot: HealthSnapshot?

    private var days: [HealthDay] { (snapshot?.days ?? []).filter { $0.date <= GoopStyle.localDateKey }.sorted { $0.date < $1.date } }
    private var chartValues: [Double?] { days.map { metric.value(in: $0) } }
    private var latest: HealthDay? { days.last(where: { metric.value(in: $0) != nil }) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PageTitle(kicker: metric.kicker, title: metric.title)
                SurfaceCard {
                    VStack(alignment: .leading, spacing: 15) {
                        Text("LATEST RECORDED").font(.system(size: 10, weight: .bold, design: .rounded)).tracking(1).foregroundStyle(GoopStyle.muted)
                        Text(latest.map { metric.formatted($0) } ?? "No data yet")
                            .font(.system(size: 34, weight: .medium, design: .rounded)).tracking(-1)
                        Text(metric.explanation).font(.system(size: 12, design: .rounded)).foregroundStyle(GoopStyle.muted).lineSpacing(4)
                        HistoryLine(values: chartValues).frame(height: 120)
                        HStack { Text(days.first?.date ?? ""); Spacer(); Text(days.last?.date ?? "") }
                            .font(.system(size: 9, design: .rounded)).foregroundStyle(GoopStyle.muted)
                    }
                }
                SurfaceCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("RECENT DAYS").font(.system(size: 10, weight: .bold, design: .rounded)).tracking(1).foregroundStyle(GoopStyle.muted)
                        ForEach(days.suffix(7).reversed()) { day in
                            HStack {
                                Text(day.date).font(.system(size: 12, weight: .medium, design: .rounded))
                                Spacer()
                                Text(metric.formatted(day)).font(.system(size: 12, weight: .semibold, design: .rounded))
                            }
                            if day.id != days.suffix(7).first?.id {
                                Rectangle().fill(GoopStyle.ink.opacity(0.07)).frame(height: 1)
                            }
                        }
                    }
                }
                Text("Values come from Google Health after your Fitbit sync. GOOP does not fill missing readings.")
                    .font(.system(size: 10, design: .rounded)).foregroundStyle(GoopStyle.muted).padding(.bottom, 20)
            }
            .padding(.horizontal, 20).padding(.top, 16)
        }
        .background(GoopStyle.backgroundGradient)
        .navigationBarTitleDisplayMode(.inline)
    }
}

enum DetailMetric: String, Identifiable {
    case steps
    case activeZoneMinutes
    case sleep
    case hrv
    case restingHeartRate

    var id: String { rawValue }
    var title: String {
        switch self {
        case .steps: "Steps"
        case .activeZoneMinutes: "Active zone minutes"
        case .sleep: "Sleep"
        case .hrv: "Heart-rate variability"
        case .restingHeartRate: "Resting heart rate"
        }
    }
    var kicker: String {
        switch self {
        case .steps, .activeZoneMinutes: "Daily movement"
        case .sleep: "Rest and restore"
        case .hrv, .restingHeartRate: "Recovery signals"
        }
    }
    var explanation: String {
        switch self {
        case .steps: "Daily steps use Google's reconciled daily total, which avoids double-counting overlapping tracker and phone records."
        case .activeZoneMinutes: "This is the summed active-zone time reported by Google Health. GOOP does not convert it into WHOOP Strain."
        case .sleep: "Sleep duration and stages are supplied by Google Health from your synced device."
        case .hrv: "Daily HRV is the measurement reported by Google Health. Compare your own trend over time."
        case .restingHeartRate: "Daily resting heart rate is the measurement reported by Google Health."
        }
    }
    func value(in day: HealthDay) -> Double? {
        switch self {
        case .steps: day.steps.map(Double.init)
        case .activeZoneMinutes: day.activeZoneMinutes.map(Double.init)
        case .sleep: day.sleep?.minutesAsleep.map(Double.init)
        case .hrv: day.hrvMilliseconds
        case .restingHeartRate: day.restingHeartRate.map(Double.init)
        }
    }
    func formatted(_ day: HealthDay) -> String {
        guard let value = value(in: day) else { return "—" }
        return switch self {
        case .steps: "\(Int(value).formatted()) steps"
        case .activeZoneMinutes: "\(Int(value)) min"
        case .sleep: "\(Int(value) / 60)h \(Int(value) % 60)m"
        case .hrv: "\(Int(value.rounded())) ms"
        case .restingHeartRate: "\(Int(value.rounded())) bpm"
        }
    }
}

struct ReadinessDetailView: View {
    let day: HealthDay
    let history: [HealthDay]

    private var estimate: Int? { HealthScoreCalculator.readiness(current: day, history: history) }
    private var baselineDays: [HealthDay] {
        history.filter { $0.date < day.date }.sorted { $0.date > $1.date }.prefix(28).map { $0 }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PageTitle(kicker: "Recovery signals", title: "Readiness")
                SurfaceCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("GOOP WELLNESS ESTIMATE").font(.system(size: 10, weight: .bold, design: .rounded)).tracking(1).foregroundStyle(GoopStyle.muted)
                        Text(estimate.map(String.init) ?? "Building your baseline")
                            .font(.system(size: 36, weight: .medium, design: .rounded)).tracking(-1)
                        Text("This transparent GOOP estimate combines sleep duration, HRV and resting heart rate. It is not a medical measure or a WHOOP score.")
                            .font(.system(size: 12, design: .rounded)).foregroundStyle(GoopStyle.muted).lineSpacing(4)
                    }
                }
                metricRow("Sleep", value: day.sleep?.minutesAsleep.map { "\($0 / 60)h \($0 % 60)m" } ?? "No reading", note: "Compared with an 8-hour reference")
                metricRow("HRV", value: day.hrvMilliseconds.map { "\(Int($0.rounded())) ms" } ?? "No reading", note: baselineNote(for: day.hrvMilliseconds, values: baselineDays.compactMap(\.hrvMilliseconds), higherIsBetter: true, unit: "ms"))
                metricRow("Resting heart rate", value: day.restingHeartRate.map { "\($0) bpm" } ?? "No reading", note: baselineNote(for: day.restingHeartRate.map(Double.init), values: baselineDays.compactMap(\.restingHeartRate).map(Double.init), higherIsBetter: false, unit: "bpm"))
                Text("An estimate is shown only when there are at least seven earlier days of HRV and resting-heart-rate history plus today's sleep and readings.")
                    .font(.system(size: 10, design: .rounded)).foregroundStyle(GoopStyle.muted).padding(.bottom, 22)
            }
            .padding(.horizontal, 20).padding(.top, 16)
        }
        .background(GoopStyle.backgroundGradient)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func metricRow(_ title: String, value: String, note: String) -> some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 6) {
                Text(title.uppercased()).font(.system(size: 10, weight: .bold, design: .rounded)).tracking(1).foregroundStyle(GoopStyle.muted)
                Text(value).font(.system(size: 22, weight: .medium, design: .rounded))
                Text(note).font(.system(size: 11, design: .rounded)).foregroundStyle(GoopStyle.muted)
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func baselineNote(for current: Double?, values: [Double], higherIsBetter: Bool, unit: String) -> String {
        guard let current, !values.isEmpty else { return "Baseline is still building" }
        let sorted = values.sorted()
        let middle = sorted.count / 2
        let baseline = sorted.count.isMultiple(of: 2) ? (sorted[middle - 1] + sorted[middle]) / 2 : sorted[middle]
        let delta = current - baseline
        let direction = (delta >= 0) == higherIsBetter ? "above" : "below"
        return "\(Int(abs(delta).rounded())) \(unit) \(direction) your 28-day median"
    }
}
