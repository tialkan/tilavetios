import Testing
@testable import Tilavet_App

struct ArabicTextNormalizerTests {
    @Test func stripsHarakatAndNormalizesVariants() {
        let normalized = ArabicTextNormalizer.normalize("ٱلۡحَمۡدُ لِلَّهِ رَبِّ ٱلۡعَٰلَمِينَ")
        #expect(normalized == "الحمد لله رب العالمين")
    }

    @Test func tokenizesIntoComparableWords() {
        let tokens = ArabicTextNormalizer.tokens(from: "إِيَّاكَ نَعۡبُدُ وَإِيَّاكَ نَسۡتَعِينُ")
        #expect(tokens == ["اياك", "نعبد", "واياك", "نستعين"])
    }
}
