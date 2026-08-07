import AgentforceSDK
import SwiftUI
import UIKit

enum AppearanceConfiguration {
    static func theming(from config: [String: Any]) throws -> AgentforceTheming? {
        guard let raw = config["appearance"] as? [String: Any] else { return nil }
        let light = try colors(raw["lightColors"], field: "lightColors")
        let dark = try colors(raw["darkColors"], field: "darkColors")
        let icons = try icons(raw["icons"])
        let displayNames = try displayNames(raw["displayNames"])
        let typography = try typography(raw["typography"])
        return .overrides(AgentforceThemeOverrides(
            light: light,
            dark: dark,
            icons: icons,
            displayNames: displayNames,
            fonts: typography.fonts,
            fontFamilyName: typography.family
        ))
    }

    static func themeMode(from config: [String: Any]) throws -> String? {
        guard let raw = config["appearance"] as? [String: Any], let mode = raw["themeMode"] as? String else {
            return nil
        }
        switch mode {
        case "system", "light", "dark": return mode
        default: throw AppearanceError.invalid("appearance.themeMode must be 'system', 'light', or 'dark'")
        }
    }

    static func hasOverrides(from config: [String: Any]) -> Bool {
        guard let raw = config["appearance"] as? [String: Any] else { return false }
        return raw["lightColors"] != nil || raw["darkColors"] != nil || raw["icons"] != nil ||
            raw["displayNames"] != nil || raw["typography"] != nil
    }

    static func themeManager(for mode: String) -> AgentforceThemeManager {
        switch mode {
        case "system": return AgentforceDefaultThemeManager(themeMode: .system)
        case "dark": return AgentforceDefaultThemeManager(themeMode: .dark)
        default: return AgentforceDefaultThemeManager(themeMode: .light)
        }
    }

    private static func colors(_ value: Any?, field: String) throws -> [AgentforceColorToken: Color] {
        guard let values = value as? [String: String] else { return [:] }
        return try values.reduce(into: [:]) { result, entry in
            guard let token = AgentforceColorToken(rawValue: entry.key) else {
                throw AppearanceError.invalid("Unsupported iOS color token '\(entry.key)'")
            }
            result[token] = try color(entry.value, field: "appearance.\(field).\(entry.key)")
        }
    }

    private static func color(_ value: String, field: String) throws -> Color {
        let hex = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard hex.hasPrefix("#"), hex.count == 7 || hex.count == 9,
              let number = UInt64(hex.dropFirst(), radix: 16) else {
            throw AppearanceError.invalid("\(field) must be #RRGGBB or #AARRGGBB")
        }
        let rgba: (UInt64, UInt64, UInt64, UInt64)
        if hex.count == 7 {
            rgba = ((number >> 16) & 0xff, (number >> 8) & 0xff, number & 0xff, 0xff)
        } else {
            rgba = ((number >> 16) & 0xff, (number >> 8) & 0xff, number & 0xff, (number >> 24) & 0xff)
        }
        return Color(.sRGB, red: Double(rgba.0) / 255, green: Double(rgba.1) / 255,
                     blue: Double(rgba.2) / 255, opacity: Double(rgba.3) / 255)
    }

    private static func icons(_ value: Any?) throws -> [AgentforceIconType: AgentforceIcon] {
        guard let values = value as? [String: Any] else { return [:] }
        return try values.reduce(into: [:]) { result, entry in
            guard let type = AgentforceIconType.allCases.first(where: { String(describing: $0) == entry.key }),
                  let platforms = entry.value as? [String: Any],
                  let ios = platforms["ios"] as? [String: String], let light = ios["light"] else {
                throw AppearanceError.invalid("appearance.icons.\(entry.key) requires ios.light")
            }
            guard let lightImage = UIImage(named: light) else {
                throw AppearanceError.invalid("iOS image asset '\(light)' for \(entry.key) was not found")
            }
            if let dark = ios["dark"] {
                guard let darkImage = UIImage(named: dark) else {
                    throw AppearanceError.invalid("iOS image asset '\(dark)' for \(entry.key) was not found")
                }
                result[type] = AgentforceIcon(lightModeIcon: Image(uiImage: lightImage), darkModeIcon: Image(uiImage: darkImage))
            } else {
                result[type] = AgentforceIcon(Image(uiImage: lightImage))
            }
        }
    }

