//
//  Country.swift
//  SmartShop
//
//  Ported from the WorcX app, where the list and lengths were first compiled.
//

import Foundation

/// A selectable phone country code.
///
/// `minLength` / `maxLength` are the national-number digit counts (the part the
/// user types, *excluding* the dial code). For countries that share a calling
/// code (e.g. the NANP `+1` block) the shared prefix is folded into `dialCode`
/// (e.g. "+1242" for the Bahamas) so a full number still builds correctly.
///
/// Lengths are best-effort, not a numbering-plan check.
nonisolated struct Country: Hashable, Sendable {
    /// English, the fallback when the system has no name for the region.
    let name: String
    let isoCode: String      // ISO 3166-1 alpha-2, e.g. "DK"
    let dialCode: String     // e.g. "+45"
    let minLength: Int
    let maxLength: Int

    /// Flag emoji derived from the ISO code (no image assets needed).
    var flag: String {
        isoCode.uppercased().unicodeScalars.reduce(into: "") { result, scalar in
            if let s = UnicodeScalar(127397 + scalar.value) {
                result.unicodeScalars.append(s)
            }
        }
    }

    /// The region's name in `locale` — the app's language, not the device's.
    func localizedName(in locale: Locale) -> String {
        locale.localizedString(forRegionCode: isoCode) ?? name
    }

    // Identity by ISO code so multiple "+1" entries stay distinct.
    static func == (lhs: Country, rhs: Country) -> Bool { lhs.isoCode == rhs.isoCode }
    func hash(into hasher: inout Hasher) { hasher.combine(isoCode) }
}

// MARK: - Full numbers

extension Country {
    /// Main country for a dial code several share, e.g. the UK over Jersey for
    /// "+44", so a stored "+44…" reopens as the likelier one.
    private static let preferredForSharedCode: Set<String> = ["US", "GB", "NO", "FI", "RU", "IT", "AU", "RE", "GP", "MA", "CW"]

    /// Splits a stored number into its country and the digits after the code.
    ///
    /// Takes "+4512345678", "0045 12 34 56 78" or a bare "12345678". A number
    /// with no code is Danish: that is what the app stored before it had a
    /// picker, and what the server assumes. `current` wins a shared code, so a
    /// number typed under Canada stays Canada rather than flipping to the US.
    static func split(_ number: String, current: Country? = nil) -> (country: Country, national: String) {
        var digits = number.filter(\.isNumber)
        let trimmed = number.trimmingCharacters(in: .whitespaces)
        let international = trimmed.hasPrefix("+") || trimmed.hasPrefix("00")
        guard international else { return (current ?? .denmark, digits) }
        if trimmed.hasPrefix("00") { digits.removeFirst(2) }

        // Longest code first: "+1242" (Bahamas) before "+1".
        let matches = all
            .filter { digits.hasPrefix($0.dialCode.dropFirst()) }
            .sorted { $0.dialCode.count > $1.dialCode.count }
        guard let longest = matches.first else { return (current ?? .denmark, digits) }
        let candidates = matches.filter { $0.dialCode == longest.dialCode }
        let country = candidates.first { $0 == current }
            ?? candidates.first { preferredForSharedCode.contains($0.isoCode) }
            ?? longest
        return (country, String(digits.dropFirst(country.dialCode.count - 1)))
    }

    /// Whether `number` has the right number of digits for its country.
    static func isValid(_ number: String) -> Bool {
        let (country, national) = split(number)
        return (country.minLength...country.maxLength).contains(national.count)
    }
}

extension Country {

    /// Default shown in the field.
    static let denmark = Country(name: "Denmark", isoCode: "DK", dialCode: "+45", minLength: 8, maxLength: 8)

