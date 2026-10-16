import Foundation

public struct TranscriptLine: Identifiable, Sendable, Equatable, Codable {
    public let id: Int
    public let source: String
    public let translation: String
    /// When the sentence finished.
    public let time: Date
}
