#if DEBUG
import Foundation

/// One home for the launch-flag harness (shared-scheme env vars,
/// SIMCTL_CHILD_ prefixes on simctl launch, the phase 7 Maestro flows) so
/// flag names and the "1" convention cannot drift file by file.
enum DebugFlags {
    /// Canned providers, no keys, no network (CaptureComposition).
    static var fixtures: Bool { isOn("FLORADEX_FIXTURES") }
    /// Runs the capture loop unattended from a generated sample photo.
    static var autorun: Bool { isOn("FLORADEX_AUTORUN") }
    /// Opens the first dex entry for screenshots; pairs with initialTab.
    static var opensFirstEntry: Bool { isOn("FLORADEX_ENTRY") }
    /// Raw initial tab id; RootTabView parses it.
    static var initialTab: String? { ProcessInfo.processInfo.environment["FLORADEX_TAB"] }

    private static func isOn(_ key: String) -> Bool {
        ProcessInfo.processInfo.environment[key] == "1"
    }
}
#endif
