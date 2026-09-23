//
//  MitIDView.swift
//  SmartShop
//

import SwiftUI

/// Port of `src/routes/mitid.tsx` — the demo MitID flow in three stages:
/// the identity form, the simulated MitID app, and the "verified" confirmation.
@MainActor
@Observable
final class MitIDModel {
    enum Stage { case form, app, verified }

    var stage: Stage = .form
    var name = ""
    /// The web posts an ISO `yyyy-MM-dd` string, so the picker's `Date` is
    /// formatted to match rather than sending an ISO-8601 timestamp.
    var birthDate = Calendar.current.date(from: DateComponents(year: 1990, month: 1, day: 1))!
    var code = ""
    var errorKey: String?
    var isSubmitting = false
    var didSignIn = false

    private let mitID: any MitIDService
    private let auth: any AuthService
    private let device: DeviceState
    private let session: AuthSessionStore

    init(mitID: any MitIDService, auth: any AuthService, device: DeviceState, session: AuthSessionStore) {
        self.mitID = mitID
        self.auth = auth
        self.device = device
        self.session = session
    }

    var firstName: String {
        name.trimmingCharacters(in: .whitespaces).split(separator: " ").first.map(String.init) ?? ""
    }

    private var isoBirthDate: String {
        birthDate.formatted(.iso8601.year().month().day().dateSeparator(.dash))
    }

    /// This flow finishes by exchanging a token hash for a session, which
    /// only the Supabase stack can do. See `AuthService.supportsTokenHashSignIn`.
    var backendCanEnrol: Bool { auth.supportsTokenHashSignIn }

    /// The form: validate, then hand over to the simulated MitID app.
    func submit() {
        errorKey = nil
        guard name.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2 else {
            errorKey = "mitid.errorFields"
            return
        }
        stage = .app
    }

    /// The MitID app's "Approve": any code is accepted in the demo.
    func approve() async {
        errorKey = nil
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            // Two steps, exactly as on the web: resolve the identity server-side
            // into a one-time token, then exchange that token for a session.
            let login = try await mitID.demoLogin(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                birthDate: isoBirthDate
            )
            session.beginEnrollment()
            try await auth.verifyEmailToken(hash: login.tokenHash)
            device.stopGuest()
            stage = .verified
            try? await Task.sleep(for: .seconds(2.6))
            didSignIn = true
        } catch is MitIDUnavailable {
            session.finishEnrollment()
            errorKey = "mitid.errorEdgeFunction"
            stage = .form
        } catch {
            session.finishEnrollment()
            errorKey = "mitid.errorGeneric"
            stage = .form
        }
    }
}

struct MitIDView: View {
    @Environment(\.strings) private var t
    @State private var model: MitIDModel

    init(mitID: any MitIDService, auth: any AuthService, device: DeviceState, session: AuthSessionStore) {
        _model = State(initialValue: MitIDModel(mitID: mitID, auth: auth, device: device, session: session))
    }

    var body: some View {
        Group {
            switch model.stage {
            case .form:
                if model.backendCanEnrol { form } else { unavailable }
            case .app: mitIDApp
            case .verified: verified
            }
        }
        .animation(.easeOut(duration: 0.25), value: model.stage)
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(isPresented: $model.didSignIn) {
            ContactDetailsView()
        }
    }

    // MARK: Stage 1 — the identity form

    private var form: some View {
        AppScreen(ovals: BrandOvals(variant: .spread, tone: .light)) {
            VStack(spacing: 0) {
                AuthHeader()
                    .padding(.top, Theme.Spacing.md)

                ScrollView {
                    VStack(spacing: Theme.Spacing.lg) {
                        header

                        BrandTextField(
                            label: t("mitid.nameLabel"),
                            placeholder: t("mitid.namePlaceholder"),
                            text: $model.name,
                            contentType: .name,
                            autocapitalization: .words
                        )

                        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                            Text(t("mitid.dobLabel"))
                                .font(Theme.body(.subheadline, weight: .semibold))
                            DatePicker(
                                t("mitid.dobLabel"),
                                selection: $model.birthDate,
                                in: ...Date.now,
                                displayedComponents: .date
                            )
                            .labelsHidden()
                            .datePickerStyle(.compact)
                            .colorScheme(.light)
                            .padding(.horizontal, Theme.Spacing.md)
                            .frame(height: 56, alignment: .leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.white, in: .rect(cornerRadius: Theme.Radius.field))
                        }

                        Button(t("mitid.submit")) { model.submit() }
                            .buttonStyle(.brandPrimary)

                        if let key = model.errorKey {
                            Text(t(key))
                                .font(Theme.body(.subheadline))
                                .multilineTextAlignment(.center)
                        }

                        Text(t("mitid.demoNote"))
                            .font(Theme.body(.footnote))
                            .foregroundStyle(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.vertical, Theme.Spacing.xl)
                }
                .scrollDismissesKeyboard(.interactively)
            }
        }
    }

