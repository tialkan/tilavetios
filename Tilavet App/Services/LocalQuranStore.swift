import Foundation

protocol QuranStoreProtocol {
    var surahs: [QuranSurahSummary] { get }
    var orderedVerses: [QuranVerse] { get }
    func verse(for startPoint: QuranStartPoint) -> QuranVerse?
    func nearbyVerses(around startPoint: QuranStartPoint, radius: Int) -> [QuranVerse]
    func nextVerse(after startPoint: QuranStartPoint) -> QuranVerse?
    func previousVerse(before startPoint: QuranStartPoint) -> QuranVerse?
    func ayahCount(for surahID: Int) -> Int
}

final class LocalQuranStore: QuranStoreProtocol {
    let surahs: [QuranSurahSummary]
    let orderedVerses: [QuranVerse]

    private let verseLookup: [String: QuranVerse]
    private let orderLookup: [String: Int]

    convenience init(bundle: Bundle = .main, resourceName: String = "quran_hafs_uthmani") throws {
        guard let url = bundle.url(forResource: resourceName, withExtension: "json", subdirectory: "Resources") ??
            bundle.url(forResource: resourceName, withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        let data = try Data(contentsOf: url)
        let payload = try JSONDecoder().decode(QuranResourcePayload.self, from: data)
        try self.init(payload: payload)
    }

    init(payload: QuranResourcePayload) throws {
        var summaries = [QuranSurahSummary]()
        var verses = [QuranVerse]()
        var lookup = [String: QuranVerse]()
        var orders = [String: Int]()
        var order = 0

        for surah in payload.surahs {
            summaries.append(
                QuranSurahSummary(
                    id: surah.id,
                    name: surah.name,
                    transliteration: surah.transliteration,
                    revelationType: surah.type,
                    totalVerses: surah.totalVerses
                )
            )

            for verse in surah.verses {
                let words = verse.text
                    .split(whereSeparator: \.isWhitespace)
                    .enumerated()
                    .map { index, word in
                        QuranWord(
                            surahID: surah.id,
                            ayahID: verse.id,
                            wordIndex: index,
                            uthmani: String(word),
                            normalized: ArabicTextNormalizer.normalize(String(word))
                        )
                    }

                let quranVerse = QuranVerse(
                    surahID: surah.id,
                    ayahID: verse.id,
                    surahName: surah.name,
                    transliteration: surah.transliteration,
                    revelationType: surah.type,
                    order: order,
                    text: verse.text,
                    normalizedText: ArabicTextNormalizer.normalize(verse.text),
                    words: words
                )

                verses.append(quranVerse)
                lookup[quranVerse.id] = quranVerse
                orders[quranVerse.id] = order
                order += 1
            }
        }

        surahs = summaries
        orderedVerses = verses
        verseLookup = lookup
        orderLookup = orders
    }

    func verse(for startPoint: QuranStartPoint) -> QuranVerse? {
        verseLookup[startPoint.id]
    }

    func nearbyVerses(around startPoint: QuranStartPoint, radius: Int) -> [QuranVerse] {
        guard let index = orderLookup[startPoint.id] else { return [] }
        let lowerBound = max(0, index - radius)
        let upperBound = min(orderedVerses.count - 1, index + radius)
        return Array(orderedVerses[lowerBound...upperBound])
    }

    func nextVerse(after startPoint: QuranStartPoint) -> QuranVerse? {
        guard let index = orderLookup[startPoint.id], index + 1 < orderedVerses.count else { return nil }
        return orderedVerses[index + 1]
    }

    func previousVerse(before startPoint: QuranStartPoint) -> QuranVerse? {
        guard let index = orderLookup[startPoint.id], index > 0 else { return nil }
        return orderedVerses[index - 1]
    }

    func ayahCount(for surahID: Int) -> Int {
        surahs.first(where: { $0.id == surahID })?.totalVerses ?? 0
    }
}
