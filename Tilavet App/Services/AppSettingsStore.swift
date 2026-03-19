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

    private enum LaunchArgument {
        static let resetDefaults = "-tilavet-reset-defaults"
        static let showDebugPanel = "-tilavet-show-debug"
        static let simulateRecitation = "-tilavet-simulated-recitation"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard, processInfo: ProcessInfo = .processInfo) {
        self.defaults = defaults

        if processInfo.arguments.contains(LaunchArgument.resetDefaults) {
            defaults.removeObject(forKey: Keys.showDebugPanel)
            defaults.removeObject(forKey: Keys.useSimulatedRecitation)
        }

        showDebugPanel = defaults.object(forKey: Keys.showDebugPanel) as? Bool ?? false
        useSimulatedRecitation = defaults.object(forKey: Keys.useSimulatedRecitation) as? Bool ?? false

        if processInfo.arguments.contains(LaunchArgument.showDebugPanel) {
            showDebugPanel = true
        }
        if processInfo.arguments.contains(LaunchArgument.simulateRecitation) {
            useSimulatedRecitation = true
        }
    }
}
