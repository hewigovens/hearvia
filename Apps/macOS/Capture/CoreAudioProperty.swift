import CoreAudio

enum CoreAudioProperty {
    static func check(_ status: OSStatus, _ operation: String) throws {
        guard status == noErr else { throw CoreAudioError(status: status, operation: operation) }
    }

    static func address(_ selector: AudioObjectPropertySelector) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
    }

    static func read<T>(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector, _ initial: T) throws -> T {
        var a = address(selector)
        var size = UInt32(MemoryLayout<T>.size)
        var value = initial
        try check(AudioObjectGetPropertyData(object, &a, 0, nil, &size, &value), "read \(selector)")
        return value
    }

    static func readString(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector) -> String? {
        guard let value = (try? read(object, selector, Unmanaged<CFString>?.none)) ?? nil else { return nil }
        return value.takeRetainedValue() as String
    }

    static func readObjectList(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector) throws -> [AudioObjectID] {
        var a = address(selector)
        var size: UInt32 = 0
        try check(AudioObjectGetPropertyDataSize(object, &a, 0, nil, &size), "size \(selector)")
        var ids = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        try check(AudioObjectGetPropertyData(object, &a, 0, nil, &size, &ids), "read \(selector)")
        return ids
    }
}
