import SwiftUI

struct PageTitle: View {
    let kicker: String
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(kicker.uppercased()).font(.system(size: 10, weight: .bold, design: .rounded)).tracking(1.4).foregroundStyle(GoopStyle.muted)
            Text(title).font(.system(size: 30, weight: .semibold, design: .rounded)).tracking(-0.8).foregroundStyle(GoopStyle.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct GoopRefreshToolbarButton: ToolbarContent {
    let action: () async -> Void

    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                Task { await action() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .tint(GoopStyle.terracotta)
            .accessibilityLabel("Refresh health data")
        }
    }
}

struct SurfaceCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .foregroundStyle(GoopStyle.ink)
            .padding(18)
            .background(GoopStyle.panelGradient, in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(GoopStyle.line, lineWidth: 1))
            .shadow(color: GoopStyle.ember.opacity(0.10), radius: 18, x: 0, y: 8)
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let caption: String
    let icon: String
    var interactionHint: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(GoopStyle.terracotta)
                    .frame(width: 28, height: 28)
                    .background(GoopStyle.ember.opacity(0.14), in: RoundedRectangle(cornerRadius: 9))
                Spacer()
                if interactionHint != nil {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(GoopStyle.terracotta)
                        .padding(.trailing, 4)
                }
                Text(title.uppercased()).font(.system(size: 9, weight: .bold, design: .rounded)).tracking(1).foregroundStyle(GoopStyle.muted)
            }
            Text(value).font(.system(size: 26, weight: .medium, design: .rounded)).tracking(-0.7).foregroundStyle(GoopStyle.ink)
            Text((interactionHint ?? caption).uppercased())
                .font(.system(size: 8, weight: .bold, design: .rounded))
                .tracking(0.8)
                .foregroundStyle(interactionHint == nil ? GoopStyle.muted : GoopStyle.terracotta)
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(GoopStyle.panelGradient, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(GoopStyle.line, lineWidth: 1))
    }
}

struct SmallStat: View {
    let label: String
    let value: String
    let unit: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased()).font(.system(size: 8, weight: .bold, design: .rounded)).tracking(0.8).foregroundStyle(GoopStyle.muted)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value).font(.system(size: 19, weight: .semibold, design: .rounded))
                Text(unit).font(.system(size: 8, weight: .bold, design: .rounded)).foregroundStyle(GoopStyle.muted)
            }
        }
    }
}

struct NoDataMessage: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.system(size: 15, weight: .semibold, design: .rounded))
            Text(detail).font(.system(size: 12, design: .rounded)).foregroundStyle(GoopStyle.muted).lineSpacing(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(17)
        .background(GoopStyle.panel, in: RoundedRectangle(cornerRadius: 20))
    }
}

struct HistoryLine: View {
    let values: [Double?]

    var body: some View {
        GeometryReader { geometry in
            let valid = values.compactMap { $0 }
            let low = valid.min() ?? 0
            let high = valid.max() ?? 1
            let points: [CGPoint] = values.enumerated().compactMap { index, value in
                guard let value else { return nil }
                let x = geometry.size.width * CGFloat(index) / CGFloat(max(values.count - 1, 1))
                let normalized = high == low ? 0.5 : (value - low) / (high - low)
                let y = geometry.size.height * (1 - normalized)
                return CGPoint(x: x, y: y)
            }

            ZStack {
                ForEach(1..<4, id: \.self) { row in
                    Path { path in
                        let y = geometry.size.height * CGFloat(row) / 4
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                    }.stroke(GoopStyle.ink.opacity(0.08), style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
                }
                Path { path in
                    guard let first = points.first else { return }
                    path.move(to: first)
                    for point in points.dropFirst() { path.addLine(to: point) }
                }.stroke(GoopStyle.ember, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                if let last = points.last {
                    Circle().fill(GoopStyle.ember).frame(width: 8, height: 8).position(last)
                }
            }
        }
    }
}
