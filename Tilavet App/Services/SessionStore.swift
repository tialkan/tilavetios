import Foundation

final class SessionStore {
    private enum Keys {
        static let sessions = "tilavet.sessions"
        static let lastStartPoint = "tilavet.lastStartPoint"
    }

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadSessions() -> [RecitationSession] {
        guard let data = defaults.data(forKey: Keys.sessions),
              let sessions = try? decoder.decode([RecitationSession].self, from: data) else {
            return []
        }
        return sessions.sorted(by: { $0.startedAt > $1.startedAt })
    }

    func save(session: RecitationSession) {
        var sessions = loadSessions()
        sessions.insert(session, at: 0)
        sessions = Array(sessions.prefix(30))
        if let data = try? encoder.encode(sessions) {
            defaults.set(data, forKey: Keys.sessions)
        }
    }

    func loadLastStartPoint() -> QuranStartPoint? {
        guard let data = defaults.data(forKey: Keys.lastStartPoint) else { return nil }
        return try? decoder.decode(QuranStartPoint.self, from: data)
    }

    func saveLastStartPoint(_ startPoint: QuranStartPoint) {
        if let data = try? encoder.encode(startPoint) {
            defaults.set(data, forKey: Keys.lastStartPoint)
        }
    }
}
