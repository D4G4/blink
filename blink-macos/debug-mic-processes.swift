#!/usr/bin/env swift
// Run: swift debug-mic-processes.swift
// Lists all audio processes registered with CoreAudio and their PIDs.

import CoreAudio
import Foundation

// kAudioHardwarePropertyProcessObjectList = 'hao#' = 0x68616F23
let kProcessObjectList: AudioObjectPropertySelector = 0x68616F23
// kAudioProcessPropertyPID = 'ppid' = 0x70706964
let kProcessPID: AudioObjectPropertySelector = 0x70706964
// kAudioProcessPropertyBundleID = 'pbid' = 0x70626964
let kProcessBundleID: AudioObjectPropertySelector = 0x70626964

func getAudioProcesses() {
    var addr = AudioObjectPropertyAddress(
        mSelector: kProcessObjectList,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )

    var size: UInt32 = 0
    let err = AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size)
    guard err == noErr else {
        print("Failed to get process list size: \(err)")
        print("(This API requires macOS 14+)")
        return
    }

    let count = Int(size) / MemoryLayout<AudioObjectID>.size
    guard count > 0 else {
        print("No audio processes found")
        return
    }

    var processes = [AudioObjectID](repeating: 0, count: count)
    let err2 = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &processes)
    guard err2 == noErr else {
        print("Failed to get process list: \(err2)")
        return
    }

    print("=== Audio Processes (\(count)) ===\n")

    for proc in processes {
        // Get PID
        var pid: pid_t = 0
        var pidSize = UInt32(MemoryLayout<pid_t>.size)
        var pidAddr = AudioObjectPropertyAddress(
            mSelector: kProcessPID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let pidErr = AudioObjectGetPropertyData(proc, &pidAddr, 0, nil, &pidSize, &pid)

        // Get Bundle ID
        var bundleID: CFString = "" as CFString
        var bundleSize: UInt32 = 256
        var bundleAddr = AudioObjectPropertyAddress(
            mSelector: kProcessBundleID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let bundleErr = AudioObjectGetPropertyData(proc, &bundleAddr, 0, nil, &bundleSize, &bundleID)

        let pidStr = pidErr == noErr ? "\(pid)" : "?"
        let bundleStr = bundleErr == noErr ? (bundleID as String) : "?"

        // Get process name from PID
        var processName = "?"
        if pidErr == noErr && pid > 0 {
            let task = Process()
            task.launchPath = "/bin/ps"
            task.arguments = ["-p", "\(pid)", "-o", "comm="]
            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = FileHandle.nullDevice
            try? task.run()
            task.waitUntilExit()
            if let data = try? pipe.fileHandleForReading.readToEnd(),
               let name = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
                processName = name
            }
        }

        print("  AudioObject \(proc): PID=\(pidStr) bundle=\(bundleStr) name=\(processName)")
    }
}

print("Running on macOS \(ProcessInfo.processInfo.operatingSystemVersion.majorVersion).\(ProcessInfo.processInfo.operatingSystemVersion.minorVersion)\n")
getAudioProcesses()

if CommandLine.arguments.contains("--watch") {
    print("\nWatching (Ctrl+C to stop)...\n")
    var lastCount = 0
    while true {
        Thread.sleep(forTimeInterval: 2.0)
        var addr = AudioObjectPropertyAddress(
            mSelector: kProcessObjectList,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size)
        let count = Int(size) / MemoryLayout<AudioObjectID>.size
        if count != lastCount {
            let ts = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
            print("[\(ts)] Audio process count changed: \(lastCount) → \(count)")
            getAudioProcesses()
            lastCount = count
        }
    }
}
