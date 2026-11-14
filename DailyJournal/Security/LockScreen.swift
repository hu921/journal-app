import SwiftUI
import LocalAuthentication

/// Enter the 4-digit passcode, use Face ID, or use the iPhone passcode if forgotten.
struct LockScreen: View {
    @ObservedObject private var lock = AppLock.shared
    @State private var code = ""
    @State private var shake = 0
    @State private var failedAttempts = 0
    @State private var waitUntil: Date?
    @State private var message = "Enter Passcode"

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            Image(systemName: "lock.fill")
                .font(.system(size: 36))
                .foregroundStyle(Color.accentColor)
            Text(message).appFont(.title3, weight: .semibold)

            PasscodeDots(count: code.count)
                .modifier(Shake(animatableData: CGFloat(shake)))

            NumberPad(
                onDigit: { digit in enter(digit) },
                onDelete: { if !code.isEmpty { code.removeLast() } },
                biometryIcon: lock.useFaceID ? biometryIcon : nil,
                onBiometry: { authenticate(policy: .deviceOwnerAuthenticationWithBiometrics) }
            )
            .disabled(waitUntil.map { $0 > .now } ?? false)

            Button("Forgot Passcode?") {
                authenticate(policy: .deviceOwnerAuthentication)
            }
            .appFont(.subheadline)
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .task {
            if lock.useFaceID, biometryIcon != nil {
                authenticate(policy: .deviceOwnerAuthenticationWithBiometrics)
            }
        }
    }

    private var biometryIcon: String? {
        switch lock.biometryType {
        case .faceID: "faceid"
        case .touchID: "touchid"
        case .opticID: "opticid"
        default: nil
        }
    }

    private func enter(_ digit: Int) {
        guard code.count < 4 else { return }
        code.append(String(digit))
        guard code.count == 4 else { return }
        if PasscodeStore.verify(code) {
            failedAttempts = 0
            lock.unlock(method: "passcode")
            code = ""
        } else {
            failedAttempts += 1
            AppLog.info("Wrong passcode (\(failedAttempts))")
            withAnimation(.default) { shake += 1 }
            code = ""
            if failedAttempts >= 5 {
                waitUntil = Date().addingTimeInterval(30)
                message = "Too many tries. Wait 30 seconds."
                Task {
                    try? await Task.sleep(for: .seconds(30))
                    waitUntil = nil
                    message = "Enter Passcode"
                }
            } else {
                message = "Wrong Passcode"
            }
        }
    }

    private func authenticate(policy: LAPolicy) {
        let context = LAContext()
        context.localizedFallbackTitle = policy == .deviceOwnerAuthenticationWithBiometrics ? "Enter Passcode" : nil
        let reason = policy == .deviceOwnerAuthentication
            ? "Use your iPhone passcode to open Daily Log."
            : "Unlock Daily Log."
        context.evaluatePolicy(policy, localizedReason: reason) { success, _ in
            Task { @MainActor in
                if success {
                    lock.unlock(method: policy == .deviceOwnerAuthentication ? "device passcode" : "Face ID")
                }
            }
        }
    }
}

struct PasscodeDots: View {
    let count: Int
    var body: some View {
        HStack(spacing: 18) {
            ForEach(0..<4, id: \.self) { i in
                Circle()
                    .strokeBorder(Color.accentColor, lineWidth: 1.5)
                    .background(Circle().fill(i < count ? Color.accentColor : .clear))
                    .frame(width: 16, height: 16)
            }
        }
    }
}

struct NumberPad: View {
    var onDigit: (Int) -> Void
    var onDelete: () -> Void
    var biometryIcon: String? = nil
    var onBiometry: () -> Void = {}

    private let rows = [[1, 2, 3], [4, 5, 6], [7, 8, 9]]

    var body: some View {
        VStack(spacing: 16) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 24) {
                    ForEach(row, id: \.self) { n in key("\(n)") { onDigit(n) } }
                }
            }
            HStack(spacing: 24) {
                if let biometryIcon {
                    Button(action: onBiometry) {
                        Image(systemName: biometryIcon).font(.title)
                            .frame(width: 76, height: 76)
                    }
                    .accessibilityLabel("Use Face ID")
                } else {
                    Color.clear.frame(width: 76, height: 76)
                }
                key("0") { onDigit(0) }
                Button(action: onDelete) {
                    Image(systemName: "delete.left").font(.title2)
                        .frame(width: 76, height: 76)
                }
                .accessibilityLabel("Delete")
            }
        }
        .foregroundStyle(.primary)
    }

    private func key(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 30, weight: .regular, design: .rounded))
                .frame(width: 76, height: 76)
                .background(Circle().fill(Color(.secondarySystemBackground)))
        }
        .buttonStyle(.plain)
    }
}

/// Side-to-side shake for a wrong passcode.
struct Shake: GeometryEffect {
    var animatableData: CGFloat
    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 10 * sin(animatableData * .pi * 4), y: 0))
    }
}
