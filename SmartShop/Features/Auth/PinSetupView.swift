//
//  PinSetupView.swift
//  SmartShop
//

import SwiftUI

/// Port of `src/routes/mitid_.pinkode.tsx`: choose a PIN, confirm it, then
/// optionally locate the nearest store and save it as "my store".
@MainActor
@Observable
final class PinSetupModel {
    enum Step { case choose, confirm, done }

    var step: Step = .choose
    var pin = ""
    var confirmation = ""
    /// Translation *key*, resolved by the view — so a language switch also
    /// re-renders an error that is already on screen.
    var errorKey: String?
    var isSaving = false
    /// Set once the nearest store has been saved; shown for a moment before continuing.
    var savedStoreName: String?
    var locating = false

    private let pins: any PinService
    private let device: DeviceState
    private let profiles: any ProfileService

    init(pins: any PinService, device: DeviceState, profiles: any ProfileService) {
        self.pins = pins
        self.device = device
        self.profiles = profiles
    }

    /// "Find nearest store": current location → closest store → profile.
    /// Returns true when the flow should continue.
    func useLocation() async -> Bool {
        locating = true
        errorKey = nil
        defer { locating = false }
        do {
            let point = try await LocationFinder().current()
            guard let nearest = Store.byDistance(from: point).first else { return true }
            try await profiles.setFavoriteStore(nearest.store.slug, home: point)
            savedStoreName = nearest.store.name
            try? await Task.sleep(for: .seconds(1.2))
            return true
        } catch {
            errorKey = "mitid.locDenied"
            return false
        }
    }

    /// Called whenever a digit lands. The web drives this from three chained
    /// `useEffect`s; one function reads far more clearly and cannot fire twice.
    func digitsChanged() async {
        switch step {
        case .choose where pin.count == 4:
            errorKey = nil
            step = .confirm

        case .confirm where confirmation.count == 4:
            guard !isSaving else { return }
            guard confirmation == pin else {
                errorKey = "mitid.pinMismatch"
                pin = ""
                confirmation = ""
                step = .choose
                return
            }
            await save()

        default:
            break
        }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        do {
            try await pins.setPin(pin)
            device.markPinOnDevice()
            device.markUnlocked()
            step = .done
        } catch {
            self.errorKey = "mitid.errorGeneric"
            pin = ""
            confirmation = ""
            step = .choose
        }
    }
}

struct PinSetupView: View {
    @Environment(\.strings) private var t
    @Environment(AppEnvironment.self) private var environment
    @Environment(DeviceState.self) private var device
    @Environment(AuthSessionStore.self) private var session

    @State private var model: PinSetupModel?

    var body: some View {
        AppScreen(ovals: BrandOvals(variant: .spread, tone: .light)) {
            if let model {
                content(model)
            }
        }
        .navigationBarBackButtonHidden()
        .toolbarBackground(.hidden, for: .navigationBar)
        .task {
            if model == nil {
                model = PinSetupModel(pins: environment.pinService, device: device, profiles: environment.profileService)
            }
        }
    }

    @ViewBuilder
    private func content(_ model: PinSetupModel) -> some View {
        @Bindable var model = model

        VStack(spacing: Theme.Spacing.lg) {
            AppLogo(size: .small)

            Spacer()

            if model.step == .done {
                locationStep(model)
            } else {
                Text(t("mitid.pinTitle")).font(Theme.display(.title))
                Text(model.step == .choose ? t("mitid.pinSubtitle") : t("mitid.pinRepeatSub"))
                    .font(Theme.body(.subheadline))
                    .foregroundStyle(.white.opacity(0.8))

                PinPad(
                    value: model.step == .choose ? $model.pin : $model.confirmation,
                    isDisabled: model.isSaving
                )
                .onChange(of: model.pin) { Task { await model.digitsChanged() } }
                .onChange(of: model.confirmation) { Task { await model.digitsChanged() } }

                if let key = model.errorKey {
                    Text(t(key)).font(Theme.body(.subheadline)).multilineTextAlignment(.center)
                }
            }

            Spacer()
        }
        .padding(.vertical, Theme.Spacing.lg)
    }

    private func locationStep(_ model: PinSetupModel) -> some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 80, height: 64)
                .background(Theme.Colors.lime, in: .ellipse)

            Text(t("mitid.locTitle")).font(Theme.display(.title))
            Text(model.savedStoreName.map { "\(t("mitid.locSaved")) \($0)" } ?? t("mitid.locSubtitle"))
                .font(Theme.body(.subheadline))
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)

            if model.savedStoreName == nil {
                VStack(spacing: 12) {
                    Button(model.locating ? t("mitid.working") : t("mitid.locAllow")) {
                        Task { if await model.useLocation() { finish() } }
                    }
                    .buttonStyle(.brandPrimary)
                    .disabled(model.locating)

                    Button(t("mitid.locSkip"), action: finish)
                        .buttonStyle(.brandOutline)
                }
                .padding(.top, Theme.Spacing.md)
            }

            if let key = model.errorKey {
                Text(t(key)).font(Theme.body(.subheadline)).multilineTextAlignment(.center)
            }
        }
    }

    /// Ends enrollment: the app re-evaluates its phase and, for a new account,
    /// shows the onboarding guide (the web's `/velkommen`).
    private func finish() {
        session.finishEnrollment()
    }
}
