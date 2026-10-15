import AppKit
import CoreAudio

enum AudioProcesses {
    static let system = AudioObjectID(kAudioObjectSystemObject)

    /// Core Audio process objects (apps and helpers such as WebKit GPU or Chrome audio service).
    static func list() -> [AudioProcess] {
        let own = getpid()
        let ids = (try? CoreAudioProperty.readObjectList(system, kAudioHardwarePropertyProcessObjectList)) ?? []
        return ids.compactMap { id in
            guard let pid = try? CoreAudioProperty.read(id, kAudioProcessPropertyPID, pid_t(0)), pid != own else { return nil }
            let bundleID = CoreAudioProperty.readString(id, kAudioProcessPropertyBundleID) ?? ""
            let running = ((try? CoreAudioProperty.read(id, kAudioProcessPropertyIsRunningOutput, UInt32(0))) ?? 0) != 0
            let app = NSRunningApplication(processIdentifier: pid)
            let name = app?.localizedName ?? (bundleID.isEmpty ? "pid \(pid)" : bundleID)
            return AudioProcess(id: id, pid: pid, bundleID: bundleID, name: name, isOutputting: running)
        }
        .sorted { ($0.isOutputting ? 0 : 1, $0.name) < ($1.isOutputting ? 0 : 1, $1.name) }
    }

    static func object(for pid: pid_t) -> AudioObjectID? {
        var a = CoreAudioProperty.address(kAudioHardwarePropertyTranslatePIDToProcessObject)
        var pid = pid
        var object = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        let status = AudioObjectGetPropertyData(system, &a, UInt32(MemoryLayout<pid_t>.size), &pid, &size, &object)
        return status == noErr && object != kAudioObjectUnknown ? object : nil
    }

    static func defaultOutputUID() throws -> String {
        let device = try CoreAudioProperty.read(system, kAudioHardwarePropertyDefaultSystemOutputDevice, AudioDeviceID(kAudioObjectUnknown))
        guard let uid = CoreAudioProperty.readString(device, kAudioDevicePropertyDeviceUID) else {
            throw CoreAudioError(status: kAudioHardwareUnknownPropertyError, operation: "default output UID")
        }
        return uid
    }
}
