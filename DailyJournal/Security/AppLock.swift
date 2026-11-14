import SwiftUI
import LocalAuthentication

/// Locks the app when it leaves the screen and shows the lock screen
/// in its own top window, so it also covers open sheets and alerts.
@MainActor
final class AppLock: ObservableObject {
    static let shared = AppLock()

    @AppStorage("useFaceID") var useFaceID = true
    @Published private(set) var isLocked = false

    private var lockWindow: UIWindow?
    private var privacyWindow: UIWindow?

    var isEnabled: Bool { PasscodeStore.isSet }

    /// Face ID or Touch ID, if this device has one set up.
    var biometryType: LABiometryType {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        return context.biometryType
    }

    func handle(_ phase: ScenePhase) {
        guard isEnabled else { hidePrivacyCover(); return }
        switch phase {
        case .background:
            lock()
        case .inactive:
            // Screenshots, Control Center and notifications also make the app inactive,
            // so do nothing here. The lock screen covers the app when it goes to the background.
            break
        case .active:
            hidePrivacyCover()
            if isLocked { showLockWindow() }
        @unknown default:
            break
        }
    }

    /// Called at launch.
    func lockIfEnabled() {
        if isEnabled { lock() }
    }

    func lock() {
        guard isEnabled else { return }
        if !isLocked { AppLog.info("App locked") }
        isLocked = true
        showLockWindow()
    }

    func unlock(method: String) {
        AppLog.info("App unlocked with \(method)")
        isLocked = false
        lockWindow?.isHidden = true
        lockWindow = nil
        hidePrivacyCover()
    }

    // MARK: Windows

    private var scene: UIWindowScene? {
        UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
    }

    private func showLockWindow() {
        guard lockWindow == nil, let scene else { return }
        let window = UIWindow(windowScene: scene)
        window.windowLevel = .alert + 2
        window.rootViewController = UIHostingController(rootView: LockScreen().appAppearance())
        window.makeKeyAndVisible()
        lockWindow = window
    }

    private func showPrivacyCover() {
        guard privacyWindow == nil, let scene else { return }
        let window = UIWindow(windowScene: scene)
        window.windowLevel = .alert + 1
        window.rootViewController = UIHostingController(rootView: PrivacyCover())
        window.isHidden = false
        privacyWindow = window
    }

    private func hidePrivacyCover() {
        privacyWindow?.isHidden = true
        privacyWindow = nil
    }
}

/// Plain cover shown in the app switcher.
private struct PrivacyCover: View {
    var body: some View {
        ZStack {
            Color.accentColor.ignoresSafeArea()
            Image(systemName: "lock.fill")
                .font(.system(size: 44))
                .foregroundStyle(.white)
        }
    }
}
