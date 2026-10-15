import SwiftUI

struct SourceSheet: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        TileSheet(title: "Listen to") {
            ForEach(InputSource.allCases) { source in
                ChoiceRow(symbol: source.symbol, title: source.title, detail: source.detail, selected: settings.input == source) {
                    settings.input = source
                }
            }
        }
    }
}
