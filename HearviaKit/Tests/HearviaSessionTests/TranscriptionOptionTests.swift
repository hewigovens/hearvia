import HearviaCore
@testable import HearviaSession
import Testing

@MainActor
struct TranscriptionOptionTests {
    @Test func requestCarriesTheOption() async {
        let harness = Harness()
        await harness.translator.setTranscribesSource(false)
        await harness.translator.start()
        #expect(harness.engines.first?.request.transcribesSource == false)
    }

    @Test func changeRestartsARunningRealtimeEngine() async {
        let harness = Harness()
        await harness.translator.start()
        await harness.translator.setTranscribesSource(false)
        #expect(harness.engines.count == 2)
        #expect(harness.engines[0].stopped && harness.engines[1].request.transcribesSource == false)
        await harness.translator.setTranscribesSource(false) // unchanged: no restart
        #expect(harness.engines.count == 2)
    }

    @Test func onDeviceIgnoresTheChange() async {
        let harness = Harness()
        await harness.translator.setEngine(.onDevice)
        await harness.translator.start()
        await harness.translator.setTranscribesSource(false)
        #expect(harness.engines.count == 1)
    }
}
