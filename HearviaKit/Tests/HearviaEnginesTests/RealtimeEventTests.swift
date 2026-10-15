import Foundation
@testable import HearviaEngines
import Testing

@Test func parsesTranslationEvents() {
    let delta = #"{"type":"session.output_transcript.delta","delta":"你好","elapsed_ms":1200}"#
    guard case let .translationDelta(text, ms) = RealtimeTranslationClient.parse(Data(delta.utf8)) else { Issue.record()
        return
    }
    #expect(text == "你好" && ms == 1200)
    let error = #"{"type":"error","error":{"type":"invalid_request_error","code":"invalid_event","message":"bad"}}"#
    guard case let .serverError(_, code, message) = RealtimeTranslationClient.parse(Data(error.utf8)) else { Issue.record()
        return
    }
    #expect(code == "invalid_event" && message == "bad")
}
