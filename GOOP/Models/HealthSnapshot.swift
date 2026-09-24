import Foundation

struct HealthSnapshot: Decodable {
    let user: GOOPUser
    let generatedAt: Date
    let days: [HealthDay]
}

struct GOOPUser: Decodable {
    let name: String
    let email: String
}

struct HealthDay: Decodable, Identifiable {
    let date: String
    let steps: Int?
    let activeZoneMinutes: Int?
    let restingHeartRate: Int?
    let hrvMilliseconds: Double?
    let sleep: SleepSummary?

    var id: String { date }

    var activityLoad: Int? {
        HealthScoreCalculator.activityLoad(activeZoneMinutes: activeZoneMinutes)
    }
}

struct SleepSummary: Decodable {
    let startTime: Date?
    let endTime: Date?
    let minutesAsleep: Int?
    let minutesInBed: Int?
    let deepMinutes: Int?
    let remMinutes: Int?
    let lightMinutes: Int?
    let awakeMinutes: Int?
}

enum GOOPConnectionState: Equatable {
    case signedOut
    case connecting
    case connected
    case loading
    case failed(String)
}
