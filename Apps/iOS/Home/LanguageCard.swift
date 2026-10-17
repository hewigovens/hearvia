import HearviaCore
import HearviaSession
import HearviaUI
import SwiftUI

struct LanguageCard: View {
    let translator: LiveTranslator

    private var autoDetects: Bool {
        translator.engine.detectsSpokenLanguage
    }

    var body: some View {
        HStack(spacing: 4) {
            Menu {
                Picker("Spoken language", selection: Binding(get: { translator.sourceLanguage },
                                                             set: { language in Task { await translator.setSourceLanguage(language) } })) {
                    ForEach(OnDeviceLanguages.shared.spokenChoices(for: translator.engine, including: translator.sourceLanguage), id: \.self) { Text(LanguageName.of($0)).tag($0) }
                }
            } label: {
                LanguageField(caption: "Spoken", value: autoDetects ? "Auto-detect" : LanguageName.short(translator.sourceLanguage), alignment: .leading)
            }
            .disabled(autoDetects)
            Button(action: swap) {
                Image(systemName: "arrow.left.arrow.right").font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.hvAccent)
                    .frame(width: 44, height: 44)
                    .background(Color.hvSurfaceRaised, in: .circle)
            }
            .disabled(autoDetects)
            .opacity(autoDetects ? 0.4 : 1)
            .accessibilityLabel("Swap languages")
            Menu {
                Picker("Subtitles in", selection: Binding(get: { translator.targetLanguage },
                                                          set: { language in Task { await translator.setTargetLanguage(language) } })) {
                    ForEach(OnDeviceLanguages.shared.subtitleChoices(for: translator.engine, including: translator.targetLanguage), id: \.self) { Text(LanguageName.of($0)).tag($0) }
                }
            } label: {
                LanguageField(caption: "Subtitles", value: LanguageName.short(translator.targetLanguage), alignment: .trailing)
            }
        }
        .padding(6)
        .background(Color.hvSurface, in: .rect(cornerRadius: 16, style: .continuous))
    }

    private func swap() {
        let spoken = translator.sourceLanguage, target = translator.targetLanguage
        Task {
            await translator.setSourceLanguage(target)
            await translator.setTargetLanguage(spoken)
        }
    }
}

private struct LanguageField: View {
    let caption: String
    let value: String
    let alignment: HorizontalAlignment

    var body: some View {
        VStack(alignment: alignment, spacing: 2) {
            Text(caption).font(.caption).foregroundStyle(Color.hvMuted)
            Text(value).font(.system(size: 17, weight: .semibold)).foregroundStyle(Color.hvText).lineLimit(1).minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, minHeight: 60, alignment: alignment == .leading ? .leading : .trailing)
        .padding(.horizontal, 12)
        .contentShape(.rect)
    }
}
