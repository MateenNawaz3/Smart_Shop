//
//  IdVerificationForm.swift
//  SmartShop
//

import SwiftUI
import PhotosUI

/// Small status chip. Port of `VerificationStatusBadge.tsx`.
struct VerificationStatusBadge: View {
    @Environment(\.strings) private var t
    let status: VerificationStatus
    var method: VerificationMethod?

    var body: some View {
        let (icon, label, bg, fg): (String, String, Color, Color) = switch status {
        case .verified: ("checkmark.seal.fill", t("verify.verify.statusVerified"), Theme.Colors.lime.opacity(0.2), Theme.Colors.green)
        case .pending: ("clock", t("verify.verify.statusPending"), Theme.Colors.green.opacity(0.1), Theme.Colors.green.opacity(0.8))
        case .rejected: ("xmark.shield", t("verify.verify.statusRejected"), Theme.Colors.red.opacity(0.1), Theme.Colors.red)
        case .none: ("exclamationmark.shield", t("verify.verify.statusNone"), Theme.Colors.green.opacity(0.1), Theme.Colors.green.opacity(0.8))
        }
        HStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 14, weight: .semibold))
            Text(label)
            if let method {
                Text("· \(methodLabel(method))").opacity(0.7)
            }
        }
        .font(Theme.body(.caption, weight: .semibold))
        .foregroundStyle(fg)
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(bg, in: .capsule)
    }

    private func methodLabel(_ m: VerificationMethod) -> String {
        switch m {
        case .mitid: t("verify.verify.methodMitid")
        case .passport: t("verify.verify.methodPassport")
        case .license: t("verify.verify.methodLicense")
        case .idCard: t("verify.verify.methodIdCard")
        }
    }
}

/// Passport, driving licence or ID card photos as an alternative to MitID.
/// Port of `IdVerificationForm.tsx`. Licence and ID card need both sides.
struct IdVerificationForm: View {
    var onDone: () -> Void = {}
    /// Sends the photos somewhere other than `verificationService`. The sign-up
    /// wizard uses it for the Mobile API, where a person reviews the document
    /// later, so the demo's "approved automatically" note would be untrue.
    var submitForReview: ((VerificationMethod, Data, Data?) async throws -> Void)?

    @Environment(\.strings) private var t
    @Environment(AppEnvironment.self) private var environment

    @State private var method: VerificationMethod = .passport
    @State private var front: UIImage?
    @State private var back: UIImage?
    @State private var frontItem: PhotosPickerItem?
    @State private var backItem: PhotosPickerItem?
    @State private var error: String?
    @State private var loading = false
    @State private var done = false

    private static let maxBytes = 10 * 1024 * 1024
    private var needsBack: Bool { method != .passport }

