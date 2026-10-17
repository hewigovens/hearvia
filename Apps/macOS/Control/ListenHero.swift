import HearviaUI
import SwiftUI

struct ListenHero: View {
    let model: AppModel

    var body: some View {
        let listening = model.capturing
        let layout = listening ? AnyLayout(HStackLayout(spacing: 12)) : AnyLayout(VStackLayout(spacing: 6))
        layout {
            ListenButton(listening: listening, size: listening ? 40 : 72) {
                Task { await model.toggleListening() }
            }
            .keyboardShortcut(.return, modifiers: .command)
            .padding(.vertical, listening ? 0 : 6)
            VStack(alignment: listening ? .leading : .center, spacing: 2) {
                Text(listening ? "Listening" : "Start listening")
                    .font(.system(size: listening ? 14 : 15, weight: .semibold))
                    .lineLimit(1)
                Group {
                    if listening, let since = model.capturingSince {
                        TimelineView(.periodic(from: since, by: 1)) { context in
                            Text("\(Duration.seconds(context.date.timeIntervalSince(since).rounded(.down)), format: .time(pattern: .minuteSecond)) · ⌘↩ to stop")
                        }
                    } else {
                        Text("⌘↩ · other apps keep playing")
                    }
                }
                .font(.caption).monospacedDigit().foregroundStyle(Color.hvMuted)
            }
            if listening {
                Spacer(minLength: 0)
                LevelBars(levels: model.levels)
                    .scaleEffect(0.66, anchor: .trailing)
                    .frame(width: 52, alignment: .trailing)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(listening ? 10 : 0)
        .background(listening ? Color.hvAccentSoft : .clear, in: .rect(cornerRadius: 14, style: .continuous))
    }
}
