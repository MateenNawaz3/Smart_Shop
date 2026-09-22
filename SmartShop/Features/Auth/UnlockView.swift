//
//  UnlockView.swift
//  SmartShop
//

import SwiftUI
import LocalAuthentication

/// Port of `src/routes/laas-op.tsx` — the PIN gate in front of a live session.
///
/// Adds Face ID / Touch ID, which the web cannot offer. The PIN stays the
/// fallback: biometry can fail, be unenrolled, or be unavailable on the device.
@MainActor
@Observable
final class UnlockModel {
    var pin = ""
    /// Translation *key*, resolved by the view.
    var errorKey: String?
    var attempts = 0
    var isChecking = false
    /// Set when the *server* says this device is shut out. It is authoritative
    /// when present — the local `attempts` tally is only a fallback for the
    /// backends that keep no count of their own.
    var lockedForSeconds: Int?

    /// Same limit as the web: five wrong tries and the PIN route is closed.
    var isLockedOut: Bool { lockedForSeconds != nil || attempts >= 5 }

    private let pins: any PinService
    private let device: DeviceState
    private let session: AuthSessionStore

    init(pins: any PinService, device: DeviceState, session: AuthSessionStore) {
        self.pins = pins
        self.device = device
        self.session = session
    }

    func pinChanged() async {
        guard pin.count == 4, !isChecking, !isLockedOut else { return }
        isChecking = true
        defer { isChecking = false }

        do {
            switch try await pins.verifyPin(pin) {
            case .correct:
                unlock()
            case .notSet:
                // The account has no PIN any more (cleared on another device);
                // don't strand the user behind a gate nothing can open.
                device.clearPinOnDevice()
                unlock()
            case .wrong(let attemptsLeft):
                // The server counts down; a backend that does not keep a count
                // leaves this nil and the local tally stands in.
                if let attemptsLeft {
                    attempts = max(0, 5 - attemptsLeft)
                } else {
                    attempts += 1
                }
                errorKey = "mitid.unlockWrong"
                pin = ""
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            case .locked(let seconds):
                // The correct PIN will not open it until this elapses, so say
                // so rather than inviting another try.
                lockedForSeconds = seconds
                attempts = 5
                errorKey = "mitid.unlockWrong"
                pin = ""
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
        } catch {
            self.errorKey = "mitid.errorGeneric"
            pin = ""
        }
    }

    func authenticateWithBiometrics(reason: String) async {
        let context = LAContext()
        var authError: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &authError)
        else { return }

        do {
            let ok = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
            if ok { unlock() }
        } catch {
            // Cancelled or failed — the PIN pad is still there.
        }
    }

    var biometryAvailable: Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
    }

    private func unlock() {
        attempts = 0
        lockedForSeconds = nil
        device.markUnlocked()
        session.recompute()
    }

    func signOut() async {
        await session.signOut()
    }
}

struct UnlockView: View {
    @Environment(\.strings) private var t
    @Environment(AppEnvironment.self) private var environment
    @Environment(DeviceState.self) private var device
    @Environment(AuthSessionStore.self) private var session

    @State private var model: UnlockModel?

    var body: some View {
        AppScreen(ovals: BrandOvals(variant: .spread, tone: .light)) {
            if let model {
                content(model)
            }
        }
        .task {
            if model == nil {
                model = UnlockModel(pins: environment.pinService, device: device, session: session)
            }
            // Offer biometrics immediately, the way the system passcode screen does.
            await model?.authenticateWithBiometrics(reason: t("mitid.unlockSubtitle"))
        }
    }

    @ViewBuilder
    private func content(_ model: UnlockModel) -> some View {
        @Bindable var model = model

        VStack(spacing: Theme.Spacing.lg) {
            AppLogo(size: .small)
            Spacer()

            Text(t("mitid.unlockTitle")).font(Theme.display(.largeTitle))
            Text(t("mitid.unlockSubtitle"))
                .font(Theme.body(.subheadline))
                .foregroundStyle(.white.opacity(0.8))

            PinPad(value: $model.pin, isDisabled: model.isChecking || model.isLockedOut)
                .onChange(of: model.pin) { Task { await model.pinChanged() } }

            if model.isLockedOut {
                Text(t("mitid.unlockLocked")).font(Theme.body(.subheadline))
            } else if let key = model.errorKey {
                Text(t(key)).font(Theme.body(.subheadline))
            }

            if model.biometryAvailable && !model.isLockedOut {
                Button(t("mitid.unlockBiometry")) {
                    Task { await model.authenticateWithBiometrics(reason: t("mitid.unlockSubtitle")) }
                }
                .buttonStyle(.brandLink)
            }

            Button(t("mitid.unlockForgot")) {
                Task { await model.signOut() }
            }
            .buttonStyle(.brandLink)

            Spacer()
        }
        .multilineTextAlignment(.center)
        .padding(.vertical, Theme.Spacing.lg)
    }
}
