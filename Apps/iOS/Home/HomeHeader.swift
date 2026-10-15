import HearviaKit
import SwiftUI

/// The wordmark when ready; a live "Listening" pill with elapsed time while listening.
struct HomeHeader: View {
    let model: AppModel
    let present: (HomePresentation) -> Void

    var body: some View {
        HStack {
            if model.listening {
                listeningPill
            } else {
                Text("Hearvia").font(.system(size: 32, weight: .bold)).tracking(-0.5)
            }
            Spacer()
            if !model.listening {
                CircleButton(symbol: "questionmark", label: "How it works") { present(.onboarding) }
            }
            CircleButton(symbol: "gearshape", label: "Settings") { present(.settings) }
                .accessibilityIdentifier("settings")
        }
    }

    private var listeningPill: some View {
        HStack(spacing: 10) {
            Circle().fill(Color.hvAccent).frame(width: 10, height: 10)
                .background(Circle().fill(Color.hvAccent.opacity(0.28)).frame(width: 18, height: 18))
            Text("Listening · \(model.micRunning ? "Microphone" : "Other apps")").font(.subheadline.weight(.semibold))
            if let since = model.listeningSince {
                TimelineView(.periodic(from: since, by: 1)) { context in
                    Text(Duration.seconds(context.date.timeIntervalSince(since).rounded(.down)), format: .time(pattern: .minuteSecond))
                        .font(.subheadline).monospacedDigit().foregroundStyle(Color.hvMuted)
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 14)
        .background(Color.hvAccentSoft, in: .capsule)
    }
}
