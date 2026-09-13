import SwiftUI

enum WireframeColor: String, CaseIterable, Identifiable {
    case ink, green, blue, violet

    var id: String { rawValue }
    var title: String { rawValue.capitalized }

    // Each ink has a light/dark counterpart against Tiro's paper/forest surface.
    // Gold stays reserved for labels so text remains distinct from outlines.
    func color(in scheme: ColorScheme) -> Color {
        let hex: UInt32
        switch (self, scheme) {
        case (.ink, .dark): hex = 0xF0FDF6
        case (.green, .dark): hex = 0x93DCB4
        case (.blue, .dark): hex = 0x90BBFF
        case (.violet, .dark): hex = 0xD9ADF2
        case (.ink, _): hex = 0x0B241D
        case (.green, _): hex = 0x237C56
        case (.blue, _): hex = 0x245AB5
        case (.violet, _): hex = 0x8542A0
        }
        return Color(
            red: Double((hex >> 16) & 255) / 255,
            green: Double((hex >> 8) & 255) / 255,
            blue: Double(hex & 255) / 255
        )
    }
}