    var body: some View {
        if done {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.seal.fill").foregroundStyle(Theme.Colors.green)
                Text(t("verify.verify.done")).font(Theme.display(.body, weight: .bold)).foregroundStyle(Theme.Colors.green)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(Theme.Colors.lime.opacity(0.15), in: .rect(cornerRadius: Theme.Radius.card))
        } else {
            form
        }
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack(alignment: .top, spacing: 12) {
                OvalIcon(systemName: "person.text.rectangle", size: CGSize(width: 56, height: 44))
                VStack(alignment: .leading, spacing: 4) {
                    Text(t("verify.verify.foreignTitle")).font(Theme.display(.title2, weight: .bold)).foregroundStyle(Theme.Colors.green)
                    Text(t("verify.verify.foreignSub")).font(Theme.body(.subheadline)).foregroundStyle(Theme.Colors.green.opacity(0.7))
                }
            }

            Text(t("verify.verify.chooseDocument")).font(Theme.body(.subheadline, weight: .semibold)).foregroundStyle(Theme.Colors.green)
            HStack(spacing: 8) {
                option(.passport, t("verify.verify.passport"))
                option(.license, t("verify.verify.driversLicense"))
                option(.idCard, t("verify.verify.idCard"))
            }

            Text(t("verify.verify.uploadTitle")).font(Theme.body(.subheadline, weight: .semibold)).foregroundStyle(Theme.Colors.green).padding(.top, 4)
            Text(t("verify.verify.uploadHint")).font(Theme.body(.caption)).foregroundStyle(Theme.Colors.green.opacity(0.6))

            side(label: t("verify.verify.frontLabel"),
                 hint: method == .passport ? t("verify.verify.passportHint") : t("verify.verify.frontHint"),
                 image: front, item: $frontItem)
            if needsBack {
                side(label: t("verify.verify.backLabel"), hint: t("verify.verify.backHint"), image: back, item: $backItem)
            }

            Button(loading ? t("verify.verify.submitting") : t("verify.verify.submit")) { Task { await submit() } }
                .buttonStyle(WidePillButtonStyle(background: Theme.Colors.lime))
                .disabled(loading)
                .padding(.top, 4)

            if let error {
                Text(error).font(Theme.body(.subheadline)).foregroundStyle(Theme.Colors.red)
            }

            if submitForReview == nil {
                DemoNote(badge: t("verify.verify.demoBadge"), text: t("verify.verify.demoNote"))
            }
        }
        .padding(20)
        .background(Theme.Colors.lime.opacity(0.1), in: .rect(cornerRadius: Theme.Radius.card))
        .onChange(of: frontItem) { _, item in Task { front = await load(item, side: "front") } }
        .onChange(of: backItem) { _, item in Task { back = await load(item, side: "back") } }
    }

    private func option(_ m: VerificationMethod, _ label: String) -> some View {
        let active = method == m
        return Button {
            method = m
            error = nil
            if m == .passport { back = nil; backItem = nil }
        } label: {
            Text(label)
                .font(Theme.display(.subheadline, weight: .bold))
                .foregroundStyle(active ? .white : Theme.Colors.green)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(active ? Theme.Colors.green : .white, in: .rect(cornerRadius: Theme.Radius.field))
                .overlay { RoundedRectangle(cornerRadius: Theme.Radius.field).strokeBorder(active ? Theme.Colors.green : Theme.Colors.green.opacity(0.2)) }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(active ? .isSelected : [])
    }

    private func side(label: String, hint: String, image: UIImage?, item: Binding<PhotosPickerItem?>) -> some View {
        // Read out of the main actor up here: PhotosPicker's label builder is a
        // Sendable closure, so `t` and `Theme` cannot be touched inside it.
        let pickerTitle = image == nil ? t("verify.verify.chooseFile") : t("verify.verify.changeFile")
        let pickerFont = Theme.display(.body, weight: .bold)
        let green = Theme.Colors.green

        return VStack(alignment: .leading, spacing: 8) {
            Text(label).font(Theme.body(.subheadline, weight: .semibold)).foregroundStyle(Theme.Colors.green)
            Text(hint).font(Theme.body(.caption)).foregroundStyle(Theme.Colors.green.opacity(0.6))
            if let image {
                Image(uiImage: image)
                    .resizable().scaledToFill()
                    .frame(height: 160).frame(maxWidth: .infinity).clipped()
                    .clipShape(.rect(cornerRadius: Theme.Radius.field))
                    .overlay { RoundedRectangle(cornerRadius: Theme.Radius.field).strokeBorder(Theme.Colors.green.opacity(0.15)) }
                    .accessibilityLabel(t("verify.verify.previewAlt"))
            }
            PhotosPicker(selection: item, matching: .images) {
                Label(pickerTitle, systemImage: "square.and.arrow.up")
                    .font(pickerFont)
                    .foregroundStyle(green)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background { Capsule().strokeBorder(green.opacity(0.6), lineWidth: 2) }
            }
        }
        .padding(.top, 4)
    }

    private func load(_ item: PhotosPickerItem?, side: String) async -> UIImage? {
        error = nil
        guard let item else { return nil }
        guard let data = try? await item.loadTransferable(type: Data.self) else { error = t("verify.verify.errors.wrongType"); return nil }
        guard data.count <= Self.maxBytes else { error = t("verify.verify.errors.tooLarge"); return nil }
        guard let image = UIImage(data: data) else { error = t("verify.verify.errors.wrongType"); return nil }
        return image
    }

    private func submit() async {
        error = nil
        guard let front else { error = t("verify.verify.errors.noFile"); return }
        if needsBack && back == nil { error = t("verify.verify.errors.noBack"); return }
        loading = true
        defer { loading = false }
        do {
            let frontData = front.jpegData(compressionQuality: 0.85) ?? Data()
            let backData = back?.jpegData(compressionQuality: 0.85)
            if let submitForReview {
                try await submitForReview(method, frontData, needsBack ? backData : nil)
            } else {
                _ = try await environment.verificationService.submit(method: method, front: frontData, back: needsBack ? backData : nil)
            }
            done = true
            onDone()
        } catch {
            self.error = t("verify.verify.errors.generic")
        }
    }
}
