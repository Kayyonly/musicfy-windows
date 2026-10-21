import SwiftUI

enum MusicfyTheme {
    static let background = Color.black
    static let primary = Color.white
    static let secondary = Color(hex: 0x9A9AA0)
    static let surface = Color(hex: 0x0F0F0F)
    static let field = Color(hex: 0x141416)
    static let divider = Color(hex: 0x232326)
    static let chrome = Color(hex: 0x0F0F12)
    static let selected = Color.white.opacity(0.2)
    static let opaqueSelection = Color(hex: 0x45454A)
    static let navigationSecondary = Color(hex: 0xC3C3C8)

    // Original tonal placeholders, not colors extracted from commercial covers.
    static func artworkColors(_ index: Int) -> [Color] {
        let palettes: [[UInt32]] = [
            [0x323139, 0x8B8580], [0x613F24, 0x181317],
            [0x08629D, 0xD67529], [0x739060, 0xD2DEBE],
            [0x834E34, 0x222329], [0x294E49, 0x1A242D],
            [0xC9D3D4, 0x899FA4]
        ]
        return palettes[abs(index % palettes.count)].map { Color(hex: $0) }
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB, red: Double((hex >> 16) & 255) / 255,
                  green: Double((hex >> 8) & 255) / 255,
                  blue: Double(hex & 255) / 255, opacity: 1)
    }
}
