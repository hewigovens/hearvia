import Foundation

public struct TranscriptLine: Identifiable, Sendable, Equatable, Codable {
    public let id: Int
    public let source: String
    public let translation: String
    public let time: Date
}
