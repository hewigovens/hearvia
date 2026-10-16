import HearviaSession
import SwiftUI

/// Download, progress or Remove for a downloadable engine's model. Place inside a Form/List section.
public struct DownloadableEngineRow: View {
    let engine: any DownloadableEngine

    public init(_ engine: any DownloadableEngine) {
        self.engine = engine
    }

    public var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(engine.kind.title)
                Text(engine.downloadBytes.formatted(.byteCount(style: .file))).font(.footnote).foregroundStyle(.secondary)
            }
            Spacer()
            if let progress = engine.progress {
                ProgressView(value: progress).frame(width: 80)
            } else if engine.isDownloaded {
                Button("Remove", role: .destructive) { engine.remove() }
            } else {
                Button("Download") { Task { await engine.download() } }.buttonStyle(.bordered)
            }
        }
        if !engine.failure.isEmpty {
            Text(engine.failure).font(.footnote).foregroundStyle(.red)
        }
    }
}
