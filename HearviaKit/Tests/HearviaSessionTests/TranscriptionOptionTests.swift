import HearviaCore
@testable import HearviaSession
import Observation
import Testing

@MainActor @Observable
private final class OriginalSetting {
    var shown = true
}

@MainActor
struct TranscriptionOptionTests {
    @Test func requestCarriesTheOption() async {
        let harness = Harness()
        await harness.translator.setTranscribesSource(false)
        await harness.translator.start()
        #expect(harness.engines.first?.request.transcribesSource == false)
    }

    @Test func requestSaysWhenTheInputIsTheMicrophone() async {
        let harness = Harness()
        harness.translator.listensToMicrophone = true
        await harness.translator.start()
        #expect(harness.engines.first?.request.listensToMicrophone == true)
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

    @Test func followsTheShowOriginalAndSaveSettings() async {
        let harness = Harness()
        let setting = OriginalSetting()
        harness.translator.transcribeSource { [setting] in setting.shown }
        setting.shown = false
        await harness.settle()
        #expect(harness.translator.transcribesSource) // saved transcripts keep the original
        harness.translator.savesTranscripts = false
        await harness.settle()
        #expect(!harness.translator.transcribesSource)
        setting.shown = true
        await harness.settle()
        #expect(harness.translator.transcribesSource)
    }
}
