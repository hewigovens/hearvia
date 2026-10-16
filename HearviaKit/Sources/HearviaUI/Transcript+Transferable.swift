import CoreTransferable
import HearviaCore
import UniformTypeIdentifiers

/// Shares or exports a transcript as a text file named after its start time; plain text where a file doesn't fit.
extension Transcript: Transferable {
    public static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .utf8PlainText) { Data($0.text.utf8) }
            .suggestedFileName { "\($0.fileName).txt" }
        ProxyRepresentation(exporting: \.text)
    }
}
