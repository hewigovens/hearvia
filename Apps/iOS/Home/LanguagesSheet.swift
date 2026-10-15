import HearviaSession
import SwiftUI

struct LanguagesSheet: View {
    let translator: LiveTranslator

    var body: some View {
        TileSheet(title: "Languages") {
            LanguageCard(translator: translator)
        }
    }
}
