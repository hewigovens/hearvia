import AVFoundation
import CoreAudio

/// Captures other apps' output with a Core Audio process tap read through a private aggregate device.
/// The first start shows the system "audio recording" permission prompt.
final class ProcessTapCapture: @unchecked Sendable {
    private let queue = DispatchQueue(label: "dev.hewig.Hearvia.tap", qos: .userInitiated)
    private var tapID = AudioObjectID(kAudioObjectUnknown)
    private var aggregateID = AudioObjectID(kAudioObjectUnknown)
    private var procID: AudioDeviceIOProcID?
    private(set) var format: AVAudioFormat?

    /// `processes == nil` taps everything except this app.
    func start(processes: [AudioObjectID]?, onBuffer: @escaping @Sendable (AVAudioPCMBuffer) -> Void) throws {
        stop()
        do {
            let description = if let processes {
                CATapDescription(stereoMixdownOfProcesses: processes)
            } else {
                CATapDescription(stereoGlobalTapButExcludeProcesses: AudioProcesses.object(for: getpid()).map { [$0] } ?? [])
            }
            description.uuid = UUID()
            description.name = "Hearvia"
            description.isPrivate = true
            description.muteBehavior = .unmuted
            try CoreAudioProperty.check(AudioHardwareCreateProcessTap(description, &tapID), "create process tap")

            var asbd = try CoreAudioProperty.read(tapID, kAudioTapPropertyFormat, AudioStreamBasicDescription())
            guard let format = AVAudioFormat(streamDescription: &asbd) else {
                throw CoreAudioError(status: kAudioHardwareBadStreamError, operation: "tap format")
            }
            self.format = format

            let outputUID = try AudioProcesses.defaultOutputUID()
            let aggregate: [String: Any] = [
                kAudioAggregateDeviceNameKey: "Hearvia Tap",
                kAudioAggregateDeviceUIDKey: UUID().uuidString,
                kAudioAggregateDeviceMainSubDeviceKey: outputUID,
                kAudioAggregateDeviceIsPrivateKey: true,
                kAudioAggregateDeviceIsStackedKey: false,
                kAudioAggregateDeviceTapAutoStartKey: true,
                kAudioAggregateDeviceSubDeviceListKey: [[kAudioSubDeviceUIDKey: outputUID]],
                kAudioAggregateDeviceTapListKey: [[kAudioSubTapDriftCompensationKey: true,
                                                   kAudioSubTapUIDKey: description.uuid.uuidString]]
            ]
            try CoreAudioProperty.check(AudioHardwareCreateAggregateDevice(aggregate as CFDictionary, &aggregateID), "create aggregate device")
            try CoreAudioProperty.check(AudioDeviceCreateIOProcIDWithBlock(&procID, aggregateID, queue) { _, input, _, _, _ in
                // No copy: the consumer converts synchronously inside this callback.
                guard let buffer = AVAudioPCMBuffer(pcmFormat: format, bufferListNoCopy: input, deallocator: nil) else { return }
                onBuffer(buffer)
            }, "create IO proc")
            try CoreAudioProperty.check(AudioDeviceStart(aggregateID, procID), "start aggregate device")
        } catch {
            stop()
            throw error
        }
    }

    func stop() {
        if aggregateID != kAudioObjectUnknown {
            if let procID {
                AudioDeviceStop(aggregateID, procID)
                AudioDeviceDestroyIOProcID(aggregateID, procID)
            }
            AudioHardwareDestroyAggregateDevice(aggregateID)
        }
        if tapID != kAudioObjectUnknown {
            AudioHardwareDestroyProcessTap(tapID)
        }
        procID = nil
        aggregateID = AudioObjectID(kAudioObjectUnknown)
        tapID = AudioObjectID(kAudioObjectUnknown)
    }

    deinit { stop() }
}
