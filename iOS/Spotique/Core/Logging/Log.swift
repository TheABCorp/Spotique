import OSLog

enum Log {
    static let network = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "network")
    static let auth = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "auth")
    static let ui = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "ui")
    static let storage = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "storage")
}
