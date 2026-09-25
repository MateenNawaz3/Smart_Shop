//
//  Post.swift
//  SmartShop
//

import SwiftUI

/// A bulletin-board entry. Port of `Post` in `src/data/posts.ts`.
///
/// Unlike UI copy, a post's text is *content*: it is written per post and will
/// eventually come from the database, so it carries its own translations rather
/// than living in the string catalog.
nonisolated struct Post: Identifiable, Codable, Hashable, Sendable {
    struct Localized: Codable, Hashable, Sendable {
        var da: String
        var en: String
        var de: String

        func callAsFunction(_ language: AppLanguage) -> String {
            switch language {
            case .da: da
            case .en: en
            case .de: de
            }
        }
    }

    struct Media: Codable, Hashable, Sendable {
        var type: String
        /// Source filename in the web project; mapped to an asset below.
        var src: String
        var alt: Localized
        /// A remote image or video, for a post from the Mobile API. Absent
        /// from the bundled JSON, so it decodes as nil there.
        var url: URL? = nil

        /// What to draw: the remote file when there is one, else the bundled.
        @MainActor var artwork: Artwork? {
            if let url { return .remote(url) }
            return image.map(Artwork.bundled)
        }

        @MainActor var image: ImageResource? {
            switch src {
            case "butik-facade.png": .butikFacade
            case "butik-indvendigt.png": .butikIndvendigt
            case "butik-aabning.png": .butikAabning
            case "butik-interior.png": .butikInterior
            default: nil
            }
        }

        /// The remote file, or the bundled one for `type == "video"` posts if
        /// the app ships it.
        var videoURL: URL? {
            if let url { return url }
            let name = (src as NSString).deletingPathExtension
            let ext = (src as NSString).pathExtension
            return Bundle.main.url(forResource: name, withExtension: ext.isEmpty ? "mp4" : ext)
        }
    }

    enum Category: String, Codable, Sendable {
        case openingSoon = "opening-soon"
        case news
        case fromOpening = "from-opening"

        /// The API spells these with underscores (`opening_soon`), and its set
        /// is open. An unknown one is nil: the card simply has no pill.
        init?(apiValue: String?) {
            guard let apiValue else { return nil }
            self.init(rawValue: apiValue.replacingOccurrences(of: "_", with: "-"))
        }

        /// Key into the string catalog for the pill label.
        var labelKey: String {
            switch self {
            case .openingSoon: "home.categoryOpeningSoon"
            case .news: "home.categoryNews"
            case .fromOpening: "home.categoryFromOpening"
            }
        }
    }

    var id: String
    /// ISO date, used for sorting.
    var date: String
    /// Nil for a category this build does not know.
    var categoryKey: Category?
    var title: Localized
    var body: Localized
    var media: Media?

    var publishedOn: Date? {
        try? Date(date, strategy: .iso8601.year().month().day().dateSeparator(.dash))
    }
}

nonisolated extension Post {
    /// Newest first, matching `getPosts` in the web project.
    static let all: [Post] = {
        guard let url = Bundle.main.url(forResource: "posts", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let posts = try? JSONDecoder().decode([Post].self, from: data)
        else {
            assertionFailure("posts.json missing or malformed")
            return []
        }
        return posts.sorted { $0.date > $1.date }
    }()

    static func latest(_ limit: Int) -> [Post] {
        Array(all.prefix(limit))
    }
}
