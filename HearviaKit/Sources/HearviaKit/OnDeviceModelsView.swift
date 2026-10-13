import SwiftUI
import Translation

/// Status rows + download buttons for the on-device engine's two models. Place inside a Form/List section.
public struct OnDeviceModelsView: View {
    let source: String
    let target: String
    @State private var speech: OnDeviceModels.Availability?
    @State private var text: OnDeviceModels.Availability?
    @State private var speechProgress: Double?
    @State private var download: TranslationSession.Configuration?
    @State private var failure = ""

    public init(source: String, target: String) { self.source = source; self.target = target }

    public var body: some View {
        Group {
            row("Speech recognition · \(LanguageLabel.of(source))", speech, progress: speechProgress) {
                Task { await downloadSpeech() }
            }
            if source != target {
                row("Translation · \(LanguageLabel.of(source)) → \(LanguageLabel.of(target))", text, progress: nil) {
                    download = OnDeviceModels.translationDownload(from: source, to: target)
                }
            }
            if !failure.isEmpty { Text(failure).font(.footnote).foregroundStyle(.red) }
        }
        .task(id: "\(source)>\(target)") { await refresh() }
        .translationTask(download) { session in
            nonisolated(unsafe) let session = session // Used only here, for the system download sheet.
            do { try await session.prepareTranslation() } catch { failure = error.localizedDescription }
            download = nil
            await refresh()
        }
    }

    private func row(_ title: String, _ status: OnDeviceModels.Availability?, progress: Double?, action: @escaping () -> Void) -> some View {
        HStack {
            Text(title)
            Spacer()
            if let progress {
                ProgressView(value: progress).frame(width: 80)
            } else if status == .downloadable {
                Button("Download", action: action).buttonStyle(.bordered)
            } else {
                Text(status?.label ?? "Checking…")
                    .foregroundStyle(status == .installed ? .green : status == .unsupported ? .red : .secondary)
            }
        }
    }

    private func refresh() async {
        failure = ""
        speech = await OnDeviceModels.speech(source)
        text = await OnDeviceModels.translation(from: source, to: target)
    }

    private func downloadSpeech() async {
        speechProgress = 0
        do {
            try await OnDeviceModels.downloadSpeech(source) { p in Task { @MainActor in speechProgress = p } }
        } catch { failure = error.localizedDescription }
        speechProgress = nil
        await refresh()
    }
}
