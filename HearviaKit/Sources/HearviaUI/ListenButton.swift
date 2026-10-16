import SwiftUI

/// Round Start/Stop control: an accent play button with a breathing glow that turns into a pulsing red stop button.
/// Every press sends a ripple out; `busy` shows progress while capture is starting.
public struct ListenButton: View {
    let listening: Bool
    let busy: Bool
    let size: CGFloat
    let action: () -> Void
    @State private var presses = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(listening: Bool, busy: Bool = false, size: CGFloat, action: @escaping () -> Void) {
        self.listening = listening
        self.busy = busy
        self.size = size
        self.action = action
    }

    public var body: some View {
        Button {
            presses += 1
            action()
        } label: {
            ZStack {
                Circle().fill(fill)
                if busy, !listening {
                    ProgressView().tint(Color.hvText)
                } else {
                    Image(systemName: listening ? "stop.fill" : "play.fill")
                        .font(.system(size: size * 0.34, weight: .bold))
                        .foregroundStyle(listening ? Color.white : Color.hvOnAccent)
                        .offset(x: listening ? 0 : size * 0.03) // Optical centring: the triangle's mass sits left of its frame.
                        .contentTransition(.symbolEffect(.replace))
                }
            }
            .frame(width: size, height: size)
            .shadow(color: (listening ? Color.hvStop : Color.hvAccent).opacity(busy ? 0 : 0.3), radius: size * 0.16, y: size * 0.08)
            .contentShape(.circle)
        }
        .buttonStyle(PressStyle())
        .focusEffectDisabled()
        .background {
            if !reduceMotion {
                if listening {
                    Pulse()
                } else if !busy {
                    Breath()
                }
                Ripple(delay: 0, trigger: presses)
                Ripple(delay: 0.14, trigger: presses)
            }
        }
        .accessibilityLabel(busy && !listening ? "Cancel" : listening ? "Stop listening" : "Start listening")
    }

    private var fill: Color {
        busy && !listening ? .hvSurfaceRaised : listening ? .hvStop : .hvAccent
    }
}

private struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// The live indicator behind the stop button.
private struct Pulse: View {
    var body: some View {
        Circle().fill(Color.hvStop)
            .phaseAnimator([false, true]) { circle, expanded in
                circle.scaleEffect(expanded ? 1.6 : 1).opacity(expanded ? 0 : 0.45)
            } animation: { expanded in
                expanded ? .easeOut(duration: 1.8) : nil
            }
            .allowsHitTesting(false)
    }
}

/// The idle glow behind the play button, slowly breathing in and out.
private struct Breath: View {
    var body: some View {
        Circle().fill(Color.hvAccent)
            .blur(radius: 10)
            .phaseAnimator([false, true]) { glow, inhaled in
                glow.scaleEffect(inhaled ? 1.22 : 1.02).opacity(inhaled ? 0.5 : 0.15)
            } animation: { _ in
                .easeInOut(duration: 2.2)
            }
            .allowsHitTesting(false)
    }
}

/// A ring that grows out of the button and fades once per press.
private struct Ripple: View {
    let delay: Double
    let trigger: Int

    var body: some View {
        Circle().strokeBorder(Color.hvAccent, lineWidth: 2)
            .keyframeAnimator(initialValue: Frame(), trigger: trigger) { ring, frame in
                ring.scaleEffect(frame.scale).opacity(frame.opacity)
            } keyframes: { _ in
                KeyframeTrack(\.scale) {
                    MoveKeyframe(1)
                    LinearKeyframe(1, duration: delay)
                    CubicKeyframe(2.1, duration: 0.75)
                }
                KeyframeTrack(\.opacity) {
                    MoveKeyframe(0)
                    LinearKeyframe(0, duration: delay)
                    MoveKeyframe(0.6)
                    LinearKeyframe(0, duration: 0.75)
                }
            }
            .allowsHitTesting(false)
    }

    struct Frame {
        var scale = 1.0
        var opacity = 0.0
    }
}
