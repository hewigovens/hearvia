#if !targetEnvironment(simulator) // The Simulator SDK has no ScreenCaptureKit.
    import ScreenCaptureKit

    extension AudioProbe: SCStreamOutput {
        func bind(_ stream: SCStream) async {
            await bind(ObjectIdentifier(stream))
        }

        func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
            switch type {
            case .audio: receive(sampleBuffer, from: .system, stream: ObjectIdentifier(stream))
            case .microphone: receive(sampleBuffer, from: .microphone, stream: ObjectIdentifier(stream))
            default: break // Screen frames are intentionally discarded.
            }
        }
    }
#endif
