import os

/// Centralized logger for the entire app. All values are logged with public privacy
/// so they're readable in exported logs (os.Logger redacts dynamic values by default in Release).
enum BlinkLog {
    static let app      = make("AppState")
    static let context  = make("Context")
    static let ui       = make("UI")
    static let menuBar  = make("MenuBar")
    static let update   = make("Update")

    private static func make(_ category: String) -> BlinkLogger {
        BlinkLogger(Logger(subsystem: "com.blink20.app", category: category))
    }
}

/// Thin wrapper around os.Logger that forces public privacy on all interpolations.
struct BlinkLogger {
    private let logger: Logger

    init(_ logger: Logger) {
        self.logger = logger
    }

    func info(_ message: String) {
        logger.info("\(message, privacy: .public)")
    }

    func debug(_ message: String) {
        logger.debug("\(message, privacy: .public)")
    }

    func error(_ message: String) {
        logger.error("\(message, privacy: .public)")
    }
}
