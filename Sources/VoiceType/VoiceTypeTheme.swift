import SwiftUI

struct VoiceTypePalette {
    let canvas: Color
    let surface: Color
    let field: Color
    let ink: Color
    let stroke: Color
    let coral: Color
    let aqua: Color

    init(_ colorScheme: ColorScheme) {
        switch colorScheme {
        case .dark:
            canvas = Color(red: 0.063, green: 0.082, blue: 0.110) // Midnight graphite
            surface = Color(red: 0.094, green: 0.122, blue: 0.161) // Receiver
            field = Color(red: 0.043, green: 0.059, blue: 0.082) // Recessed signal bay
            ink = Color(red: 0.949, green: 0.965, blue: 0.980) // Air
            stroke = Color(red: 0.180, green: 0.224, blue: 0.282) // Quiet line
            coral = Color(red: 1.000, green: 0.459, blue: 0.412)
            aqua = Color(red: 0.439, green: 0.835, blue: 0.820)
        default:
            canvas = Color(red: 0.965, green: 0.970, blue: 0.955)
            surface = Color(red: 0.992, green: 0.994, blue: 0.988)
            field = Color(red: 0.914, green: 0.918, blue: 0.902)
            ink = Color(red: 0.090, green: 0.095, blue: 0.110)
            stroke = Color(red: 0.835, green: 0.840, blue: 0.820)
            coral = Color(red: 1.000, green: 0.420, blue: 0.370)
            aqua = Color(red: 0.390, green: 0.850, blue: 0.800)
        }
    }
}
