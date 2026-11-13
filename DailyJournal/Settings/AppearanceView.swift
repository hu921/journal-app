import SwiftUI

/// Theme, font, font size, auto title and calendar photos.
struct AppearanceView: View {
    @AppStorage(SettingsKey.theme) private var theme = AppTheme.system.rawValue
    @AppStorage(SettingsKey.fontFamily) private var family = AppFontFamily.system.rawValue
    @AppStorage(SettingsKey.useCustomFontSize) private var useCustomSize = false
    @AppStorage(SettingsKey.customFontSize) private var customSize = 17.0
    @AppStorage(SettingsKey.autoTitleFirstLine) private var autoTitle = true
    @AppStorage(SettingsKey.showCalendarPhotos) private var calendarPhotos = true

    private static let sizeRange = 10.0...40.0

    var body: some View {
        Form {
            Section("Theme") {
                Picker("Theme", selection: $theme) {
                    ForEach(AppTheme.allCases) { Text($0.label).tag($0.rawValue) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            Section("Font") {
                Picker("Font", selection: $family) {
                    ForEach(AppFontFamily.allCases) { f in
                        Text(f.label)
                            .font(f.familyName.map { .custom($0, size: 17) } ?? .body)
                            .tag(f.rawValue)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }

            Section {
                Picker("Font Size", selection: $useCustomSize) {
                    Text("System").tag(false)
                    Text("Custom").tag(true)
                }
                .pickerStyle(.segmented)

                if useCustomSize {
                    HStack {
                        Text("Size (pt)")
                        Spacer()
                        TextField("17", value: $customSize, format: .number.precision(.fractionLength(0)))
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                            .onChange(of: customSize) { _, new in
                                let clamped = min(max(new, Self.sizeRange.lowerBound), Self.sizeRange.upperBound)
                                if clamped != new { customSize = clamped }
                            }
                        Stepper("", value: $customSize, in: Self.sizeRange, step: 1)
                            .labelsHidden()
                    }
                }

                Text("The quick brown fox writes in a journal.")
                    .appFont(.body)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Font Size")
            } footer: {
                Text(useCustomSize ? "Choose 10 to 40 pt." : "Follows the text size in iOS Settings.")
            }

            Section {
                Toggle("Auto Title First Line", isOn: $autoTitle)
                Toggle("Show Photos in Calendar", isOn: $calendarPhotos)
            } footer: {
                Text("Auto title uses the first line of your text as the entry title.")
            }
        }
        .navigationTitle("Appearance")
        .navigationBarTitleDisplayMode(.inline)
    }
}
