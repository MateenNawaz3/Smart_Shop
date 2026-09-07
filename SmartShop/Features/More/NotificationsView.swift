//
//  NotificationsView.swift
//  SmartShop
//

import SwiftUI

/// Offer-email opt-in. Port of `routes/_authenticated/mere_.notifikationer.tsx`.
struct NotificationsView: View {
    @Binding var path: [MoreRoute]

    @Environment(\.strings) private var t
    @Environment(AppEnvironment.self) private var environment

    @State private var enabled = false
    @State private var loaded = false
    @State private var saving = false
    @State private var message: String?
    @State private var error: String?

    var body: some View {
        AppPageLayout(title: t("more.notifications.title"), description: t("more.notifications.description")) {
            GuestBackLink(title: t("more.notifications.backToMore")) { path.removeAll() }
        } content: {
            GuestCard {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    HStack(alignment: .top, spacing: Theme.Spacing.md) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(t("more.notifications.offersTitle"))
                                .font(Theme.display(.title3, weight: .bold))
                                .foregroundStyle(Theme.Colors.green)
                            Text(t("more.notifications.offersDescription"))
                                .font(Theme.body(.subheadline))
                                .lineSpacing(3)
                                .foregroundStyle(Theme.Colors.green.opacity(0.7))
                        }
                        Toggle("", isOn: Binding(get: { enabled }, set: { toggle($0) }))
                            .labelsHidden()
                            .tint(Theme.Colors.lime)
                            .disabled(saving || !loaded)
                            .accessibilityLabel(t("more.notifications.ariaReceiveOffers"))
                    }
                    if let message {
                        Text(message).font(Theme.body(.subheadline, weight: .semibold)).foregroundStyle(Theme.Colors.green)
                    }
                    if let error {
                        Text(error).font(Theme.body(.subheadline)).foregroundStyle(Theme.Colors.red)
                    }
                }
            }

            Text(t("more.notifications.importantNote"))
                .font(Theme.body(.subheadline))
                .lineSpacing(3)
                .foregroundStyle(Theme.Colors.green.opacity(0.7))
                .padding(.top, Theme.Spacing.md + 4)
        }
        .task {
            if let details = try? await environment.profileService.details() {
                enabled = details.markedsforing
            }
            loaded = true
        }
    }

    private func toggle(_ next: Bool) {
        enabled = next
        saving = true
        message = nil
        error = nil
        Task {
            do {
                try await environment.profileService.setMarketing(next)
                message = t("more.notifications.savedMessage")
            } catch {
                enabled = !next
                self.error = t("more.notifications.saveError")
            }
            saving = false
        }
    }
}