    /// Stands in for the form when the backend cannot complete the flow.
    private var unavailable: some View {
        AppScreen(ovals: BrandOvals(variant: .spread, tone: .light)) {
            VStack(spacing: 0) {
                AuthHeader()
                    .padding(.top, Theme.Spacing.md)

                VStack(spacing: Theme.Spacing.md) {
                    Image(systemName: "clock.badge.exclamationmark")
                        .font(.system(size: 44))
                        .foregroundStyle(Theme.Colors.lime)
                    Text(t("mitid.unavailableTitle"))
                        .font(Theme.display(.title2, weight: .bold))
                        .multilineTextAlignment(.center)
                    Text(t("mitid.unavailableBody"))
                        .font(Theme.body(.subheadline))
                        .foregroundStyle(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .frame(maxHeight: .infinity)
            }
        }
    }

    private var header: some View {
        VStack(spacing: Theme.Spacing.md) {
            Text(t("mitid.demoBadge"))
                .font(Theme.body(.caption, weight: .bold))
                .textCase(.uppercase)
                .foregroundStyle(Theme.Colors.lime)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .overlay { Capsule().strokeBorder(Theme.Colors.lime, lineWidth: 1) }

            Text(t("mitid.title")).font(Theme.display(.largeTitle))
            Text(t("mitid.subtitle"))
                .font(Theme.body(.subheadline))
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
        }
    }

    // MARK: Stage 2 — the simulated MitID app (white, MitID blue)

    private static let mitIDBlue = Color(hex: 0x0060E6)

    private var mitIDApp: some View {
        AppScreen(tone: .light) {
            ScrollView {
                VStack(spacing: 0) {
                    Text(t("mitid.appRedirect"))
                        .font(Theme.body(.subheadline, weight: .medium))
                        .foregroundStyle(Theme.Colors.ink.opacity(0.55))
                        .multilineTextAlignment(.center)

                    // The MitID wordmark; the real logo is a trademark and is
                    // not bundled.
                    Text(verbatim: "MitID")
                        .font(.system(size: 44, weight: .heavy, design: .rounded))
                        .foregroundStyle(Self.mitIDBlue)
                        .padding(.top, 40)
                        .accessibilityLabel("MitID")

                    Text(t("mitid.appTitle"))
                        .font(Theme.display(.title2))
                        .foregroundStyle(Theme.Colors.ink)
                        .padding(.top, 40)
                    Text(t("mitid.appHint"))
                        .font(Theme.body(.subheadline))
                        .foregroundStyle(Theme.Colors.ink.opacity(0.55))
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)

                    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                        Text(t("mitid.appCodeLabel"))
                            .font(Theme.body(.subheadline, weight: .semibold))
                            .foregroundStyle(Theme.Colors.ink)
                        TextField("", text: Binding(
                            get: { model.code },
                            set: { model.code = String($0.filter(\.isNumber).prefix(10)) }
                        ))
                        .keyboardType(.numberPad)
                        .font(.system(size: 24, weight: .medium))
                        .tracking(10)
                        .multilineTextAlignment(.center)
                        .frame(height: 56)
                        .background(Theme.Colors.cream, in: .rect(cornerRadius: Theme.Radius.field))
                        .overlay { RoundedRectangle(cornerRadius: Theme.Radius.field).strokeBorder(Theme.Colors.ink.opacity(0.12)) }
                        .accessibilityLabel(t("mitid.appCodeLabel"))

                        Button(model.isSubmitting ? t("mitid.appApproving") : t("mitid.appApprove")) {
                            Task { await model.approve() }
                        }
                        .buttonStyle(WidePillButtonStyle(background: Self.mitIDBlue))
                        .disabled(model.isSubmitting)
                        .opacity(model.isSubmitting ? 0.6 : 1)

                        if let key = model.errorKey {
                            Text(t(key)).font(Theme.body(.subheadline)).foregroundStyle(Theme.Colors.red)
                                .frame(maxWidth: .infinity).multilineTextAlignment(.center)
                        }
                        Text(t("mitid.demoNote"))
                            .font(Theme.body(.caption))
                            .foregroundStyle(Theme.Colors.ink.opacity(0.5))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.top, 32)
                }
                .frame(maxWidth: 380)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }

    // MARK: Stage 3 — verified

    private var verified: some View {
        AppScreen(tone: .light) {
            VStack(spacing: 0) {
                Image(systemName: "checkmark")
                    .font(.system(size: 36, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 80, height: 80)
                    .background(Theme.Colors.lime, in: .circle)
                Text(String(format: t("mitid.verifiedTitle"), model.firstName))
                    .font(Theme.display(.title2))
                    .foregroundStyle(Theme.Colors.ink)
                    .multilineTextAlignment(.center)
                    .padding(.top, Theme.Spacing.lg)
                Text(t("mitid.verifiedBody"))
                    .font(Theme.body(.subheadline))
                    .foregroundStyle(Theme.Colors.ink.opacity(0.55))
                    .padding(.top, 8)
            }
            .frame(maxWidth: 380)
            .transition(.opacity.combined(with: .offset(y: 14)))
        }
    }
}
