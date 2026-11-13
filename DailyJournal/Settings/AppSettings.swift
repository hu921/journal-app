import SwiftUI

/// Keys and choices for settings saved on this device.
enum SettingsKey {
    static let theme = "appTheme"
    static let fontFamily = "appFontFamily"
    static let useCustomFontSize = "useCustomFontSize"
    static let customFontSize = "customFontSize"
    static let autoTitleFirstLine = "autoTitleFirstLine"
    static let showCalendarPhotos = "showCalendarPhotos"
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

    func body(content: Content) -> some View {
        content
            .appFont(.body)
            .preferredColorScheme((AppTheme(rawValue: theme) ?? .system).colorScheme)
    }
}
