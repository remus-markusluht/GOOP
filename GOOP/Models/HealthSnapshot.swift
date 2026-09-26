import Foundation

struct HealthSnapshot: Decodable {
    let user: GOOPUser
    let generatedAt: Date
    let days: [HealthDay]
    let workouts: [WorkoutSummary]?
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

struct WorkoutSummary: Decodable, Identifiable {
    let id: String
    let startTime: Date
    let endTime: Date
    let name: String
    let type: String
    let activeDurationSeconds: Int?
    let distanceMeters: Double?
    let calories: Double?
    let steps: Int?
    let averageHeartRate: Int?
    let activeZoneMinutes: Int?
}

enum GOOPConnectionState: Equatable {
    case signedOut
    case connecting
    case connected
    case loading
    case failed(String)
}