    private static func displayNames(_ value: Any?) throws -> [AgentforceDisplayNameType: String] {
        guard let values = value as? [String: String] else { return [:] }
        return try values.reduce(into: [:]) { result, entry in
            guard let type = AgentforceDisplayNameType.allCases.first(where: { String(describing: $0) == entry.key }),
                  !entry.value.isEmpty else {
                throw AppearanceError.invalid("Unsupported or empty iOS display-name token '\(entry.key)'")
            }
            result[type] = entry.value
        }
    }

    private static func typography(_ value: Any?) throws -> (family: String?, fonts: [AgentforceFontStyle: AgentforceFontOverride]) {
        guard let raw = value as? [String: Any] else { return (nil, [:]) }
        let family = try fontFamily(raw["fontFamily"])
        guard let styles = raw["styles"] as? [String: [String: Any]] else { return (family, [:]) }
        let fonts = try styles.reduce(into: [AgentforceFontStyle: AgentforceFontOverride]()) { result, entry in
            guard let style = fontStyle(entry.key) else {
                throw AppearanceError.invalid("Unsupported iOS typography style '\(entry.key)'")
            }
            let size = entry.value["size"] as? NSNumber
            if let size, (!size.doubleValue.isFinite || size.doubleValue <= 0 || size.doubleValue > 512) {
                throw AppearanceError.invalid("appearance.typography.styles.\(entry.key).size must be between 0 and 512")
            }
            let weight = try fontWeight(entry.value["weight"])
            let styleFamily = try fontFamily(entry.value["fontFamily"])
            result[style] = AgentforceFontOverride(size: size.map { CGFloat($0.doubleValue) }, weight: weight, fontFamilyName: styleFamily)
        }
        return (family, fonts)
    }

    private static func fontStyle(_ value: String) -> AgentforceFontStyle? {
        // Android's public names include `Font` (for example,
        // `bodyFontScale1Regular`), while the iOS SDK omits it. Accept both
        // spellings so a shared JS appearance object maps to the same token.
        AgentforceFontStyle(rawValue: value) ??
            AgentforceFontStyle(rawValue: value.replacingOccurrences(of: "FontScale", with: "Scale"))
    }

    private static func fontFamily(_ value: Any?) throws -> String? {
        guard let raw = value as? [String: Any] else { return nil }
        switch raw["type"] as? String {
        case "generic":
            switch raw["family"] as? String {
            case "default", "sans-serif": return nil
            case "serif": return "Georgia"
            case "monospace": return "Menlo"
            case "cursive": return "Snell Roundhand"
            default: throw AppearanceError.invalid("Unsupported generic font family")
            }
        case "bundled":
            guard let ios = raw["ios"] as? [String: String], let name = ios["name"], UIFont(name: name, size: 12) != nil else {
                throw AppearanceError.invalid("Bundled iOS font must name a registered font")
            }
            return name
        case .none: return nil
        default: throw AppearanceError.invalid("appearance typography font family is invalid")
        }
    }

    private static func fontWeight(_ value: Any?) throws -> Font.Weight? {
        guard let value = value as? NSNumber else { return nil }
        switch value.intValue {
        case 100: return .ultraLight; case 200: return .thin; case 300: return .light
        case 400: return .regular; case 500: return .medium; case 600: return .semibold
        case 700: return .bold; case 800: return .heavy; case 900: return .black
        default: throw AppearanceError.invalid("Typography weight must be one of 100 through 900 in increments of 100")
        }
    }
}

enum AppearanceError: LocalizedError {
    case invalid(String)
    var errorDescription: String? { if case let .invalid(message) = self { return message }; return nil }
}
