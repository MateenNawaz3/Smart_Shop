//
//  RemotePageCard.swift
//  SmartShop
//

import SwiftUI

/// A card whose copy comes from `/mobile/pages/{key}`, with the app's own
/// wording as the fallback.
///
/// **The local copy is the floor, not a placeholder.** It renders immediately
/// and stays if the page never arrives, so the screen is complete offline and
/// on a cold start. Server content replaces it only once it is in hand — there
/// is no spinner, because a card of real text is a better wait than a blank one.
///
/// The body is Markdown (`**bold**` and newlines), so it is parsed rather than
/// printed raw. A body that will not parse falls back to plain text rather than
/// showing the customer asterisks.
struct RemotePageCard<Fallback: View>: View {
    let key: String
    var title: String?
    @ViewBuilder var fallback: Fallback

    @Environment(AppEnvironment.self) private var environment
    @State private var page: Page?

    var body: some View {
        InfoCard(title: page?.title ?? title) {
            if let page {
                Text(Self.formatted(page.body))
                    .font(Theme.body(.body))
                    .lineSpacing(4)
                    .foregroundStyle(Theme.Colors.green.opacity(0.85))
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                fallback
            }
        }
        .task {
            // Silent: a page that does not load leaves the built-in copy in
            // place, which is a complete answer on its own.
            page = try? await environment.contentService.page(key: key)
        }
    }

    private static func formatted(_ markdown: String) -> AttributedString {
        (try? AttributedString(
            markdown: markdown,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(markdown)
    }
}
