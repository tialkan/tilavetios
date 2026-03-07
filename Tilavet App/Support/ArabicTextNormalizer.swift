import Foundation

enum ArabicTextNormalizer {
    private static let removalScalars: Set<UnicodeScalar> = {
        var values = Set<UnicodeScalar>()
        let ranges: [ClosedRange<UInt32>] = [
            0x0610...0x061A,
            0x064B...0x065F,
            0x06D6...0x06ED
        ]
        for range in ranges {
            for value in range {
                if let scalar = UnicodeScalar(value) {
                    values.insert(scalar)
                }
            }
        }
        for scalar in ["\u{0640}", "\u{0670}", "\u{06DF}", "\u{06E0}", "\u{06E2}", "\u{06E3}", "\u{06EA}", "\u{06EB}", "\u{06EC}", "\u{06ED}"] {
            values.formUnion(scalar.unicodeScalars)
        }
        return values
    }()

    private static let replacements: [String: String] = [
        "أ": "ا",
        "إ": "ا",
        "آ": "ا",
        "ٱ": "ا",
        "ى": "ي",
        "ئ": "ي",
        "ؤ": "و",
        "ة": "ه",
        "ۡ": "",
        "ۚ": " ",
        "ۛ": " ",
        "ۖ": " ",
        "ۗ": " ",
        "ۘ": " ",
        "ۙ": " ",
        "ۜ": " ",
        "۝": " ",
        "۞": " "
    ]

    static func normalize(_ text: String) -> String {
        let replaced = replacements.reduce(text.precomposedStringWithCanonicalMapping) { partial, entry in
            partial.replacingOccurrences(of: entry.key, with: entry.value)
        }

        var normalized = String.UnicodeScalarView()
        normalized.reserveCapacity(replaced.unicodeScalars.count)

        for scalar in replaced.unicodeScalars {
            if removalScalars.contains(scalar) {
                continue
            }
            if CharacterSet.whitespacesAndNewlines.contains(scalar) || CharacterSet.punctuationCharacters.contains(scalar) || CharacterSet.symbols.contains(scalar) {
                normalized.append(" ")
                continue
            }
            normalized.append(scalar)
        }

        return String(normalized)
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .lowercased()
    }

    static func tokens(from text: String) -> [String] {
        normalize(text).split(separator: " ").map(String.init)
    }
}
