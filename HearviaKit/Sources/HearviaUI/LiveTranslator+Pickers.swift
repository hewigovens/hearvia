import HearviaCore
import HearviaSession
import SwiftUI

/// Picker selections go through the async setters, which restart a running engine when the change needs it.
public extension LiveTranslator {
    var sourceLanguageSelection: Binding<String> {
        Binding(get: { self.sourceLanguage }, set: { language in Task { await self.setSourceLanguage(language) } })
    }

    var targetLanguageSelection: Binding<String> {
        Binding(get: { self.targetLanguage }, set: { language in Task { await self.setTargetLanguage(language) } })
    }

    var spokenChoices: [String] {
        OnDeviceLanguages.shared.spokenChoices(for: engine, including: sourceLanguage)
    }

    var subtitleChoices: [String] {
        OnDeviceLanguages.shared.subtitleChoices(for: engine, including: targetLanguage)
    }
}