    /// Full list, alphabetical by English name.
    static let all: [Country] = [
        Country(name: "Afghanistan",                    isoCode: "AF", dialCode: "+93",   minLength: 9,  maxLength: 9),
        Country(name: "Åland Islands",                  isoCode: "AX", dialCode: "+358",  minLength: 6,  maxLength: 12),
        Country(name: "Albania",                        isoCode: "AL", dialCode: "+355",  minLength: 8,  maxLength: 9),
        Country(name: "Algeria",                        isoCode: "DZ", dialCode: "+213",  minLength: 8,  maxLength: 9),
        Country(name: "American Samoa",                 isoCode: "AS", dialCode: "+1684", minLength: 7,  maxLength: 7),
        Country(name: "Andorra",                        isoCode: "AD", dialCode: "+376",  minLength: 6,  maxLength: 6),
        Country(name: "Angola",                         isoCode: "AO", dialCode: "+244",  minLength: 9,  maxLength: 9),
        Country(name: "Anguilla",                       isoCode: "AI", dialCode: "+1264", minLength: 7,  maxLength: 7),
        Country(name: "Antigua and Barbuda",            isoCode: "AG", dialCode: "+1268", minLength: 7,  maxLength: 7),
        Country(name: "Argentina",                      isoCode: "AR", dialCode: "+54",   minLength: 10, maxLength: 11),
        Country(name: "Armenia",                        isoCode: "AM", dialCode: "+374",  minLength: 8,  maxLength: 8),
        Country(name: "Aruba",                          isoCode: "AW", dialCode: "+297",  minLength: 7,  maxLength: 7),
        Country(name: "Australia",                      isoCode: "AU", dialCode: "+61",   minLength: 9,  maxLength: 9),
        Country(name: "Austria",                        isoCode: "AT", dialCode: "+43",   minLength: 4,  maxLength: 13),
        Country(name: "Azerbaijan",                     isoCode: "AZ", dialCode: "+994",  minLength: 9,  maxLength: 9),
        Country(name: "Bahamas",                        isoCode: "BS", dialCode: "+1242", minLength: 7,  maxLength: 7),
        Country(name: "Bahrain",                        isoCode: "BH", dialCode: "+973",  minLength: 8,  maxLength: 8),
        Country(name: "Bangladesh",                     isoCode: "BD", dialCode: "+880",  minLength: 6,  maxLength: 10),
        Country(name: "Barbados",                       isoCode: "BB", dialCode: "+1246", minLength: 7,  maxLength: 7),
        Country(name: "Belarus",                        isoCode: "BY", dialCode: "+375",  minLength: 9,  maxLength: 9),
        Country(name: "Belgium",                        isoCode: "BE", dialCode: "+32",   minLength: 8,  maxLength: 9),
        Country(name: "Belize",                         isoCode: "BZ", dialCode: "+501",  minLength: 7,  maxLength: 7),
        Country(name: "Benin",                          isoCode: "BJ", dialCode: "+229",  minLength: 8,  maxLength: 8),
        Country(name: "Bermuda",                        isoCode: "BM", dialCode: "+1441", minLength: 7,  maxLength: 7),
        Country(name: "Bhutan",                         isoCode: "BT", dialCode: "+975",  minLength: 7,  maxLength: 8),
        Country(name: "Bolivia",                        isoCode: "BO", dialCode: "+591",  minLength: 8,  maxLength: 8),
        Country(name: "Bosnia and Herzegovina",         isoCode: "BA", dialCode: "+387",  minLength: 8,  maxLength: 8),
        Country(name: "Botswana",                       isoCode: "BW", dialCode: "+267",  minLength: 7,  maxLength: 8),
        Country(name: "Brazil",                         isoCode: "BR", dialCode: "+55",   minLength: 10, maxLength: 11),
        Country(name: "British Virgin Islands",         isoCode: "VG", dialCode: "+1284", minLength: 7,  maxLength: 7),
        Country(name: "Brunei",                         isoCode: "BN", dialCode: "+673",  minLength: 7,  maxLength: 7),
        Country(name: "Bulgaria",                       isoCode: "BG", dialCode: "+359",  minLength: 8,  maxLength: 9),
        Country(name: "Burkina Faso",                   isoCode: "BF", dialCode: "+226",  minLength: 8,  maxLength: 8),
        Country(name: "Burundi",                        isoCode: "BI", dialCode: "+257",  minLength: 8,  maxLength: 8),
        Country(name: "Cambodia",                       isoCode: "KH", dialCode: "+855",  minLength: 8,  maxLength: 9),
        Country(name: "Cameroon",                       isoCode: "CM", dialCode: "+237",  minLength: 9,  maxLength: 9),
        Country(name: "Canada",                         isoCode: "CA", dialCode: "+1",    minLength: 10, maxLength: 10),
        Country(name: "Cape Verde",                     isoCode: "CV", dialCode: "+238",  minLength: 7,  maxLength: 7),
        Country(name: "Cayman Islands",                 isoCode: "KY", dialCode: "+1345", minLength: 7,  maxLength: 7),
        Country(name: "Central African Republic",       isoCode: "CF", dialCode: "+236",  minLength: 8,  maxLength: 8),
        Country(name: "Chad",                           isoCode: "TD", dialCode: "+235",  minLength: 8,  maxLength: 8),
        Country(name: "Chile",                          isoCode: "CL", dialCode: "+56",   minLength: 9,  maxLength: 9),
        Country(name: "China",                          isoCode: "CN", dialCode: "+86",   minLength: 11, maxLength: 11),
        Country(name: "Colombia",                       isoCode: "CO", dialCode: "+57",   minLength: 10, maxLength: 10),
        Country(name: "Comoros",                        isoCode: "KM", dialCode: "+269",  minLength: 7,  maxLength: 7),
        Country(name: "Congo (Brazzaville)",            isoCode: "CG", dialCode: "+242",  minLength: 9,  maxLength: 9),
        Country(name: "Congo (Kinshasa)",               isoCode: "CD", dialCode: "+243",  minLength: 9,  maxLength: 9),
        Country(name: "Cook Islands",                   isoCode: "CK", dialCode: "+682",  minLength: 5,  maxLength: 5),
        Country(name: "Costa Rica",                     isoCode: "CR", dialCode: "+506",  minLength: 8,  maxLength: 8),
        Country(name: "Côte d'Ivoire",                  isoCode: "CI", dialCode: "+225",  minLength: 8,  maxLength: 10),
        Country(name: "Croatia",                        isoCode: "HR", dialCode: "+385",  minLength: 8,  maxLength: 9),
        Country(name: "Cuba",                           isoCode: "CU", dialCode: "+53",   minLength: 8,  maxLength: 8),
        Country(name: "Curaçao",                        isoCode: "CW", dialCode: "+599",  minLength: 7,  maxLength: 8),
        Country(name: "Cyprus",                         isoCode: "CY", dialCode: "+357",  minLength: 8,  maxLength: 8),
        Country(name: "Czech Republic",                 isoCode: "CZ", dialCode: "+420",  minLength: 9,  maxLength: 9),
        Country(name: "Denmark",                        isoCode: "DK", dialCode: "+45",   minLength: 8,  maxLength: 8),
        Country(name: "Djibouti",                       isoCode: "DJ", dialCode: "+253",  minLength: 8,  maxLength: 8),
        Country(name: "Dominica",                       isoCode: "DM", dialCode: "+1767", minLength: 7,  maxLength: 7),
        Country(name: "Dominican Republic",             isoCode: "DO", dialCode: "+1",    minLength: 10, maxLength: 10),
        Country(name: "Ecuador",                        isoCode: "EC", dialCode: "+593",  minLength: 8,  maxLength: 9),
        Country(name: "Egypt",                          isoCode: "EG", dialCode: "+20",   minLength: 10, maxLength: 10),
        Country(name: "El Salvador",                    isoCode: "SV", dialCode: "+503",  minLength: 8,  maxLength: 8),
        Country(name: "Equatorial Guinea",              isoCode: "GQ", dialCode: "+240",  minLength: 9,  maxLength: 9),
        Country(name: "Eritrea",                        isoCode: "ER", dialCode: "+291",  minLength: 7,  maxLength: 7),
        Country(name: "Estonia",                        isoCode: "EE", dialCode: "+372",  minLength: 7,  maxLength: 8),
        Country(name: "Eswatini",                       isoCode: "SZ", dialCode: "+268",  minLength: 8,  maxLength: 8),
        Country(name: "Ethiopia",                       isoCode: "ET", dialCode: "+251",  minLength: 9,  maxLength: 9),
        Country(name: "Faroe Islands",                  isoCode: "FO", dialCode: "+298",  minLength: 6,  maxLength: 6),
        Country(name: "Fiji",                           isoCode: "FJ", dialCode: "+679",  minLength: 7,  maxLength: 7),
        Country(name: "Finland",                        isoCode: "FI", dialCode: "+358",  minLength: 6,  maxLength: 12),
        Country(name: "France",                         isoCode: "FR", dialCode: "+33",   minLength: 9,  maxLength: 9),
        Country(name: "French Guiana",                  isoCode: "GF", dialCode: "+594",  minLength: 9,  maxLength: 9),
        Country(name: "French Polynesia",               isoCode: "PF", dialCode: "+689",  minLength: 6,  maxLength: 8),
        Country(name: "Gabon",                          isoCode: "GA", dialCode: "+241",  minLength: 7,  maxLength: 8),
        Country(name: "Gambia",                         isoCode: "GM", dialCode: "+220",  minLength: 7,  maxLength: 7),
        Country(name: "Georgia",                        isoCode: "GE", dialCode: "+995",  minLength: 9,  maxLength: 9),
        Country(name: "Germany",                        isoCode: "DE", dialCode: "+49",   minLength: 6,  maxLength: 13),
        Country(name: "Ghana",                          isoCode: "GH", dialCode: "+233",  minLength: 9,  maxLength: 9),
        Country(name: "Gibraltar",                      isoCode: "GI", dialCode: "+350",  minLength: 8,  maxLength: 8),
        Country(name: "Greece",                         isoCode: "GR", dialCode: "+30",   minLength: 10, maxLength: 10),
        Country(name: "Greenland",                      isoCode: "GL", dialCode: "+299",  minLength: 6,  maxLength: 6),
        Country(name: "Grenada",                        isoCode: "GD", dialCode: "+1473", minLength: 7,  maxLength: 7),
        Country(name: "Guadeloupe",                     isoCode: "GP", dialCode: "+590",  minLength: 9,  maxLength: 9),
        Country(name: "Guam",                           isoCode: "GU", dialCode: "+1671", minLength: 7,  maxLength: 7),
        Country(name: "Guatemala",                      isoCode: "GT", dialCode: "+502",  minLength: 8,  maxLength: 8),
        Country(name: "Guernsey",                       isoCode: "GG", dialCode: "+44",   minLength: 10, maxLength: 10),
        Country(name: "Guinea",                         isoCode: "GN", dialCode: "+224",  minLength: 8,  maxLength: 9),
        Country(name: "Guinea-Bissau",                  isoCode: "GW", dialCode: "+245",  minLength: 7,  maxLength: 7),
        Country(name: "Guyana",                         isoCode: "GY", dialCode: "+592",  minLength: 7,  maxLength: 7),
        Country(name: "Haiti",                          isoCode: "HT", dialCode: "+509",  minLength: 8,  maxLength: 8),
        Country(name: "Honduras",                       isoCode: "HN", dialCode: "+504",  minLength: 8,  maxLength: 8),
        Country(name: "Hong Kong",                      isoCode: "HK", dialCode: "+852",  minLength: 8,  maxLength: 8),
        Country(name: "Hungary",                        isoCode: "HU", dialCode: "+36",   minLength: 8,  maxLength: 9),
        Country(name: "Iceland",                        isoCode: "IS", dialCode: "+354",  minLength: 7,  maxLength: 9),
        Country(name: "India",                          isoCode: "IN", dialCode: "+91",   minLength: 10, maxLength: 10),
        Country(name: "Indonesia",                      isoCode: "ID", dialCode: "+62",   minLength: 9,  maxLength: 11),
        Country(name: "Iran",                           isoCode: "IR", dialCode: "+98",   minLength: 10, maxLength: 10),
        Country(name: "Iraq",                           isoCode: "IQ", dialCode: "+964",  minLength: 9,  maxLength: 10),
        Country(name: "Ireland",                        isoCode: "IE", dialCode: "+353",  minLength: 7,  maxLength: 9),
        Country(name: "Isle of Man",                    isoCode: "IM", dialCode: "+44",   minLength: 10, maxLength: 10),
        Country(name: "Israel",                         isoCode: "IL", dialCode: "+972",  minLength: 8,  maxLength: 9),
        Country(name: "Italy",                          isoCode: "IT", dialCode: "+39",   minLength: 9,  maxLength: 11),
        Country(name: "Jamaica",                        isoCode: "JM", dialCode: "+1876", minLength: 7,  maxLength: 7),
        Country(name: "Japan",                          isoCode: "JP", dialCode: "+81",   minLength: 10, maxLength: 10),
        Country(name: "Jersey",                         isoCode: "JE", dialCode: "+44",   minLength: 10, maxLength: 10),
        Country(name: "Jordan",                         isoCode: "JO", dialCode: "+962",  minLength: 8,  maxLength: 9),
        Country(name: "Kazakhstan",                     isoCode: "KZ", dialCode: "+7",    minLength: 10, maxLength: 10),
        Country(name: "Kenya",                          isoCode: "KE", dialCode: "+254",  minLength: 9,  maxLength: 9),
        Country(name: "Kiribati",                       isoCode: "KI", dialCode: "+686",  minLength: 5,  maxLength: 8),
        Country(name: "Kosovo",                         isoCode: "XK", dialCode: "+383",  minLength: 8,  maxLength: 9),
        Country(name: "Kuwait",                         isoCode: "KW", dialCode: "+965",  minLength: 8,  maxLength: 8),
        Country(name: "Kyrgyzstan",                     isoCode: "KG", dialCode: "+996",  minLength: 9,  maxLength: 9),
        Country(name: "Laos",                           isoCode: "LA", dialCode: "+856",  minLength: 8,  maxLength: 10),
        Country(name: "Latvia",                         isoCode: "LV", dialCode: "+371",  minLength: 8,  maxLength: 8),
        Country(name: "Lebanon",                        isoCode: "LB", dialCode: "+961",  minLength: 7,  maxLength: 8),
        Country(name: "Lesotho",                        isoCode: "LS", dialCode: "+266",  minLength: 8,  maxLength: 8),
        Country(name: "Liberia",                        isoCode: "LR", dialCode: "+231",  minLength: 7,  maxLength: 9),
        Country(name: "Libya",                          isoCode: "LY", dialCode: "+218",  minLength: 9,  maxLength: 10),
        Country(name: "Liechtenstein",                  isoCode: "LI", dialCode: "+423",  minLength: 7,  maxLength: 7),
        Country(name: "Lithuania",                      isoCode: "LT", dialCode: "+370",  minLength: 8,  maxLength: 8),
        Country(name: "Luxembourg",                     isoCode: "LU", dialCode: "+352",  minLength: 6,  maxLength: 11),
        Country(name: "Macau",                          isoCode: "MO", dialCode: "+853",  minLength: 8,  maxLength: 8),
        Country(name: "Madagascar",                     isoCode: "MG", dialCode: "+261",  minLength: 9,  maxLength: 10),
        Country(name: "Malawi",                         isoCode: "MW", dialCode: "+265",  minLength: 7,  maxLength: 9),
        Country(name: "Malaysia",                       isoCode: "MY", dialCode: "+60",   minLength: 9,  maxLength: 10),
        Country(name: "Maldives",                       isoCode: "MV", dialCode: "+960",  minLength: 7,  maxLength: 7),
        Country(name: "Mali",                           isoCode: "ML", dialCode: "+223",  minLength: 8,  maxLength: 8),
        Country(name: "Malta",                          isoCode: "MT", dialCode: "+356",  minLength: 8,  maxLength: 8),
        Country(name: "Marshall Islands",               isoCode: "MH", dialCode: "+692",  minLength: 7,  maxLength: 7),
        Country(name: "Martinique",                     isoCode: "MQ", dialCode: "+596",  minLength: 9,  maxLength: 9),
        Country(name: "Mauritania",                     isoCode: "MR", dialCode: "+222",  minLength: 8,  maxLength: 8),
        Country(name: "Mauritius",                      isoCode: "MU", dialCode: "+230",  minLength: 7,  maxLength: 8),
        Country(name: "Mayotte",                        isoCode: "YT", dialCode: "+262",  minLength: 9,  maxLength: 9),
        Country(name: "Mexico",                         isoCode: "MX", dialCode: "+52",   minLength: 10, maxLength: 10),
        Country(name: "Micronesia",                     isoCode: "FM", dialCode: "+691",  minLength: 7,  maxLength: 7),
        Country(name: "Moldova",                        isoCode: "MD", dialCode: "+373",  minLength: 8,  maxLength: 8),
        Country(name: "Monaco",                         isoCode: "MC", dialCode: "+377",  minLength: 8,  maxLength: 9),
        Country(name: "Mongolia",                       isoCode: "MN", dialCode: "+976",  minLength: 8,  maxLength: 8),
        Country(name: "Montenegro",                     isoCode: "ME", dialCode: "+382",  minLength: 8,  maxLength: 8),
        Country(name: "Montserrat",                     isoCode: "MS", dialCode: "+1664", minLength: 7,  maxLength: 7),
        Country(name: "Morocco",                        isoCode: "MA", dialCode: "+212",  minLength: 9,  maxLength: 9),
        Country(name: "Mozambique",                     isoCode: "MZ", dialCode: "+258",  minLength: 9,  maxLength: 9),
        Country(name: "Myanmar",                        isoCode: "MM", dialCode: "+95",   minLength: 7,  maxLength: 10),
        Country(name: "Namibia",                        isoCode: "NA", dialCode: "+264",  minLength: 9,  maxLength: 9),
        Country(name: "Nauru",                          isoCode: "NR", dialCode: "+674",  minLength: 7,  maxLength: 7),
        Country(name: "Nepal",                          isoCode: "NP", dialCode: "+977",  minLength: 10, maxLength: 10),
        Country(name: "Netherlands",                    isoCode: "NL", dialCode: "+31",   minLength: 9,  maxLength: 9),
        Country(name: "New Caledonia",                  isoCode: "NC", dialCode: "+687",  minLength: 6,  maxLength: 6),
        Country(name: "New Zealand",                    isoCode: "NZ", dialCode: "+64",   minLength: 8,  maxLength: 10),
        Country(name: "Nicaragua",                      isoCode: "NI", dialCode: "+505",  minLength: 8,  maxLength: 8),
        Country(name: "Niger",                          isoCode: "NE", dialCode: "+227",  minLength: 8,  maxLength: 8),
        Country(name: "Nigeria",                        isoCode: "NG", dialCode: "+234",  minLength: 8,  maxLength: 10),
        Country(name: "North Korea",                    isoCode: "KP", dialCode: "+850",  minLength: 6,  maxLength: 13),
        Country(name: "North Macedonia",                isoCode: "MK", dialCode: "+389",  minLength: 8,  maxLength: 8),
        Country(name: "Norway",                         isoCode: "NO", dialCode: "+47",   minLength: 8,  maxLength: 8),
        Country(name: "Oman",                           isoCode: "OM", dialCode: "+968",  minLength: 8,  maxLength: 8),
        Country(name: "Pakistan",                       isoCode: "PK", dialCode: "+92",   minLength: 10, maxLength: 10),
        Country(name: "Palau",                          isoCode: "PW", dialCode: "+680",  minLength: 7,  maxLength: 7),
        Country(name: "Palestine",                      isoCode: "PS", dialCode: "+970",  minLength: 9,  maxLength: 9),
        Country(name: "Panama",                         isoCode: "PA", dialCode: "+507",  minLength: 7,  maxLength: 8),
        Country(name: "Papua New Guinea",               isoCode: "PG", dialCode: "+675",  minLength: 7,  maxLength: 8),
        Country(name: "Paraguay",                       isoCode: "PY", dialCode: "+595",  minLength: 9,  maxLength: 9),
        Country(name: "Peru",                           isoCode: "PE", dialCode: "+51",   minLength: 8,  maxLength: 9),
        Country(name: "Philippines",                    isoCode: "PH", dialCode: "+63",   minLength: 10, maxLength: 10),
        Country(name: "Poland",                         isoCode: "PL", dialCode: "+48",   minLength: 9,  maxLength: 9),
        Country(name: "Portugal",                       isoCode: "PT", dialCode: "+351",  minLength: 9,  maxLength: 9),
        Country(name: "Puerto Rico",                    isoCode: "PR", dialCode: "+1",    minLength: 10, maxLength: 10),
        Country(name: "Qatar",                          isoCode: "QA", dialCode: "+974",  minLength: 8,  maxLength: 8),
        Country(name: "Réunion",                        isoCode: "RE", dialCode: "+262",  minLength: 9,  maxLength: 9),
        Country(name: "Romania",                        isoCode: "RO", dialCode: "+40",   minLength: 9,  maxLength: 9),
        Country(name: "Russia",                         isoCode: "RU", dialCode: "+7",    minLength: 10, maxLength: 10),
        Country(name: "Rwanda",                         isoCode: "RW", dialCode: "+250",  minLength: 9,  maxLength: 9),
        Country(name: "Saint Kitts and Nevis",          isoCode: "KN", dialCode: "+1869", minLength: 7,  maxLength: 7),
        Country(name: "Saint Lucia",                    isoCode: "LC", dialCode: "+1758", minLength: 7,  maxLength: 7),
        Country(name: "Saint Vincent and the Grenadines", isoCode: "VC", dialCode: "+1784", minLength: 7,  maxLength: 7),
        Country(name: "Samoa",                          isoCode: "WS", dialCode: "+685",  minLength: 5,  maxLength: 7),
        Country(name: "San Marino",                     isoCode: "SM", dialCode: "+378",  minLength: 6,  maxLength: 10),
        Country(name: "São Tomé and Príncipe",          isoCode: "ST", dialCode: "+239",  minLength: 7,  maxLength: 7),
        Country(name: "Saudi Arabia",                   isoCode: "SA", dialCode: "+966",  minLength: 9,  maxLength: 9),
        Country(name: "Senegal",                        isoCode: "SN", dialCode: "+221",  minLength: 9,  maxLength: 9),
        Country(name: "Serbia",                         isoCode: "RS", dialCode: "+381",  minLength: 8,  maxLength: 9),
        Country(name: "Seychelles",                     isoCode: "SC", dialCode: "+248",  minLength: 7,  maxLength: 7),
        Country(name: "Sierra Leone",                   isoCode: "SL", dialCode: "+232",  minLength: 8,  maxLength: 8),
        Country(name: "Singapore",                      isoCode: "SG", dialCode: "+65",   minLength: 8,  maxLength: 8),
        Country(name: "Slovakia",                       isoCode: "SK", dialCode: "+421",  minLength: 9,  maxLength: 9),
        Country(name: "Slovenia",                       isoCode: "SI", dialCode: "+386",  minLength: 8,  maxLength: 8),
        Country(name: "Solomon Islands",                isoCode: "SB", dialCode: "+677",  minLength: 5,  maxLength: 7),
        Country(name: "Somalia",                        isoCode: "SO", dialCode: "+252",  minLength: 7,  maxLength: 8),
        Country(name: "South Africa",                   isoCode: "ZA", dialCode: "+27",   minLength: 9,  maxLength: 9),
        Country(name: "South Korea",                    isoCode: "KR", dialCode: "+82",   minLength: 9,  maxLength: 10),
        Country(name: "South Sudan",                    isoCode: "SS", dialCode: "+211",  minLength: 9,  maxLength: 9),
        Country(name: "Spain",                          isoCode: "ES", dialCode: "+34",   minLength: 9,  maxLength: 9),
        Country(name: "Sri Lanka",                      isoCode: "LK", dialCode: "+94",   minLength: 9,  maxLength: 9),
        Country(name: "Sudan",                          isoCode: "SD", dialCode: "+249",  minLength: 9,  maxLength: 9),
        Country(name: "Suriname",                       isoCode: "SR", dialCode: "+597",  minLength: 6,  maxLength: 7),
        Country(name: "Sweden",                         isoCode: "SE", dialCode: "+46",   minLength: 7,  maxLength: 13),
        Country(name: "Switzerland",                    isoCode: "CH", dialCode: "+41",   minLength: 9,  maxLength: 9),
        Country(name: "Syria",                          isoCode: "SY", dialCode: "+963",  minLength: 8,  maxLength: 9),
        Country(name: "Taiwan",                         isoCode: "TW", dialCode: "+886",  minLength: 9,  maxLength: 9),
        Country(name: "Tajikistan",                     isoCode: "TJ", dialCode: "+992",  minLength: 9,  maxLength: 9),
        Country(name: "Tanzania",                       isoCode: "TZ", dialCode: "+255",  minLength: 9,  maxLength: 9),
        Country(name: "Thailand",                       isoCode: "TH", dialCode: "+66",   minLength: 9,  maxLength: 9),
        Country(name: "Timor-Leste",                    isoCode: "TL", dialCode: "+670",  minLength: 7,  maxLength: 8),
        Country(name: "Togo",                           isoCode: "TG", dialCode: "+228",  minLength: 8,  maxLength: 8),
        Country(name: "Tonga",                          isoCode: "TO", dialCode: "+676",  minLength: 5,  maxLength: 7),
        Country(name: "Trinidad and Tobago",            isoCode: "TT", dialCode: "+1868", minLength: 7,  maxLength: 7),
        Country(name: "Tunisia",                        isoCode: "TN", dialCode: "+216",  minLength: 8,  maxLength: 8),
        Country(name: "Turkey",                         isoCode: "TR", dialCode: "+90",   minLength: 10, maxLength: 10),
        Country(name: "Turkmenistan",                   isoCode: "TM", dialCode: "+993",  minLength: 8,  maxLength: 8),
        Country(name: "Turks and Caicos Islands",       isoCode: "TC", dialCode: "+1649", minLength: 7,  maxLength: 7),
        Country(name: "Tuvalu",                         isoCode: "TV", dialCode: "+688",  minLength: 5,  maxLength: 6),
        Country(name: "Uganda",                         isoCode: "UG", dialCode: "+256",  minLength: 9,  maxLength: 9),
        Country(name: "Ukraine",                        isoCode: "UA", dialCode: "+380",  minLength: 9,  maxLength: 9),
        Country(name: "United Arab Emirates",           isoCode: "AE", dialCode: "+971",  minLength: 8,  maxLength: 9),
        Country(name: "United Kingdom",                 isoCode: "GB", dialCode: "+44",   minLength: 9,  maxLength: 10),
        Country(name: "United States",                  isoCode: "US", dialCode: "+1",    minLength: 10, maxLength: 10),
        Country(name: "Uruguay",                        isoCode: "UY", dialCode: "+598",  minLength: 8,  maxLength: 8),
        Country(name: "Uzbekistan",                     isoCode: "UZ", dialCode: "+998",  minLength: 9,  maxLength: 9),
        Country(name: "Vanuatu",                        isoCode: "VU", dialCode: "+678",  minLength: 5,  maxLength: 7),
        Country(name: "Vatican City",                   isoCode: "VA", dialCode: "+39",   minLength: 9,  maxLength: 11),
        Country(name: "Venezuela",                      isoCode: "VE", dialCode: "+58",   minLength: 10, maxLength: 10),
        Country(name: "Vietnam",                        isoCode: "VN", dialCode: "+84",   minLength: 9,  maxLength: 10),
        Country(name: "Western Sahara",                 isoCode: "EH", dialCode: "+212",  minLength: 9,  maxLength: 9),
        Country(name: "Yemen",                          isoCode: "YE", dialCode: "+967",  minLength: 7,  maxLength: 9),
        Country(name: "Zambia",                         isoCode: "ZM", dialCode: "+260",  minLength: 9,  maxLength: 9),
        Country(name: "Zimbabwe",                       isoCode: "ZW", dialCode: "+263",  minLength: 9,  maxLength: 9),
    ]
}
