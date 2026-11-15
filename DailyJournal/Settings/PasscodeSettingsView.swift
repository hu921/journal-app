import SwiftUI

/// Turn the passcode on or off, change it, and choose Face ID.
struct PasscodeSettingsView: View {
    @ObservedObject private var lock = AppLock.shared
    @State private var isOn = PasscodeStore.isSet
    @State private var flow: PasscodeFlow?

    var body: some View {
        Form {
            Section {
                Toggle("Passcode Lock", isOn: Binding(
                    get: { isOn },
                    set: { wantOn in flow = wantOn ? .create : .turnOff }
                ))
                if isOn {
                    Button("Change Passcode") { flow = .change }
                }
            } footer: {
                Text("The app locks as soon as you leave it. If you forget the passcode, you can open the app with your iPhone passcode.")
            }

            if isOn, let label = biometryLabel {
                Section {
                    Toggle("Unlock with \(label)", isOn: $lock.useFaceID)
                }
            }
        }
        .navigationTitle("Passcode")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $flow) { flow in
            NavigationStack {
                PasscodeEntryView(flow: flow) {
                    isOn = PasscodeStore.isSet
                }
            }
            .interactiveDismissDisabled()
        }
    }

    private var biometryLabel: String? {
        switch lock.biometryType {
        case .faceID: "Face ID"
        case .touchID: "Touch ID"
        case .opticID: "Optic ID"
        default: nil
        }
    }
}

enum PasscodeFlow: String, Identifiable {
    case create, change, turnOff
    var id: String { rawValue }
}

/// Steps: check the current passcode (change, turn off), then enter and confirm a new one.
struct PasscodeEntryView: View {
    @Environment(\.dismiss) private var dismiss
    let flow: PasscodeFlow
    var onDone: () -> Void

    private enum Step { case current, new, confirm }
    @State private var step: Step
    @State private var code = ""
    @State private var firstCode = ""
    @State private var error: String?
    @State private var shake = 0

    init(flow: PasscodeFlow, onDone: @escaping () -> Void) {
        self.flow = flow
        self.onDone = onDone
        _step = State(initialValue: flow == .create ? .new : .current)
    }

    private var prompt: String {
        switch step {
        case .current: "Enter your current passcode"
        case .new: "Enter a new 4-digit passcode"
        case .confirm: "Enter it again to confirm"
        }
    }

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            Text(prompt).appFont(.title3, weight: .semibold)
            PasscodeDots(count: code.count)
                .modifier(Shake(animatableData: CGFloat(shake)))
            Text(error ?? " ").appFont(.footnote).foregroundStyle(.red)
            NumberPad(onDigit: enter, onDelete: { if !code.isEmpty { code.removeLast() } })
            Spacer()
        }
        .padding()
        .navigationTitle(flow == .turnOff ? "Turn Off Passcode" : flow == .change ? "Change Passcode" : "Set Passcode")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { onDone(); dismiss() }
            }
        }
    }

    private func enter(_ digit: Int) {
        guard code.count < 4 else { return }
        code.append(String(digit))
        guard code.count == 4 else { return }
        let entered = code
        code = ""
        switch step {
        case .current:
            guard PasscodeStore.verify(entered) else { return fail("Wrong passcode") }
            error = nil
            if flow == .turnOff {
                PasscodeStore.delete()
                AppLog.info("Passcode turned off")
                finish()
            } else {
                step = .new
            }
        case .new:
            firstCode = entered
            error = nil
            step = .confirm
        case .confirm:
            guard entered == firstCode else {
                step = .new
                return fail("Passcodes didn't match. Try again.")
            }
            PasscodeStore.set(entered)
            AppLog.info(flow == .create ? "Passcode turned on" : "Passcode changed")
            finish()
        }
    }

    private func fail(_ text: String) {
        error = text
        withAnimation(.default) { shake += 1 }
    }

    private func finish() {
        onDone()
        dismiss()
    }
}
