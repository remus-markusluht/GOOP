import Foundation

enum HealthScoreCalculator {
    static let sleepGoalMinutes = 8 * 60

    /// A transparent GOOP activity load indicator, not a clinical or WHOOP score.
    /// Fitbit awards AZM as 1 point in fat-burn and 2 in cardio/peak zones.
    static func activityLoad(activeZoneMinutes: Int?) -> Int? {
        guard let activeZoneMinutes else { return nil }
        return min(21, max(0, Int((Double(activeZoneMinutes) / 90 * 21).rounded())))
    }

    /// An estimate is shown only after at least seven previous measurements are available.
    /// It combines sleep against an 8-hour target, HRV against a 28-day median, and
    /// resting heart rate against a 28-day median. This is a GOOP wellness estimate.
    static func readiness(current: HealthDay, history: [HealthDay]) -> Int? {
        let previous = history
            .filter { $0.date < current.date }
            .sorted { $0.date > $1.date }
            .prefix(28)

        let hrvValues = previous.compactMap(\.hrvMilliseconds)
        let rhrValues = previous.compactMap(\.restingHeartRate)
        guard hrvValues.count >= 7,
              rhrValues.count >= 7,
              let currentHRV = current.hrvMilliseconds,
              let currentRHR = current.restingHeartRate,
              let sleepMinutes = current.sleep?.minutesAsleep else { return nil }

        let hrvBaseline = median(hrvValues)
        let rhrBaseline = median(rhrValues)
        guard hrvBaseline > 0, rhrBaseline > 0 else { return nil }

        let sleepComponent = min(1, max(0, Double(sleepMinutes) / Double(sleepGoalMinutes)))
        let hrvComponent = min(1, max(0, 0.5 + ((currentHRV / hrvBaseline) - 1) * 2.5))
        let rhrComponent = min(1, max(0, 0.5 + ((rhrBaseline - Double(currentRHR)) / 10)))
        return Int((100 * (sleepComponent * 0.5 + hrvComponent * 0.3 + rhrComponent * 0.2)).rounded())
    }

    private static func median(_ values: [Double]) -> Double {
        let sorted = values.sorted()
        let middle = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return (sorted[middle - 1] + sorted[middle]) / 2
        }
        return sorted[middle]
    }

    private static func median(_ values: [Int]) -> Double {
        median(values.map(Double.init))
    }
}
