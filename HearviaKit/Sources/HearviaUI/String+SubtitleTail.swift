public extension String {
    /// The last `limit` characters, starting on a word when one starts soon after the cut, so a long subtitle stays cheap to lay out.
    func subtitleTail(_ limit: Int) -> String {
        guard count > limit else { return self }
        var tail = suffix(limit)
        if let space = tail.firstIndex(of: " "), tail.distance(from: tail.startIndex, to: space) < 20 {
            tail = tail[tail.index(after: space)...]
        }
        return String(tail)
    }
}
