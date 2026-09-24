//
//  LanguageStore.swift
//  SmartShop
//

import Foundation
import SwiftUI

/// The three languages the app ships. Port of `src/lib/language.ts`.
enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case da, en, de

    var id: String { rawValue }

    /// Endonym — always shown in the language's own words, never translated.
    var native: String {
        switch self {
        case .da: "Dansk"
        case .en: "English"
        case .de: "Deutsch"
        }
    }

    /// Locale used for dates and numbers.
    ///
    /// Mirrors `LOCALE` in `ReceiptPaper.tsx` and `DATE_LOCALES` in
    /// `data/events.ts`: English means *British* English, so dates read
    /// "2 September 2026" and not the American "September 2, 2026".
    /// `Locale(identifier: "en")` alone resolves to en-US and gets this wrong.
    var locale: Locale {
        switch self {
        case .da: Locale(identifier: "da_DK")
        case .en: Locale(identifier: "en_GB")
        case .de: Locale(identifier: "de_DE")
        }
    }

    var flag: FlagCode {
        switch self {
        case .da: .dk
        case .en: .gb
        case .de: .de
        }
    }
}

/// The app's chosen language.
///
/// This is deliberately **not** the device locale. Smart Shop's guest mode is
/// tourist mode: a visitor with a German phone may well want Danish, and a Dane
/// abroad still wants Danish. So the choice is explicit and persisted, exactly
/// as `src/lib/language.ts` does it.
///
/// The web defaults to English (`DEFAULT_LANGUAGE`). On iOS we can do better on
/// first launch — if the device is already Danish or German, start there — and
/// fall back to English otherwise.
@MainActor
@Observable
final class LanguageStore {
    private static let key = "smartshop-lang"

    private(set) var language: AppLanguage {
        didSet {
            bundle = Self.bundle(for: language)
            // Every API request advertises the language the UI is showing, and
            // the client reads it from here rather than hopping to the main
            // actor on every call.
            APILocalization.shared.current = language.rawValue
        }
    }

    /// The `.lproj` bundle the chosen language's strings are read from.
    private(set) var bundle: Bundle

    /// Server-owned strings for the chosen language, which **override** the
    /// compiled bundle key for key.
    ///
    /// This is what lets copy be corrected without shipping a build: the bundle
    /// is the floor, not the source of truth. It is deliberately additive —
    /// a key the server does not send falls through to the bundle, and a failed
    /// load leaves the app exactly as it was rather than blank.
    private(set) var overrides: [String: String] = [:]

    /// Set once at launch. Nil in previews and in UI tests, where the bundle is
    /// the whole story and no network should happen.
    var translations: (any TranslationService)?

    init() {
        let stored = UserDefaults.standard.string(forKey: Self.key)
            .flatMap(AppLanguage.init(rawValue:))
        let language = UITesting.forcedLanguage ?? stored ?? Self.devicePreferred
        self.language = language
        self.bundle = Self.bundle(for: language)
        // `didSet` does not fire during init, so seed it explicitly.
        APILocalization.shared.current = language.rawValue
    }

    func select(_ language: AppLanguage) {
        guard language != self.language else { return }
        UserDefaults.standard.set(language.rawValue, forKey: Self.key)
        // Drop the old language's overrides immediately. Keeping them until the
        // new ones arrive would show Danish strings on a German screen for as
        // long as the request takes.
        overrides = [:]
        self.language = language
        Task { await refreshOverrides() }
    }

    /// Pulls the server's strings for the current language.
    ///
    /// Silent by design. Every failure mode — offline, 404 for a language the
    /// server has no bundle for, a malformed body — leaves `overrides` as it is
    /// and the app keeps working on its compiled strings. There is nothing
    /// useful to tell the customer about a copy update that did not arrive.
    func refreshOverrides() async {
        guard let translations else { return }
        let requested = language
        guard let bundle = try? await translations.bundle(for: requested) else { return }

        // `/translations/de` once answered with Danish and a 200. Taking the
        // server at its word would have put Danish door messages in front of a
        // German speaker with nothing to show it had happened.
        guard !bundle.isFallback(from: requested) else { return }
        guard requested == language else { return }   // language changed mid-flight
        overrides = bundle.strings
    }

    /// Look up a key in the chosen language.
    func string(_ key: String) -> String {
        bundle.localizedString(forKey: key, value: key, table: nil)
    }

    private static var devicePreferred: AppLanguage {
        for code in Locale.preferredLanguages {
            if let match = AppLanguage(rawValue: String(code.prefix(2))) { return match }
        }
        return .en
    }

    /// String Catalogs compile to one `.lproj` per language inside the bundle,
    /// so switching language at runtime is a matter of reading from a different
    /// one. Falling back to `.main` keeps text rendering even if a lookup fails.
    private static func bundle(for language: AppLanguage) -> Bundle {
        guard let path = Bundle.main.path(forResource: language.rawValue, ofType: "lproj"),
              let bundle = Bundle(path: path)
        else { return .main }
        return bundle
    }
}

// MARK: - Reading strings from views

extension EnvironmentValues {
    /// Every view can translate without threading a store through initialisers.
    @Entry var strings: Translator = Translator(bundle: .main)
}

/// A tiny value that resolves keys against one language's bundle.
///
/// Being a value (not the store) means SwiftUI re-renders a view when the
/// language changes, because the environment value itself changed.
struct Translator: Equatable {
    let bundle: Bundle
    /// Server-owned strings, consulted before the bundle. See
    /// `LanguageStore.overrides`.
    var overrides: [String: String] = [:]

    /// `t("tourist.title")`
    ///
    /// Server first, bundle second. The bundle is the floor: a key the server
    /// has never heard of still resolves, so an override set can be partial —
    /// which it always is, since the server owns only the strings whose
    /// *decisions* it owns.
    func callAsFunction(_ key: String) -> String {
        overrides[key] ?? bundle.localizedString(forKey: key, value: key, table: nil)
    }

    /// Reads an array of records stored as `prefix.<index>.<field>` — how the
    /// generator flattened `t.tourist.steps` and `t.tourist.gtkItems`.
    func list(_ prefix: String, fields: [String], max: Int = 20) -> [[String: String]] {
        var items: [[String: String]] = []
        for index in 0..<max {
            var record: [String: String] = [:]
            for field in fields {
                let key = "\(prefix).\(index).\(field)"
                // Sentinel, not "": `localizedString` returns the *key* when a
                // lookup misses and `value` is nil or empty, so an empty-string
                // check can never detect the end of the array.
                let value = bundle.localizedString(forKey: key, value: "\u{0}", table: nil)
                if value == "\u{0}" { return items }   // ran past the end
                record[field] = value
            }
            items.append(record)
        }
        return items
    }
}
