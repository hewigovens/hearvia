import HearviaSession
import HearviaUI
import SwiftUI

struct LanguagesSheet: View {
    let translator: LiveTranslator

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Languages").font(.title3.weight(.semibold))
            LanguageCard(translator: translator)
            if translator.engine.detectsSpokenLanguage {
                Text("OpenAI Realtime detects the spoken language.").font(.footnote).foregroundStyle(Color.hvMuted)
            }
        }
        .padding(20)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color.hvGround)
        .foregroundStyle(Color.hvText)
        .presentationDetents([.height(220)])
    }
}
