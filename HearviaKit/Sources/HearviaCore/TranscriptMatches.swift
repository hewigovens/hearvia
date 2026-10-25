import Foundation

/// The rows a transcripts list shows for a query: the session in progress when it matches, then the saved sessions that match.
public struct TranscriptMatches {
    public let live: Transcript?
    public let saved: [Transcript]
    /// False for a blank query, which lists every session.
    public let isSearching: Bool

    public init(query: String, live: Transcript?, saved: [Transcript]) {
        isSearching = !TranscriptSearch.needle(query).isEmpty
        self.live = live.flatMap { $0.matches(query) ? $0 : nil }
        self.saved = saved.filter { $0.matches(query) }
    }

    public var isEmpty: Bool {
        live == nil && saved.isEmpty
    }

    public var nothingMatches: Bool {
        isSearching && isEmpty
    }

    public var ids: [UUID] {
        (live.map { [$0.id] } ?? []) + saved.map(\.id)
    }

    /// `selection` while its row is listed, otherwise the first row.
    public func selection(keeping selection: UUID?) -> UUID? {
        if let selection, ids.contains(selection) {
            return selection
        }
        return ids.first
    }
}
