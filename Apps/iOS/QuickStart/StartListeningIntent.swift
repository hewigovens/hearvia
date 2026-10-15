import AppIntents
import Observation

/// Opens Hearvia and starts listening: behind the Home Screen widget, the Control Center control, the Action
/// button and Shortcuts. Compiled into the app and the widget extension; it always runs in the app.
struct StartListeningIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Listening"
    static let description = IntentDescription("Opens Hearvia and starts live subtitles.")
    /// Listening to other apps needs the iOS screen-sharing sheet, which only appears in the foreground.
    static let openAppWhenRun = true

    @Parameter(title: "Listen to", description: "Leave empty to use the last choice.")
    var source: InputSource?

    init() {}

    init(source: InputSource?) {
        self.source = source
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        QuickStart.shared.request = QuickStartRequest(source: source)
        return .result()
    }
}

/// A start request waiting for the home screen, which may not exist yet when the intent runs on a cold launch.
@MainActor @Observable
final class QuickStart {
    static let shared = QuickStart()
    var request: QuickStartRequest?

    /// Returns the waiting request and clears it, so it is handled once.
    func take() -> QuickStartRequest? {
        defer { request = nil }
        return request
    }
}

struct QuickStartRequest: Equatable {
    /// Nil keeps the last choice.
    let source: InputSource?
    private let id = UUID()
}

extension InputSource: AppEnum {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Audio Source"
    static let caseDisplayRepresentations: [InputSource: DisplayRepresentation] = [
        .otherApps: DisplayRepresentation(title: "Other apps", image: .init(systemName: "square.grid.2x2")),
        .microphone: DisplayRepresentation(title: "Microphone", image: .init(systemName: "mic"))
    ]
}
