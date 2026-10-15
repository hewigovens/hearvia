import Foundation

public struct TranscriptLine: Identifiable, Sendable, Equatable {
    public let id: Int
    public let source: String
    public let translation: String
}
