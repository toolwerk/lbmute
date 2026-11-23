// lbmute — read and set the input mute of an audio device from the command line.
//
// Virtual devices (for example from Loopback by Rogue Amoeba) expose a Core Audio
// mute control on their input side. Setting it makes that one device deliver
// silence while the physical microphone behind it keeps working for everyone else.
//
// Usage:
//   lbmute list
//   lbmute <device> get
//   lbmute <device> set 0|1
//   lbmute <device> toggle
//
// <device> is the exact device name or any part of its UID.
// get / set / toggle print the resulting mute state: 1 = muted, 0 = audible.

import CoreAudio
import Foundation

let usage = """
usage: lbmute list
       lbmute <device> get
       lbmute <device> set 0|1
       lbmute <device> toggle
"""

func fail(_ message: String, code: Int32 = 1) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(code)
}

func address(
    _ selector: AudioObjectPropertySelector,
    scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal
) -> AudioObjectPropertyAddress {
    AudioObjectPropertyAddress(
        mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
}

func stringProperty(_ device: AudioObjectID, _ selector: AudioObjectPropertySelector) -> String? {
    var addr = address(selector)
    var value: Unmanaged<CFString>?
    var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
    guard AudioObjectGetPropertyData(device, &addr, 0, nil, &size, &value) == noErr,
        let string = value
    else { return nil }
    return string.takeRetainedValue() as String
}

func allDevices() -> [AudioObjectID] {
    var addr = address(kAudioHardwarePropertyDevices)
    let system = AudioObjectID(kAudioObjectSystemObject)
    var size: UInt32 = 0
    guard AudioObjectGetPropertyDataSize(system, &addr, 0, nil, &size) == noErr else { return [] }
    var ids = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
    guard AudioObjectGetPropertyData(system, &addr, 0, nil, &size, &ids) == noErr else { return [] }
    return ids
}

var muteAddress = address(kAudioDevicePropertyMute, scope: kAudioObjectPropertyScopeInput)

func hasMute(_ device: AudioObjectID) -> Bool {
    AudioObjectHasProperty(device, &muteAddress)
}

func readMute(_ device: AudioObjectID) -> UInt32 {
    var value: UInt32 = 0
    var size = UInt32(MemoryLayout<UInt32>.size)
    AudioObjectGetPropertyData(device, &muteAddress, 0, nil, &size, &value)
    return value
}

func writeMute(_ device: AudioObjectID, _ value: UInt32) -> Bool {
    var value = value
    return AudioObjectSetPropertyData(
        device, &muteAddress, 0, nil, UInt32(MemoryLayout<UInt32>.size), &value) == noErr
}

let args = CommandLine.arguments
guard args.count >= 2 else { fail(usage, code: 2) }

if args[1] == "list" {
    for device in allDevices() {
        let name = stringProperty(device, kAudioObjectPropertyName) ?? "?"
        let uid = stringProperty(device, kAudioDevicePropertyDeviceUID) ?? "?"
        let mute = hasMute(device) ? String(readMute(device)) : "-"
        print("\(name) | \(uid) | inputMute:\(mute)")
    }
    exit(0)
}

guard args.count >= 3 else { fail(usage, code: 2) }
let query = args[1]
guard
    let device = allDevices().first(where: {
        (stringProperty($0, kAudioDevicePropertyDeviceUID) ?? "").contains(query)
            || stringProperty($0, kAudioObjectPropertyName) == query
    })
else { fail("device not found: \(query)") }
guard hasMute(device) else { fail("device has no input mute control: \(query)") }

switch args[2] {
case "get":
    break
case "set":
    guard args.count >= 4, let value = UInt32(args[3]), value <= 1 else { fail(usage, code: 2) }
    guard writeMute(device, value) else { fail("could not set mute") }
case "toggle":
    guard writeMute(device, readMute(device) == 0 ? 1 : 0) else { fail("could not set mute") }
default:
    fail(usage, code: 2)
}
print(readMute(device))
