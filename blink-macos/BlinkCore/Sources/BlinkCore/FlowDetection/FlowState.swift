import Foundation

public enum FlowState: String, Codable, Equatable, Sendable {
    case normal
    case flow
    case deepFlow
    case idle
    case meeting
    case breakPrompted
}
