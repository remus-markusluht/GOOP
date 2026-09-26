import SwiftUI

enum GoopStyle {
    // Warm Tempo: espresso surfaces, linen type, and a restrained burnt-coral signal.
    static let canvas = Color(hex: 0x171311)
    static let ink = Color(hex: 0xF4E9D9)
    static let muted = Color(hex: 0xB7A69A)
    static let terracotta = Color(hex: 0xEA835D)
    static let clay = Color(hex: 0x8E6353)
    static let ember = Color(hex: 0xC96A4A)
    static let panel = Color(hex: 0x241D19)
    static let line = Color(hex: 0xF4E9D9).opacity(0.12)

    static let backgroundGradient = LinearGradient(
        colors: [Color(hex: 0x2B1A15), canvas, Color(hex: 0x120F0D)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let panelGradient = LinearGradient(
        colors: [Color(hex: 0x30231D), panel],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let heroGradient = LinearGradient(
        colors: [ember, clay, Color(hex: 0x332019)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static var localDateKey: String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: .now)
    }
}

extension Color {
    fileprivate init(hex: UInt) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

struct GoopCardPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .brightness(configuration.isPressed ? 0.06 : 0)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}
