import SwiftUI

// Shared ocean and paper colors; each screen controls its own illustration density.
enum CreationPalette {
    static let ocean = Color(red: 0.035, green: 0.20, blue: 0.24)
    static let ink = Color(red: 0.13, green: 0.27, blue: 0.29)
    static let mutedInk = Color(red: 0.35, green: 0.43, blue: 0.43)
    static let paper = Color(red: 0.98, green: 0.96, blue: 0.91)
    static let pearl = Color(red: 1, green: 0.97, blue: 0.90)
    static let coral = Color(red: 1, green: 0.76, blue: 0.65)
}

struct CreationOceanBackground: View {
    var body: some View {
        GeometryReader { geometry in
            Image("CreationOcean").resizable().scaledToFill()
                .frame(width: max(0, geometry.size.width), height: max(0, geometry.size.height)).clipped()
                .overlay {
                    LinearGradient(stops: [
                        .init(color: CreationPalette.ocean.opacity(0.64), location: 0),
                        .init(color: CreationPalette.ocean.opacity(0.24), location: 0.42),
                        .init(color: CreationPalette.ocean.opacity(0.40), location: 1),
                    ], startPoint: .top, endPoint: .bottom)
                }
        }
        .background(CreationPalette.ocean)
        .ignoresSafeArea().allowsHitTesting(false).accessibilityHidden(true)
    }
}

struct CreationPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.78 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
    }
}
