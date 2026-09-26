import SwiftUI

struct WorkoutsView: View {
    let snapshot: HealthSnapshot?
    private var workouts: [WorkoutSummary] { snapshot?.workouts ?? [] }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PageTitle(kicker: "Training log", title: "Workouts")
                if workouts.isEmpty {
                    NoDataMessage(title: "No workouts synced", detail: "Activities recorded by your Fitbit will appear here after Google Health syncs them.")
                } else {
                    ForEach(workouts) { workout in
                        NavigationLink { WorkoutDetailView(workout: workout) } label: {
                            SurfaceCard {
                                HStack(alignment: .top, spacing: 13) {
                                    Image(systemName: icon(for: workout.type))
                                        .font(.system(size: 18, weight: .semibold))
                                        .frame(width: 42, height: 42)
                                        .background(GoopStyle.lime, in: RoundedRectangle(cornerRadius: 13))
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(workout.name).font(.system(size: 15, weight: .semibold, design: .rounded))
                                        Text(workout.startTime.formatted(date: .abbreviated, time: .shortened))
                                            .font(.system(size: 10, design: .rounded)).foregroundStyle(GoopStyle.muted)
                                        Text(summary(workout)).font(.system(size: 11, design: .rounded)).foregroundStyle(GoopStyle.muted)
                                    }
                                    Spacer(minLength: 4)
                                    Image(systemName: "chevron.right").font(.system(size: 10, weight: .bold)).foregroundStyle(GoopStyle.muted)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                Text("Workout sessions are recorded by your connected device and provided by Google Health.")
                    .font(.system(size: 10, design: .rounded)).foregroundStyle(GoopStyle.muted).padding(.bottom, 20)
            }
            .padding(.horizontal, 20).padding(.top, 16)
        }
        .background(GoopStyle.canvas)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func summary(_ workout: WorkoutSummary) -> String {
        [duration(workout.activeDurationSeconds), workout.distanceMeters.map { String(format: "%.2f km", $0 / 1000) }, workout.averageHeartRate.map { "\($0) bpm avg" }]
            .compactMap { $0 }.joined(separator: " · ")
    }

    private func duration(_ seconds: Int?) -> String? {
        guard let seconds else { return nil }
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
    }

    private func icon(for type: String) -> String {
        if type.contains("RUN") { return "figure.run" }
        if type.contains("WALK") { return "figure.walk" }
        if type.contains("BIKE") || type.contains("CYCL") { return "bicycle" }
        if type.contains("SWIM") { return "figure.pool.swim" }
        return "figure.mixed.cardio"
    }
}

private struct WorkoutDetailView: View {
    let workout: WorkoutSummary

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PageTitle(kicker: workout.type.replacingOccurrences(of: "_", with: " "), title: workout.name)
                SurfaceCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("SESSION").font(.system(size: 10, weight: .bold, design: .rounded)).tracking(1).foregroundStyle(GoopStyle.muted)
                        Text(workout.startTime.formatted(date: .complete, time: .shortened)).font(.system(size: 14, weight: .medium, design: .rounded))
                        Text("Ended \(workout.endTime.formatted(date: .omitted, time: .shortened))").font(.system(size: 11, design: .rounded)).foregroundStyle(GoopStyle.muted)
                    }
                }
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    detail("Active time", workout.activeDurationSeconds.map(formatDuration) ?? "—")
                    detail("Distance", workout.distanceMeters.map { String(format: "%.2f km", $0 / 1000) } ?? "—")
                    detail("Average HR", workout.averageHeartRate.map { "\($0) bpm" } ?? "—")
                    detail("Zone minutes", workout.activeZoneMinutes.map(String.init) ?? "—")
                    detail("Steps", workout.steps.map { $0.formatted() } ?? "—")
                    detail("Calories", workout.calories.map { "\(Int($0.rounded())) kcal" } ?? "—")
                }
                Text("GOOP displays workout fields returned by Google Health. Missing fields were not estimated.")
                    .font(.system(size: 10, design: .rounded)).foregroundStyle(GoopStyle.muted).padding(.bottom, 20)
            }
            .padding(.horizontal, 20).padding(.top, 16)
        }
        .background(GoopStyle.canvas)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func detail(_ title: String, _ value: String) -> some View {
        MetricCard(title: title, value: value, caption: "Synced value", icon: "chart.bar.fill")
    }

    private func formatDuration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
    }
}
