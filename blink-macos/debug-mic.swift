#!/usr/bin/env swift
// Run: swift debug-mic.swift
// Shows all audio devices, their input/output streams, and active status.
// Use this to debug why mic detection reports false positives.

import CoreAudio
import Foundation

func getDeviceName(_ deviceID: AudioDeviceID) -> String {
    var nameSize: UInt32 = 256
    var nameAddr = AudioObjectPropertyAddress(
        mSelector: kAudioObjectPropertyName,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    var name: CFString = "" as CFString
    AudioObjectGetPropertyData(deviceID, &nameAddr, 0, nil, &nameSize, &name)
    return name as String
}

func getStreamCount(_ deviceID: AudioDeviceID, scope: AudioObjectPropertyScope) -> Int {
    var addr = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyStreams,
        mScope: scope,
        mElement: kAudioObjectPropertyElementMain
    )
    var size: UInt32 = 0
    AudioObjectGetPropertyDataSize(deviceID, &addr, 0, nil, &size)
    return Int(size) / MemoryLayout<AudioStreamID>.size
}

func isDeviceRunning(_ deviceID: AudioDeviceID) -> Bool {
    var isRunning: UInt32 = 0
    var size = UInt32(MemoryLayout<UInt32>.size)
    var addr = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    let err = AudioObjectGetPropertyData(deviceID, &addr, 0, nil, &size, &isRunning)
    return err == noErr && isRunning != 0
}

func getActiveInputStreams(_ deviceID: AudioDeviceID) -> [AudioStreamID] {
    var streamAddr = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyStreams,
        mScope: kAudioDevicePropertyScopeInput,
        mElement: kAudioObjectPropertyElementMain
    )
    var streamSize: UInt32 = 0
    guard AudioObjectGetPropertyDataSize(deviceID, &streamAddr, 0, nil, &streamSize) == noErr,
          streamSize > 0 else { return [] }

    let count = Int(streamSize) / MemoryLayout<AudioStreamID>.size
    var streams = [AudioStreamID](repeating: 0, count: count)
    guard AudioObjectGetPropertyData(deviceID, &streamAddr, 0, nil, &streamSize, &streams) == noErr else { return [] }

    return streams.filter { stream in
        var isActive: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        var activeAddr = AudioObjectPropertyAddress(
            mSelector: kAudioStreamPropertyIsActive,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        return AudioObjectGetPropertyData(stream, &activeAddr, 0, nil, &size, &isActive) == noErr && isActive != 0
    }
}

// Get all devices
var devicesSize: UInt32 = 0
var devicesAddr = AudioObjectPropertyAddress(
    mSelector: kAudioHardwarePropertyDevices,
    mScope: kAudioObjectPropertyScopeGlobal,
    mElement: kAudioObjectPropertyElementMain
)
AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &devicesAddr, 0, nil, &devicesSize)
let deviceCount = Int(devicesSize) / MemoryLayout<AudioDeviceID>.size
var devices = [AudioDeviceID](repeating: 0, count: deviceCount)
AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &devicesAddr, 0, nil, &devicesSize, &devices)

print("=== Audio Device Report ===\n")

for device in devices {
    let name = getDeviceName(device)
    let inputStreams = getStreamCount(device, scope: kAudioDevicePropertyScopeInput)
    let outputStreams = getStreamCount(device, scope: kAudioDevicePropertyScopeOutput)
    let running = isDeviceRunning(device)
    let inputOnly = inputStreams > 0 && outputStreams == 0
    let activeInputs = getActiveInputStreams(device)

    let marker = running ? "🔴 RUNNING" : "⚪ idle"
    print("Device \(device): \(name)")
    print("  Input streams: \(inputStreams), Output streams: \(outputStreams)")
    print("  Input-only: \(inputOnly)")
    print("  DeviceIsRunningSomewhere: \(marker)")
    if inputStreams > 0 {
        print("  Active input streams: \(activeInputs.isEmpty ? "none" : activeInputs.map(String.init).joined(separator: ", "))")
    }
    print()
}

// Summary
print("=== Blink would detect mic as: ", terminator: "")
let micActive = devices.contains { device in
    let inputStreams = getStreamCount(device, scope: kAudioDevicePropertyScopeInput)
    let outputStreams = getStreamCount(device, scope: kAudioDevicePropertyScopeOutput)
    guard inputStreams > 0 else { return false }

    if outputStreams == 0 {
        // Input-only: trust DeviceIsRunningSomewhere
        return isDeviceRunning(device)
    } else {
        // Combo: check input stream IsActive
        return !getActiveInputStreams(device).isEmpty
    }
}
print(micActive ? "🔴 ACTIVE" : "⚪ INACTIVE")
print()

// Loop mode
if CommandLine.arguments.contains("--watch") {
    print("Watching for changes (Ctrl+C to stop)...\n")
    while true {
        Thread.sleep(forTimeInterval: 2.0)
        let active = devices.contains { device in
            let inputStreams = getStreamCount(device, scope: kAudioDevicePropertyScopeInput)
            let outputStreams = getStreamCount(device, scope: kAudioDevicePropertyScopeOutput)
            guard inputStreams > 0 else { return false }
            if outputStreams == 0 { return isDeviceRunning(device) }
            return !getActiveInputStreams(device).isEmpty
        }
        let ts = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        print("[\(ts)] Mic: \(active ? "🔴 ACTIVE" : "⚪ inactive")")
    }
}
