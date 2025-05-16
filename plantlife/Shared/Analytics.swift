import Foundation

struct Analytics {
    static func log(_ event: String, parameters: [String: Any] = [:]) {
        #if DEBUG
        print("[Analytics] \(event) :: \(parameters)")
        #endif
        // TODO: integrate Firebase Analytics or other provider
    }
} 