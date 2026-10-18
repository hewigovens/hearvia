import HearviaCore
import HearviaEngines
import SwiftUI
import Translation

/// Place inside a Form/List section.
public struct OnDeviceModelsView: View {
    let source: String
    let target: String
    let translates: Bool
    @State private var speech: OnDeviceModels.Availability?
    @State private var text: OnDeviceModels.Availability?
    /// Auto: the installed speech languages it chooses from, and each one's translation into `target`.
    @State private var candidates: [String]?
    @State private var autoText: [String: OnDeviceModels.Availability] = [:]
    @State private var speechProgress: Double?
    @State private var download: TranslationSession.Configuration?
    @State private var failure = ""
    /// Set when the translation download sheet finishes: "" on success, otherwise the error.
    @State private var downloadOutcome: String?

    /// `translates: false` shows only speech recognition, for a translator that isn't Apple's.
    public init(source: String, target: String, translates: Bool = true) {
        self.source = source
        self.target = target
        self.translates = translates
    }

    public var body: some View {
        Group {
            if source.isEmpty {
                autoRows
            } else {
                row("Speech · \(LanguageName.localized(source))", speech, progress: speechProgress) {
                    Task { await downloadSpeech() }
                }
                if translates, source != target {
                    translationRow(from: source, text)
                }
            }
            if !failure.isEmpty {
                Text(failure).font(.footnote).foregroundStyle(.red)
            }
        }
        .task(id: "\(source)>\(target)>\(download == nil)") { await refresh() }
        // The session isn't Sendable and `prepareTranslation` is `@concurrent` (27 SDK), so the work stays off the main actor and only the outcome comes back.
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

    @ViewBuilder private var autoRows: some View {
        HStack {
            Text("Auto-detect").lineLimit(1).layoutPriority(1)
            Spacer(minLength: 8)
            if let candidates {
                Text(candidates.isEmpty ? String(localized: "None downloaded") : candidates.map(LanguageName.short).joined(separator: " · "))
                    .foregroundStyle(candidates.isEmpty ? .red : .green)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            } else {
                Text("Checking…").foregroundStyle(.secondary)
            }
        }
        if translates {
            ForEach((candidates ?? []).filter { $0 != target }, id: \.self) { language in
                translationRow(from: language, autoText[language])
            }
        }
    }

    private func translationRow(from language: String, _ status: OnDeviceModels.Availability?) -> some View {
        row("Translation · \(LanguageName.localized(language)) → \(LanguageName.localized(target))", status, progress: nil) {
            failure = ""
            download = OnDeviceModels.translationDownload(from: language, to: target)
        }
    }

    private func row(_ title: LocalizedStringKey, _ status: OnDeviceModels.Availability?, progress: Double?, action: @escaping () -> Void) -> some View {
        HStack {
            Text(title).lineLimit(1).minimumScaleFactor(0.8)
            Spacer(minLength: 8)
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
        if source.isEmpty {
            let languages = await OnDeviceModels.autoCandidates()
            for language in languages {
                autoText[language] = await OnDeviceModels.translation(from: language, to: target)
            }
            candidates = languages
            return
        }
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
