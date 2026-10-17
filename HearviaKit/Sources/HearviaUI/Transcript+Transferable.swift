import CoreTransferable
import HearviaCore
import UniformTypeIdentifiers

extension Transcript: Transferable {
    public static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .utf8PlainText) { Data($0.text.utf8) }
            .suggestedFileName { "\($0.fileName).txt" }
        ProxyRepresentation(exporting: \.text)
    }
}
