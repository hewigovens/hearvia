typealias Translate = @Sendable (String) async throws -> String

struct OnDeviceModelSet: Sendable {
    let speech: any SpeechInput
    /// nil when the spoken and subtitle languages are the same.
    let translate: Translate?
    let strategy: String
    /// On Auto, builds `translate` once the spoken language is known; nil from it means no translation is needed.
    var translator: (@Sendable (_ source: String) async throws -> Translate?)?
}
