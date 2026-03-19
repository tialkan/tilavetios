import Foundation
import Testing
@testable import Tilavet_App

@MainActor
struct QuranStoreTests {
    @Test func loadsOrderedVersesAndNeighbors() throws {
        let store = try LocalQuranStore(payload: Self.payload)

        #expect(store.surahs.count == 1)
        #expect(store.orderedVerses.count == 3)
        #expect(store.nextVerse(after: QuranStartPoint(surahID: 1, ayahID: 1))?.ayahID == 2)
        #expect(store.previousVerse(before: QuranStartPoint(surahID: 1, ayahID: 3))?.ayahID == 2)
    }
}

private extension QuranStoreTests {
    static let payload = QuranResourcePayload(
        source: "tests",
        version: 1,
        surahs: [
            QuranResourceSurah(
                id: 1,
                name: "الفاتحة",
                transliteration: "Al-Fatihah",
                type: "meccan",
                totalVerses: 3,
                verses: [
                    QuranResourceVerse(id: 1, text: "بسم الله الرحمن الرحيم"),
                    QuranResourceVerse(id: 2, text: "الحمد لله رب العالمين"),
                    QuranResourceVerse(id: 3, text: "الرحمن الرحيم")
                ]
            )
        ]
    )
}
