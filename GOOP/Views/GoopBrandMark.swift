import SwiftUI

/// Uses the same source artwork as the home-screen icon, so the in-app logo
/// cannot drift into a different interpretation of the GOOP mark.
struct GoopBrandMark: View {
    var size: CGFloat = 48

    var body: some View {
        Image("GoopBrandSymbol")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

struct GoopWordmark: View {
    var markSize: CGFloat = 48

    var body: some View {
        HStack(spacing: 12) {
            GoopBrandMark(size: markSize)
            Text("GOOP")
                .font(.system(size: markSize * 0.74, weight: .black, design: .rounded))
                .tracking(markSize * 0.025)
                .foregroundStyle(GoopStyle.ink)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("GOOP")
    }
}
