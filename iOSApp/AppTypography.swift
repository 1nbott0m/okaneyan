import SwiftUI
import UIKit
import CoreText

enum AppPalette {
    // Values mirror the semantic roles in preview/index.html and design/05-design-system.md.
    static let accent = adaptive(light: 0x805D66, dark: 0xEFA8BE)
    static let softAccent = adaptive(light: 0xD99AAB, dark: 0xEFA8BE)
    static let canvas = adaptive(light: 0xF5F1F2, dark: 0x111011)
    static let surface = adaptive(light: 0xFFFCFD, dark: 0x1D1A1B)
    static let raisedSurface = adaptive(light: 0xEEE7E9, dark: 0x262123)
    static let line = adaptive(light: 0xDED6D9, dark: 0x393235)
    static let muted = adaptive(light: 0x766D70, dark: 0xB5A9AD)
    static let controlBorder = adaptive(light: 0x8D8185, dark: 0x766A6E)
    static let rosePale = adaptive(light: 0xF2E1E6, dark: 0x34252A)
    static let hero = adaptive(light: 0x171516, dark: 0x1D1A1B)
    static let heroInk = adaptive(light: 0xF6F0F2, dark: 0xF6F0F2)
    static let heroMuted = adaptive(light: 0xB5A9AD, dark: 0xB5A9AD)
    static let heroLine = adaptive(light: 0x393235, dark: 0x393235)
    static let heroAccent = adaptive(light: 0xEFA8BE, dark: 0xEFA8BE)
    static let metalEdge = adaptive(light: 0x766A6E, dark: 0x766A6E)
    static let metalHighlight = adaptive(light: 0xEEE5E7, dark: 0xEEE5E7)

    private static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            color(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }

    private static func color(hex: UInt32) -> UIColor {
        UIColor(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

/// Bundled font roles shared by the native app and its web review surface.
enum AppTypography {
    private static let fontsRegistered: Void = {
        ["Oswald[wght]", "Onest[wght]", "GolosText[wght]"].forEach { resource in
            guard let url = Bundle.main.url(forResource: resource, withExtension: "ttf") else { return }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }()

    static func display(_ size: CGFloat, weight: UIFont.Weight = .semibold) -> Font {
        let selectedWeight: Font.Weight = weight >= .semibold ? .semibold : .medium
        return font("Oswald-Regular", size: size, relativeTo: .largeTitle, weight: selectedWeight)
    }

    static func ui(_ size: CGFloat, weight: UIFont.Weight = .regular) -> Font {
        font("Onest-Regular", size: size, relativeTo: .body, weight: swiftUIWeight(weight))
    }

    static func amount(_ size: CGFloat, weight: UIFont.Weight = .medium) -> Font {
        font("Onest-Regular", size: size, relativeTo: .body, weight: swiftUIWeight(weight)).monospacedDigit()
    }

    /// Golos Text is reserved for short Russian details after the Onest/Golos comparison.
    static func detail(_ size: CGFloat, weight: UIFont.Weight = .regular) -> Font {
        font("GolosText-Regular", size: size, relativeTo: .caption, weight: swiftUIWeight(weight))
    }

    private static func font(_ postScriptName: String, size: CGFloat, relativeTo textStyle: Font.TextStyle,
                             weight: Font.Weight) -> Font {
        _ = fontsRegistered
        guard UIFont(name: postScriptName, size: size) != nil else {
            return .system(size: size, weight: weight, design: .default)
        }
        return .custom(postScriptName, size: size, relativeTo: textStyle).weight(weight)
    }

    private static func swiftUIWeight(_ weight: UIFont.Weight) -> Font.Weight {
        if weight >= .bold { return .bold }
        if weight >= .semibold { return .semibold }
        if weight >= .medium { return .medium }
        return .regular
    }
}
