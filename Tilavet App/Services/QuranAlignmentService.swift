import Foundation

protocol QuranAlignmentServiceProtocol {
    var lastCandidates: [AlignmentCandidate] { get }
    func reset(to startPoint: QuranStartPoint)
    func update(transcriptChunk: TranscriptionChunk) -> TrackingState
}

final class QuranAlignmentService: QuranAlignmentServiceProtocol {
    private let quranStore: QuranStoreProtocol
    private(set) var lastCandidates: [AlignmentCandidate] = []

    private var anchor: QuranStartPoint
    private var lastState: TrackingState
    private var pendingAdvance: QuranStartPoint?
    private var pendingAdvanceCount = 0

    init(quranStore: QuranStoreProtocol, initialStartPoint: QuranStartPoint) {
        self.quranStore = quranStore
        anchor = initialStartPoint
        lastState = .idle(at: initialStartPoint)
    }

    func reset(to startPoint: QuranStartPoint) {
        anchor = startPoint
        lastState = .idle(at: startPoint)
        pendingAdvance = nil
        pendingAdvanceCount = 0
        lastCandidates = []
    }

    func update(transcriptChunk: TranscriptionChunk) -> TrackingState {
        let transcriptTokens = ArabicTextNormalizer.tokens(from: transcriptChunk.text)
        guard !transcriptTokens.isEmpty else {
            lastState = TrackingState(
                surahID: lastState.surahID,
                ayahID: lastState.ayahID,
                wordIndex: lastState.wordIndex,
                confidence: lastState.confidence * 0.96,
                driftState: lastState.driftState == .modelUnavailable ? .modelUnavailable : .weakMatch,
                lastTranscript: transcriptChunk.text,
                updatedAt: transcriptChunk.capturedAt
            )
            return lastState
        }

        let candidates = quranStore.nearbyVerses(around: anchor, radius: 2)
            .map { verse in
                score(tokens: transcriptTokens, for: verse)
            }
            .sorted { lhs, rhs in
                if lhs.score == rhs.score {
                    return lhs.verse.order < rhs.verse.order
                }
                return lhs.score > rhs.score
            }

        lastCandidates = candidates

        guard let best = candidates.first else {
            return lastState
        }

        let current = candidates.first(where: { $0.verse.startPoint == anchor }) ?? best
        var resolved = current

        if best.verse.order > current.verse.order && best.score - current.score >= 0.15 {
            if pendingAdvance == best.verse.startPoint {
                pendingAdvanceCount += 1
            } else {
                pendingAdvance = best.verse.startPoint
                pendingAdvanceCount = 1
            }
            if pendingAdvanceCount >= 2 {
                resolved = best
                anchor = best.verse.startPoint
                pendingAdvance = nil
                pendingAdvanceCount = 0
            }
        } else if best.score >= 0.82 || (current.score < 0.55 && best.score >= 0.7) {
            resolved = best
            anchor = best.verse.startPoint
            pendingAdvance = nil
            pendingAdvanceCount = 0
        } else {
            pendingAdvance = nil
            pendingAdvanceCount = 0
        }

        let driftState: DriftState
        switch resolved.score {
        case 0.85...:
            driftState = .aligned
        case 0.75..<0.85:
            driftState = .weakMatch
        default:
            driftState = .resyncing
        }

        lastState = TrackingState(
            surahID: resolved.verse.surahID,
            ayahID: resolved.verse.ayahID,
            wordIndex: resolved.wordIndex,
            confidence: resolved.score,
            driftState: driftState,
            lastTranscript: transcriptChunk.text,
            updatedAt: transcriptChunk.capturedAt
        )
        return lastState
    }

    private func score(tokens transcriptTokens: [String], for verse: QuranVerse) -> AlignmentCandidate {
        let verseTokens = verse.words.map(\.normalized)
        let lcsResult = longestCommonSubsequence(transcriptTokens, verseTokens)
        let coverage = transcriptTokens.isEmpty ? 0 : Double(lcsResult.matches.count) / Double(transcriptTokens.count)
        let verseCoverage = verseTokens.isEmpty ? 0 : Double(lcsResult.matches.count) / Double(verseTokens.count)
        let progressBonus = lcsResult.lastVerseIndex.map { Double($0 + 1) / Double(max(verseTokens.count, 1)) } ?? 0
        let score = min(1, max(0, coverage * 0.72 + verseCoverage * 0.18 + progressBonus * 0.10))

        return AlignmentCandidate(
            verse: verse,
            score: score,
            matchedWords: lcsResult.matches.count,
            wordIndex: min(lcsResult.lastVerseIndex ?? max(lastState.wordIndex, 0), max(verse.words.count - 1, 0))
        )
    }

    private func longestCommonSubsequence(_ lhs: [String], _ rhs: [String]) -> (matches: [(Int, Int)], lastVerseIndex: Int?) {
        guard !lhs.isEmpty && !rhs.isEmpty else {
            return ([], nil)
        }

        var dp = Array(repeating: Array(repeating: 0, count: rhs.count + 1), count: lhs.count + 1)

        for i in 1...lhs.count {
            for j in 1...rhs.count {
                if tokensMatch(lhs[i - 1], rhs[j - 1]) {
                    dp[i][j] = dp[i - 1][j - 1] + 1
                } else {
                    dp[i][j] = max(dp[i - 1][j], dp[i][j - 1])
                }
            }
        }

        var matches = [(Int, Int)]()
        var i = lhs.count
        var j = rhs.count

        while i > 0 && j > 0 {
            if tokensMatch(lhs[i - 1], rhs[j - 1]) {
                matches.append((i - 1, j - 1))
                i -= 1
                j -= 1
            } else if dp[i - 1][j] >= dp[i][j - 1] {
                i -= 1
            } else {
                j -= 1
            }
        }

        matches.reverse()
        return (matches, matches.last?.1)
    }

    private func tokensMatch(_ lhs: String, _ rhs: String) -> Bool {
        if lhs == rhs {
            return true
        }
        if lhs.isEmpty || rhs.isEmpty {
            return false
        }
        let overlap = Double(commonPrefixCount(lhs, rhs)) / Double(max(lhs.count, rhs.count))
        if overlap >= 0.75 {
            return true
        }
        return levenshteinDistance(lhs, rhs) <= 1
    }

    private func commonPrefixCount(_ lhs: String, _ rhs: String) -> Int {
        zip(lhs, rhs).prefix { $0 == $1 }.count
    }

    private func levenshteinDistance(_ lhs: String, _ rhs: String) -> Int {
        let lhsChars = Array(lhs)
        let rhsChars = Array(rhs)
        var previous = Array(0...rhsChars.count)
        for (lhsIndex, lhsChar) in lhsChars.enumerated() {
            var current = [lhsIndex + 1]
            current.reserveCapacity(rhsChars.count + 1)
            for (rhsIndex, rhsChar) in rhsChars.enumerated() {
                let cost = lhsChar == rhsChar ? 0 : 1
                current.append(
                    min(
                        current[rhsIndex] + 1,
                        previous[rhsIndex + 1] + 1,
                        previous[rhsIndex] + cost
                    )
                )
            }
            previous = current
        }
        return previous.last ?? .max
    }
}
