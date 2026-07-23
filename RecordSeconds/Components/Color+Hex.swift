import SwiftUI

extension Color {
    /// Accepts a 6-digit hex string like "1C1C1E" (no leading #).
    init(hex: String) {
        var hexValue: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&hexValue)
        let r = Double((hexValue & 0xFF0000) >> 16) / 255
        let g = Double((hexValue & 0x00FF00) >> 8) / 255
        let b = Double(hexValue & 0x0000FF) / 255
        self.init(red: r, green: g, blue: b)
    }

    /// Round-trips back to a 6-digit hex string (best effort, sRGB).
    var hexString: String {
        guard let components = UIColor(self).cgColor.components, components.count >= 3 else { return "1C1C1E" }
        let r = Int((components[0] * 255).rounded())
        let g = Int((components[1] * 255).rounded())
        let b = Int((components[2] * 255).rounded())
        return String(format: "%02X%02X%02X", r, g, b)
    }
}
