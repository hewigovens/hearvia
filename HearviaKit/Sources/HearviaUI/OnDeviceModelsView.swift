import HearviaCore
import HearviaEngines
import SwiftUI
import Translation

/// Status rows + download buttons for the on-device engine's two models. Place inside a Form/List section.
public struct OnDeviceModelsView: View {
    let source: String
    let target: String
    let translates: Bool
    @State private var speech: OnDeviceModels.Availability?
    @State private var text: OnDeviceModels.Availability?
    @State private var speechProgress: Double?
    @State private var download: TranslationSession.Configuration?
    @State private var failure = ""
    /// Set when the translation download sheet finishes: "" on success, otherwise the error.
    @State private var downloadOutcome: String?

    /// `translates: false` shows only speech recognition, for engines that bring their own translator.
    public init(source: String, target: String, translates: Bool = true) {
        self.source = source
        self.target = target
        self.translates = translates
    }

    public var body: some View {
        Group {
            row("Speech recognition · \(LanguageName.localized(source))", speech, progress: speechProgress) {
                Task { await downloadSpeech() }
            }
            if translates, source != target {
                row("Translation · \(LanguageName.localized(source)) → \(LanguageName.localized(target))", text, progress: nil) {
                    failure = ""
                    download = OnDeviceModels.translationDownload(from: source, to: target)
                }
            }
            if !failure.isEmpty {
                Text(failure).font(.footnote).foregroundStyle(.red)
            }
        }
        .task(id: "\(source)>\(target)>\(download == nil)") { await refresh() }
        // The session isn't Sendable and `prepareTranslation` is `@concurrent` (27 SDK), so the work stays off the
        // main actor and only the outcome comes back.
        .translationTask(download) { @concurrent [outcome = $downloadOutcome] session in
            var message = ""
            do { try await session.prepareTranslation() } catch { message = error.localizedDescription }
            await MainActor.run { outcome.wrappedValue = message }
        }
        .onChange(of: downloadOutcome) { _, outcome in
            guard let outcome else { return }
            failure = outcome
            download = nil // Refreshes the rows.
            downloadOutcome = nil
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
        speech = await OnDeviceModels.speech(source)
        text = await OnDeviceModels.translation(from: source, to: target)
    }

    private func downloadSpeech() async {
        failure = ""
        speechProgress = 0
        do {
            try await OnDeviceModels.downloadSpeech(source) { p in Task { @MainActor in speechProgress = p } }
        } catch { failure = error.localizedDescription }
        speechProgress = nil
        await refresh()
    }
}
