//
//  BrandPhoneField.swift
//  SmartShop
//

import SwiftUI

/// `BrandTextField` for a phone number, with a country-code picker inside the
/// field. Port of WorcX's `CustomTextField` country picker.
///
/// `text` is always the full number, "+4512345678", which is what every
/// endpoint takes. The field shows the country's flag and code on the left and
/// only the digits after the code in the text itself.
struct BrandPhoneField: View {
    @Environment(\.strings) private var t
    @Environment(LanguageStore.self) private var languages

    let label: String
    var placeholder: String = ""
    @Binding var text: String
    var error: String?
    var tone: BrandTextField.Tone = .onGreen
    var isDisabled = false

    @State private var country: Country = .denmark
    @State private var national = ""
    @State private var showsPicker = false

    var body: some View {
        BrandTextField(
            label: label,
            placeholder: placeholder,
            text: Binding(get: { national }, set: nationalChanged),
            error: error,
            contentType: .telephoneNumber,
            keyboard: .phonePad,
            autocapitalization: .never,
            tone: tone,
            isDisabled: isDisabled,
            leadingAccessory: AnyView(countryButton)
        )
        .onAppear { adopt(text) }
        .onChange(of: text) { _, new in
            // Only a change from outside: our own writes already match.
            if new != full { adopt(new) }
        }
        .sheet(isPresented: $showsPicker) {
            CountryPickerSheet(selected: country) { picked in
                country = picked
                national = String(national.prefix(picked.maxLength))
                text = full
            }
        }
    }

    /// The number as the endpoints take it. Empty while no digits are typed,
    /// so a required-field check still sees a blank field.
    private var full: String {
        national.isEmpty ? "" : country.dialCode + national
    }

    private func adopt(_ number: String) {
        (country, national) = Country.split(number, current: country)
    }

    private func nationalChanged(_ input: String) {
        // Autofill and paste bring the whole number, code included.
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("+") || trimmed.hasPrefix("00") {
            adopt(trimmed)
        } else {
            national = String(input.filter(\.isNumber).prefix(country.maxLength))
        }
        text = full
    }

    private var countryButton: some View {
        Button { showsPicker = true } label: {
            HStack(spacing: 6) {
                Text(country.flag).font(.system(size: 20))
                Text(country.dialCode)
                    .font(Theme.body(.body))
                    .foregroundStyle(Theme.Colors.ink)
                if !isDisabled {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.Colors.ink.opacity(0.45))
                }
                Rectangle()
                    .fill(Theme.Colors.green.opacity(0.2))
                    .frame(width: 1, height: 24)
                    .padding(.leading, 4)
            }
            .padding(.leading, Theme.Spacing.md)
            .frame(height: 56)
            .contentShape(.rect)
        }
        .disabled(isDisabled)
        .accessibilityLabel("\(t("phone.country.title")): \(country.localizedName(in: languages.language.locale)) \(country.dialCode)")
    }
}

/// Searchable country list. Port of WorcX's `CountryPickerVC`.
///
/// Like the original, the search box is a plain field pinned above the list
/// rather than `.searchable`: the system search's dimming layer swallows the
/// first tap on a result, so picking a country took two taps.
struct CountryPickerSheet: View {
    let selected: Country
    let onSelect: (Country) -> Void

    @Environment(\.strings) private var t
    @Environment(LanguageStore.self) private var languages
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchField
                List(filtered, id: \.isoCode) { country in
                    Button {
                        onSelect(country)
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            Text(country.flag).font(.system(size: 24))
                            Text(name(of: country))
                                .font(Theme.body(.body))
                                .foregroundStyle(Theme.Colors.ink)
                            Spacer()
                            Text(country.dialCode)
                                .font(Theme.body(.body))
                                .foregroundStyle(Theme.Colors.ink.opacity(0.55))
                            if country == selected {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(Theme.Colors.green)
                            }
                        }
                        .contentShape(.rect)
                    }
                    .accessibilityAddTraits(country == selected ? .isSelected : [])
                }
                .listStyle(.plain)
                .scrollDismissesKeyboard(.immediately)
            }
            .navigationTitle(t("phone.country.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(t("common.cancel")) { dismiss() }
                }
            }
        }
        .tint(Theme.Colors.green)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(Theme.Colors.ink.opacity(0.45))
            TextField(t("phone.country.search"), text: $query)
                .font(Theme.body(.body))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, 12)
        .frame(height: 44)
        .background(Theme.Colors.cream, in: .rect(cornerRadius: 12))
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
    }

    private func name(of country: Country) -> String {
        country.localizedName(in: languages.language.locale)
    }

    /// Sorted by the name shown, so the list is alphabetical in every language.
    /// Search matches that name, the English one, the code or the ISO letters.
    private var filtered: [Country] {
        let named = Country.all.sorted {
            name(of: $0).localizedStandardCompare(name(of: $1)) == .orderedAscending
        }
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return named }
        return named.filter {
            name(of: $0).localizedStandardContains(q)
                || $0.name.localizedStandardContains(q)
                || $0.dialCode.contains(q)
                || $0.isoCode.localizedCaseInsensitiveContains(q)
        }
    }
}
