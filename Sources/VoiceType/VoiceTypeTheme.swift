import AppKit
import SwiftUI

struct VoiceTypePalette {
    let canvas: Color
    let surface: Color
    let field: Color
    let ink: Color
    let stroke: Color
    let coral: Color
    let aqua: Color
    let danger: Color

    init(_ colorScheme: ColorScheme) {
        switch colorScheme {
        case .dark:
            canvas = Color(red: 0.024, green: 0.082, blue: 0.071) // Tiro ink
            surface = Color(red: 0.055, green: 0.184, blue: 0.157) // Forest glass
            field = Color(red: 0.035, green: 0.122, blue: 0.102) // Recessed nib
            ink = Color(red: 0.941, green: 0.992, blue: 0.965) // Mint paper
            stroke = Color(red: 0.145, green: 0.310, blue: 0.263) // Quiet green line
            coral = Color(red: 0.941, green: 0.722, blue: 0.271) // Gold writing tip
            aqua = Color(red: 0.576, green: 0.863, blue: 0.706) // Mint nib
            danger = Color(red: 1.000, green: 0.455, blue: 0.412)
        default:
            canvas = Color(red: 0.933, green: 0.961, blue: 0.945) // Sage paper
            surface = Color(red: 0.984, green: 0.992, blue: 0.984) // Clean sheet
            field = Color(red: 0.886, green: 0.929, blue: 0.902) // Soft mint well
            ink = Color(red: 0.043, green: 0.141, blue: 0.114) // Tiro ink
            stroke = Color(red: 0.753, green: 0.835, blue: 0.792) // Quiet green line
            coral = Color(red: 0.659, green: 0.424, blue: 0.031) // Accessible gold
            aqua = Color(red: 0.137, green: 0.486, blue: 0.337) // Accessible mint
            danger = Color(red: 0.765, green: 0.192, blue: 0.157)
        }
    }
}

struct TiroBrandMark: View {
    let size: CGFloat
    var showsShadow = true

    var body: some View {
        Image(nsImage: TiroBrandAsset.image)
            .resizable()
            .interpolation(.high)
            .frame(width: size, height: size)
            .shadow(
                color: .black.opacity(showsShadow ? 0.20 : 0),
                radius: size * 0.10,
                y: size * 0.05
            )
            .accessibilityLabel("Tiro")
    }
}

@MainActor
private enum TiroBrandAsset {
    static let image: NSImage = {
        guard let iconURL = Bundle.main.url(
            forResource: "AppIcon",
            withExtension: "svg"
        ), let image = NSImage(contentsOf: iconURL) else {
            return NSApp.applicationIconImage
        }
        return image
    }()
}
