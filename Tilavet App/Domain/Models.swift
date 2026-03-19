import Foundation

struct QuranResourcePayload: Codable {
    let source: String
    let version: Int
    let surahs: [QuranResourceSurah]
}

struct QuranResourceSurah: Codable {
    let id: Int
    let name: String
    let transliteration: String
    let type: String
    let totalVerses: Int
    let verses: [QuranResourceVerse]
}

struct QuranResourceVerse: Codable {
    let id: Int
    let text: String
}

struct QuranStartPoint: Codable, Hashable, Identifiable, Sendable {
    let surahID: Int
    let ayahID: Int

    var id: String {
        "\(surahID):\(ayahID)"
    }
}

struct QuranSurahSummary: Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
    let transliteration: String
    let revelationType: String
    let totalVerses: Int
}

struct QuranWord: Identifiable, Hashable, Sendable {
    let surahID: Int
    let ayahID: Int
    let wordIndex: Int
    let uthmani: String
    let normalized: String

    var id: String {
        "\(surahID):\(ayahID):\(wordIndex)"
    }
}

struct QuranVerse: Identifiable, Hashable, Sendable {
    let surahID: Int
    let ayahID: Int
    let surahName: String
    let transliteration: String
    let revelationType: String
    let order: Int
    let text: String
    let normalizedText: String
    let words: [QuranWord]

    var id: String {
        "\(surahID):\(ayahID)"
    }

    var startPoint: QuranStartPoint {
        QuranStartPoint(surahID: surahID, ayahID: ayahID)
    }
}

enum DriftState: String, Codable, CaseIterable, Sendable {
    case idle
    case aligned
    case weakMatch
    case resyncing
    case modelUnavailable
}

struct TrackingState: Codable, Equatable, Sendable {
    let surahID: Int
    let ayahID: Int
    let wordIndex: Int
    let confidence: Double
    let driftState: DriftState
    let lastTranscript: String
    let updatedAt: Date

    var startPoint: QuranStartPoint {
        QuranStartPoint(surahID: surahID, ayahID: ayahID)
    }

    static func idle(at startPoint: QuranStartPoint) -> TrackingState {
        TrackingState(
            surahID: startPoint.surahID,
            ayahID: startPoint.ayahID,
            wordIndex: 0,
            confidence: 0,
            driftState: .idle,
            lastTranscript: "",
            updatedAt: .now
        )
    }
}

enum RecitationSessionMode: String, Codable, Sendable {
    case live
    case simulated
}

struct RecitationSession: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let startedAt: Date
    let endedAt: Date
    let startedFrom: QuranStartPoint
    let endedAtPoint: QuranStartPoint
    let averageConfidence: Double
    let driftEvents: Int
    let mode: RecitationSessionMode
}

struct AudioFrame: Sendable {
    let samples: [Float]
    let sampleRate: Int
    let timestamp: Date
    let inputLevel: Float
}

enum AudioSessionEvent: Sendable {
    case interruptionBegan
    case interruptionEnded
    case routeChanged
}

struct TranscriptionChunk: Sendable, Equatable {
    let text: String
    let isFinal: Bool
    let latency: TimeInterval
    let audioDuration: TimeInterval
    let capturedAt: Date
}

struct AlignmentCandidate: Identifiable, Hashable, Sendable {
    let verse: QuranVerse
    let score: Double
    let matchedWords: Int
    let wordIndex: Int

    var id: String {
        verse.id
    }
}

struct DebugSnapshot: Sendable {
    var inputLevel: Float = 0
    var lastLatency: TimeInterval = 0
    var rollingWindowSeconds: TimeInterval = 0
    var candidateSummary: [String] = []
    var modelLocation: String = "Model klasoru eklenmedi"
    var lastError: String?
}
