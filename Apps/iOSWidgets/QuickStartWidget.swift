import AppIntents
import HearviaUI
import SwiftUI
import WidgetKit

/// Home Screen and Lock Screen widget that starts listening: the last source (small, Lock Screen) or a choice
/// of source (medium). It shows no live state, so its timeline never changes.
struct QuickStartWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "dev.hewig.hearvia.widget.start", provider: Provider()) { _ in
            QuickStartView()
                .containerBackground(Color.hvGround, for: .widget)
        }
        .configurationDisplayName("Start Hearvia")
        .description("Start live subtitles in one tap.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
    }

    struct Provider: TimelineProvider {
        func placeholder(in _: Context) -> Entry {
            Entry(date: .now)
        }

        func getSnapshot(in _: Context, completion: @escaping (Entry) -> Void) {
            completion(Entry(date: .now))
        }

        func getTimeline(in _: Context, completion: @escaping (Timeline<Entry>) -> Void) {
            completion(Timeline(entries: [Entry(date: .now)], policy: .never))
        }
    }

    struct Entry: TimelineEntry {
        let date: Date
    }
}

private struct QuickStartView: View {
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            Button(intent: StartListeningIntent()) {
                ZStack {
                    AccessoryWidgetBackground()
                    Image(systemName: "captions.bubble.fill").font(.title2)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Start Hearvia")
        case .accessoryRectangular:
            Button(intent: StartListeningIntent()) {
                Label("Start Hearvia", systemImage: "captions.bubble.fill").font(.headline)
            }
            .buttonStyle(.plain)
        case .systemMedium:
            VStack(alignment: .leading, spacing: 12) {
                header
                HStack(spacing: 10) {
                    ForEach(InputSource.allCases) { source in
                        StartButton(title: source.title, symbol: source.symbol, intent: StartListeningIntent(source: source))
                    }
                }
            }
        default:
            VStack(alignment: .leading, spacing: 0) {
                header
                Spacer(minLength: 8)
                StartButton(title: "Start", symbol: "play.fill", intent: StartListeningIntent())
            }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            HearviaIcon(size: 26)
            VStack(alignment: .leading, spacing: 0) {
                Text("Hearvia").font(.subheadline.weight(.bold)).foregroundStyle(Color.hvText)
                Text("Live subtitles").font(.caption2).foregroundStyle(Color.hvMuted)
            }
        }
    }
}

/// The accent pill used for every start action in the widget.
private struct StartButton: View {
    let title: String
    let symbol: String
    let intent: StartListeningIntent

    var body: some View {
        Button(intent: intent) {
            Label(title, systemImage: symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.hvOnAccent)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(Color.hvAccent, in: .capsule)
        }
        .buttonStyle(.plain)
    }
}
