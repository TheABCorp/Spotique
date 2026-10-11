import OSLog

enum Log {
    nonisolated static let network = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "network")
    nonisolated static let auth = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "auth")
    nonisolated static let ui = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "ui")
    nonisolated static let storage = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "storage")
}
