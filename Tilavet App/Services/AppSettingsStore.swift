import Combine
import Foundation

@MainActor
final class AppSettingsStore: ObservableObject {
    @Published var showDebugPanel: Bool {
        didSet { defaults.set(showDebugPanel, forKey: Keys.showDebugPanel) }
    }

    @Published var useSimulatedRecitation: Bool {
        didSet { defaults.set(useSimulatedRecitation, forKey: Keys.useSimulatedRecitation) }
    }

    private enum Keys {
        static let showDebugPanel = "tilavet.showDebugPanel"
        static let useSimulatedRecitation = "tilavet.useSimulatedRecitation"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        showDebugPanel = defaults.object(forKey: Keys.showDebugPanel) as? Bool ?? true
        useSimulatedRecitation = defaults.object(forKey: Keys.useSimulatedRecitation) as? Bool ?? true
    }
}
