import AVFoundation
import AppKit
import CoreAudio

struct AudioProcess: Identifiable, Hashable, Sendable {
    let id: AudioObjectID
    let pid: pid_t
    let bundleID: String
    let name: String
    let isOutputting: Bool
}

struct CoreAudioError: LocalizedError {
    let status: OSStatus
    let operation: String
    var errorDescription: String? { "\(operation) failed (OSStatus \(status))" }
}

private func check(_ status: OSStatus, _ operation: String) throws {
    guard status == noErr else { throw CoreAudioError(status: status, operation: operation) }
}

private func address(_ selector: AudioObjectPropertySelector) -> AudioObjectPropertyAddress {
    AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
}

private func read<T>(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector, _ initial: T) throws -> T {
    var a = address(selector)
    var size = UInt32(MemoryLayout<T>.size)
    var value = initial
    try check(AudioObjectGetPropertyData(object, &a, 0, nil, &size, &value), "read \(selector)")
    return value
}

private func readString(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector) -> String? {
    guard let value = (try? read(object, selector, Unmanaged<CFString>?.none)) ?? nil else { return nil }
    return value.takeRetainedValue() as String
}

private func readObjectList(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector) throws -> [AudioObjectID] {
    var a = address(selector)
    var size: UInt32 = 0
    try check(AudioObjectGetPropertyDataSize(object, &a, 0, nil, &size), "size \(selector)")
    var ids = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
    try check(AudioObjectGetPropertyData(object, &a, 0, nil, &size, &ids), "read \(selector)")
    return ids
}

enum AudioProcesses {
    static let system = AudioObjectID(kAudioObjectSystemObject)

    /// Core Audio process objects (apps and helpers such as WebKit GPU or Chrome audio service).
    static func list() -> [AudioProcess] {
        let own = getpid()
        let ids = (try? readObjectList(system, kAudioHardwarePropertyProcessObjectList)) ?? []
        return ids.compactMap { id in
            guard let pid = try? read(id, kAudioProcessPropertyPID, pid_t(0)), pid != own else { return nil }
            let bundleID = readString(id, kAudioProcessPropertyBundleID) ?? ""
            let running = ((try? read(id, kAudioProcessPropertyIsRunningOutput, UInt32(0))) ?? 0) != 0
            let app = NSRunningApplication(processIdentifier: pid)
            let name = app?.localizedName ?? (bundleID.isEmpty ? "pid \(pid)" : bundleID)
            return AudioProcess(id: id, pid: pid, bundleID: bundleID, name: name, isOutputting: running)
        }
        .sorted { ($0.isOutputting ? 0 : 1, $0.name) < ($1.isOutputting ? 0 : 1, $1.name) }
    }

    static func object(for pid: pid_t) -> AudioObjectID? {
        var a = address(kAudioHardwarePropertyTranslatePIDToProcessObject)
        var pid = pid
        var object = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        let status = AudioObjectGetPropertyData(system, &a, UInt32(MemoryLayout<pid_t>.size), &pid, &size, &object)
        return status == noErr && object != kAudioObjectUnknown ? object : nil
    }

    static func defaultOutputUID() throws -> String {
        let device = try read(system, kAudioHardwarePropertyDefaultSystemOutputDevice, AudioDeviceID(kAudioObjectUnknown))
        guard let uid = readString(device, kAudioDevicePropertyDeviceUID) else {
            throw CoreAudioError(status: kAudioHardwareUnknownPropertyError, operation: "default output UID")
        }
        return uid
    }
}

/// Captures other apps' output with a Core Audio process tap (macOS 14.2+), read
/// through a private aggregate device. Needs NSAudioCaptureUsageDescription; the
/// first start shows the system "audio recording" permission prompt.
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
            let description: CATapDescription
            if let processes {
                description = CATapDescription(stereoMixdownOfProcesses: processes)
            } else {
                description = CATapDescription(stereoGlobalTapButExcludeProcesses: AudioProcesses.object(for: getpid()).map { [$0] } ?? [])
            }
            description.uuid = UUID()
            description.name = "Hearvia"
            description.isPrivate = true
            description.muteBehavior = .unmuted
            try check(AudioHardwareCreateProcessTap(description, &tapID), "create process tap")

            var asbd = try read(tapID, kAudioTapPropertyFormat, AudioStreamBasicDescription())
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
                                                   kAudioSubTapUIDKey: description.uuid.uuidString]],
            ]
            try check(AudioHardwareCreateAggregateDevice(aggregate as CFDictionary, &aggregateID), "create aggregate device")
            try check(AudioDeviceCreateIOProcIDWithBlock(&procID, aggregateID, queue) { _, input, _, _, _ in
                // No copy: the consumer converts synchronously inside this callback.
                guard let buffer = AVAudioPCMBuffer(pcmFormat: format, bufferListNoCopy: input, deallocator: nil) else { return }
                onBuffer(buffer)
            }, "create IO proc")
            try check(AudioDeviceStart(aggregateID, procID), "start aggregate device")
        } catch {
            stop(); throw error
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
        if tapID != kAudioObjectUnknown { AudioHardwareDestroyProcessTap(tapID) }
        procID = nil; aggregateID = AudioObjectID(kAudioObjectUnknown); tapID = AudioObjectID(kAudioObjectUnknown)
    }

    deinit { stop() }
}
