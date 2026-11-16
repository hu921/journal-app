import SwiftUI

/// Keys and choices for settings saved on this device.
enum SettingsKey {
    static let theme = "appTheme"
    static let fontFamily = "appFontFamily"
    static let useCustomFontSize = "useCustomFontSize"
    static let customFontSize = "customFontSize"
    static let autoTitleFirstLine = "autoTitleFirstLine"
    static let showCalendarPhotos = "showCalendarPhotos"
    static let appColor = "appColor"
}

enum AppTheme: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

enum AppFontFamily: String, CaseIterable, Identifiable {
    case system, roboto, helveticaNeue, lato, openSans
    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: "System"
        case .roboto: "Roboto"
        case .helveticaNeue: "Helvetica Neue"
        case .lato: "Lato"
        case .openSans: "Open Sans"
        }
    }

    /// Font family name passed to Font.custom. nil means the iOS system font.
    var familyName: String? {
        switch self {
        case .system: nil
        case .roboto: "Roboto"
        case .helveticaNeue: "Helvetica Neue"
        case .lato: "Lato"
        case .openSans: "Open Sans"
        }
    }
}

/// Color theme for the app and its home screen icon.
enum AppColor: String, CaseIterable, Identifiable {
    case orange, skyBlue, grassGreen, blossomPink, metalGrey
    var id: String { rawValue }

    var label: String {
        switch self {
        case .orange: "Orange"
        case .skyBlue: "Sky Blue"
        case .grassGreen: "Grass Green"
        case .blossomPink: "Blossom Pink"
        case .metalGrey: "Metal Grey"
        }
    }

    var color: Color {
        switch self {
        case .orange: Color(red: 0.910, green: 0.478, blue: 0.290)
        case .skyBlue: Color(red: 0.290, green: 0.600, blue: 0.890)
        case .grassGreen: Color(red: 0.330, green: 0.660, blue: 0.360)
        case .blossomPink: Color(red: 0.920, green: 0.420, blue: 0.620)
        case .metalGrey: Color(red: 0.470, green: 0.500, blue: 0.540)
        }
    }

    /// Asset suffix used by the alternate icons and logos ("" for the default orange).
    private var suffix: String {
        switch self {
        case .orange: ""
        case .skyBlue: "-SkyBlue"
        case .grassGreen: "-GrassGreen"
        case .blossomPink: "-BlossomPink"
        case .metalGrey: "-MetalGrey"
        }
    }

    /// Home screen icon name; nil is the main icon.
    var iconName: String? { self == .orange ? nil : "AppIcon" + suffix }
    /// In-app copy of the icon (About page, map pins).
    var logoName: String { "AppLogo" + suffix }

    static func from(_ raw: String) -> AppColor { AppColor(rawValue: raw) ?? .orange }
}

private struct AppAccentKey: EnvironmentKey {
    static let defaultValue = AppColor.orange.color
}

extension EnvironmentValues {
    /// The chosen theme color, for places that need a Color (gradients).
    var appAccent: Color {
        get { self[AppAccentKey.self] }
        set { self[AppAccentKey.self] = newValue }
    }
}

extension UserDefaults {
    /// Auto title is on unless the person turned it off.
    var autoTitleFirstLine: Bool {
        object(forKey: SettingsKey.autoTitleFirstLine) as? Bool ?? true
    }
}

// MARK: - Font

/// Default point size of each text style at the standard text size.
private func baseSize(_ style: Font.TextStyle) -> CGFloat {
    switch style {
    case .largeTitle: 34
    case .title: 28
    case .title2: 22
    case .title3: 20
    case .headline, .body: 17
    case .callout: 16
    case .subheadline: 15
    case .footnote: 13
    case .caption: 12
    case .caption2: 11
    @unknown default: 17
    }
}

/// Applies the chosen font family and size to text.
struct AppFontModifier: ViewModifier {
    let style: Font.TextStyle
    let weight: Font.Weight?

    @AppStorage(SettingsKey.fontFamily) private var family = AppFontFamily.system.rawValue
    @AppStorage(SettingsKey.useCustomFontSize) private var useCustomSize = false
    @AppStorage(SettingsKey.customFontSize) private var customSize = 17.0

    func body(content: Content) -> some View {
        content.font(font)
    }

    private var font: Font {
        let w = weight ?? (style == .headline ? .semibold : nil)
        let name = (AppFontFamily(rawValue: family) ?? .system).familyName
        // Custom size: body text uses the typed size; other styles keep their ratio to body.
        let size = baseSize(style) * CGFloat(customSize) / 17

        var f: Font
        switch (name, useCustomSize) {
        case (nil, false): f = .system(style)
        case (nil, true): f = .system(size: size)
        case (let n?, false): f = .custom(n, size: baseSize(style), relativeTo: style)
        case (let n?, true): f = .custom(n, fixedSize: size)
        }
        if let w { f = f.weight(w) }
        return f
    }
}

extension View {
    func appFont(_ style: Font.TextStyle, weight: Font.Weight? = nil) -> some View {
        modifier(AppFontModifier(style: style, weight: weight))
    }

    /// Applies theme and default font to a whole screen tree.
    func appAppearance() -> some View {
        modifier(AppAppearanceModifier())
    }
}

struct AppAppearanceModifier: ViewModifier {
    @AppStorage(SettingsKey.theme) private var theme = AppTheme.system.rawValue
    @AppStorage(SettingsKey.appColor) private var appColor = AppColor.orange.rawValue

    func body(content: Content) -> some View {
        let accent = AppColor.from(appColor).color
        content
            .appFont(.body)
            .tint(accent)
            .environment(\.appAccent, accent)
            .preferredColorScheme((AppTheme(rawValue: theme) ?? .system).colorScheme)
    }
}
