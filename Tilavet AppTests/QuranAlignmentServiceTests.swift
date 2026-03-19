import Foundation
import Testing
@testable import Tilavet_App

@MainActor
struct QuranAlignmentServiceTests {
    @Test func keepsCurrentAyahWhenTranscriptMatchesAnchor() throws {
        let store = try LocalQuranStore(payload: Self.payload)
        let service = QuranAlignmentService(
            quranStore: store,
            initialStartPoint: QuranStartPoint(surahID: 1, ayahID: 1)
        )

        let state = service.update(
            transcriptChunk: TranscriptionChunk(
                text: "بسم الله الرحمن",
                isFinal: false,
                latency: 0.2,
                audioDuration: 2.0,
                capturedAt: .now
            )
        )

        #expect(state.ayahID == 1)
        #expect(state.wordIndex >= 2)
        #expect(state.driftState == .aligned || state.driftState == .weakMatch)
    }

    @Test func advancesAfterRepeatedStrongNextAyahCandidate() throws {
        let store = try LocalQuranStore(payload: Self.payload)
        let service = QuranAlignmentService(
            quranStore: store,
            initialStartPoint: QuranStartPoint(surahID: 1, ayahID: 1)
        )

        let first = service.update(
            transcriptChunk: TranscriptionChunk(
                text: "الحمد لله رب العالمين",
                isFinal: false,
                latency: 0.2,
                audioDuration: 2.0,
                capturedAt: .now
            )
        )
        let second = service.update(
            transcriptChunk: TranscriptionChunk(
                text: "الحمد لله رب العالمين",
                isFinal: false,
                latency: 0.2,
                audioDuration: 2.0,
                capturedAt: .now
            )
        )

        #expect(first.ayahID == 1)
        #expect(second.ayahID == 2)
    }

    @Test func weakTranscriptFallsIntoResyncState() throws {
        let store = try LocalQuranStore(payload: Self.payload)
        let service = QuranAlignmentService(
            quranStore: store,
            initialStartPoint: QuranStartPoint(surahID: 1, ayahID: 2)
        )

        let state = service.update(
            transcriptChunk: TranscriptionChunk(
                text: "كلمه بعيده تماما",
                isFinal: false,
                latency: 0.2,
                audioDuration: 1.2,
                capturedAt: .now
            )
        )

        #expect(state.ayahID == 2)
        #expect(state.driftState == .resyncing)
        #expect(state.confidence < 0.75)
    }
}

private extension QuranAlignmentServiceTests {
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
