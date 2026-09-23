//
//  APIBodyDump.swift
//  SmartShop
//

import Foundation

/// Prints a raw response body to the Xcode console, for inspecting what the
/// server *actually* sends rather than what our DTO managed to decode.
///
/// This exists because a `Decodable` is a filter: a field the server sends and
/// our type does not declare is silently dropped, so "the app shows no date of
/// birth" and "the server sends no date of birth" look identical from inside
/// the app. This shows the difference.
///
/// **Debug builds only, and only for paths explicitly listed below** — a blanket
/// dump would put every access token in the console.
///
/// Temporary. Delete `watchedPaths` (or the file) once the question it was added
/// to answer has been answered.
nonisolated enum APIBodyDump {
    /// Substrings of paths worth dumping. Empty disables it entirely.
    private static let watchedPaths: [String] = [
        "auth/mitid/complete"
    ]

    /// Values replaced before printing. These are credentials, not data.
    private static let redactedKeys: Set<String> = [
        "accessToken", "refreshToken", "token", "reference"
    ]

    static func ifWanted(path: String, status: Int, body: Data) {
        #if DEBUG
        guard watchedPaths.contains(where: path.contains) else { return }

        print("""

        ┌── API RESPONSE ──────────────────────────────────────────
        │ \(path)  →  HTTP \(status)
        ├──────────────────────────────────────────────────────────
        \(redactedJSON(body))
        └──────────────────────────────────────────────────────────

        """)
        #endif
    }

    /// Pretty-prints the body with credential values replaced. Falls back to
    /// the raw text when it is not JSON at all, since an HTML error page from a
    /// proxy is exactly the sort of thing worth seeing.
    private static func redactedJSON(_ body: Data) -> String {
        guard let parsed = try? JSONSerialization.jsonObject(with: body),
              let cleaned = try? JSONSerialization.data(
                withJSONObject: redact(parsed),
                options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
              ),
              let text = String(data: cleaned, encoding: .utf8)
        else {
            return String(data: body, encoding: .utf8) ?? "<\(body.count) bytes, not text>"
        }
        return text.split(separator: "\n").map { "│ " + $0 }.joined(separator: "\n")
    }

    private static func redact(_ value: Any) -> Any {
        switch value {
        case let dictionary as [String: Any]:
            dictionary.reduce(into: [String: Any]()) { result, pair in
                result[pair.key] = redactedKeys.contains(pair.key)
                    ? "<redacted \((pair.value as? String)?.count ?? 0) chars>"
                    : redact(pair.value)
            }
        case let array as [Any]:
            array.map(redact)
        default:
            value
        }
    }
}
