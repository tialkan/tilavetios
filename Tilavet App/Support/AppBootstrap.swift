import Foundation

enum AppBootstrap {
    static func makeQuranStore() -> QuranStoreProtocol {
        if let store = try? LocalQuranStore() {
            return store
        }

        let fallback = QuranResourcePayload(
            source: "fallback",
            version: 1,
            surahs: [
                QuranResourceSurah(
                    id: 1,
                    name: "الفاتحة",
                    transliteration: "Al-Fatihah",
                    type: "meccan",
                    totalVerses: 7,
                    verses: [
                        QuranResourceVerse(id: 1, text: "بسم الله الرحمن الرحيم"),
                        QuranResourceVerse(id: 2, text: "الحمد لله رب العالمين"),
                        QuranResourceVerse(id: 3, text: "الرحمن الرحيم"),
                        QuranResourceVerse(id: 4, text: "مالك يوم الدين"),
                        QuranResourceVerse(id: 5, text: "اياك نعبد واياك نستعين"),
                        QuranResourceVerse(id: 6, text: "اهدنا الصراط المستقيم"),
                        QuranResourceVerse(id: 7, text: "صراط الذين انعمت عليهم غير المغضوب عليهم ولا الضالين")
                    ]
                )
            ]
        )

        return (try? LocalQuranStore(payload: fallback)) ?? UnrecoverableStore()
    }
}

private final class UnrecoverableStore: QuranStoreProtocol {
    let surahs: [QuranSurahSummary] = []
    let orderedVerses: [QuranVerse] = []

    func verse(for startPoint: QuranStartPoint) -> QuranVerse? { nil }
    func nearbyVerses(around startPoint: QuranStartPoint, radius: Int) -> [QuranVerse] { [] }
    func nextVerse(after startPoint: QuranStartPoint) -> QuranVerse? { nil }
    func previousVerse(before startPoint: QuranStartPoint) -> QuranVerse? { nil }
    func ayahCount(for surahID: Int) -> Int { 0 }
}
