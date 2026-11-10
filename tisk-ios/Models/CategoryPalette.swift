import SwiftUI

/// Preset swatches for new categories. Stored as `#RRGGBB` strings.
struct CategorySwatch: Identifiable, Hashable {
    let name: String
    let background: String
    let border: String

    var id: String { name }

    static let all: [CategorySwatch] = [
        .init(name: "Yellow", background: "#F6C848", border: "#B8901A"),
        .init(name: "Orange", background: "#F5A04A", border: "#B56A17"),
        .init(name: "Red", background: "#EF7B7B", border: "#B04444"),
        .init(name: "Green", background: "#7CCB8A", border: "#46904F"),
        .init(name: "Blue", background: "#6FA8F0", border: "#3A6FB5"),
        .init(name: "Purple", background: "#B28DEB", border: "#7A55B3"),
        .init(name: "Gray", background: "#B5B5BA", border: "#7C7C82"),
    ]
}

extension Color {
    /// Parses `#RRGGBB` or `RRGGBB`. Returns nil if the string is not valid hex.
    init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let value = UInt32(s, radix: 16) else { return nil }
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}

extension Color {
    /// Uppercase `#RRGGBB` string (sRGB), suitable for storing in the database.
    var hexString: String {
        let ui = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        func byte(_ v: CGFloat) -> Int { Int((min(max(v, 0), 1) * 255).rounded()) }
        return String(format: "#%02X%02X%02X", byte(r), byte(g), byte(b))
    }

    /// A darker shade of the same hue, used for the category border color.
    var darkenedHexString: String {
        let ui = UIColor(self)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return Color(UIColor(hue: h, saturation: s, brightness: b * 0.72, alpha: 1)).hexString
    }
}
