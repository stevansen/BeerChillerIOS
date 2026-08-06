//
//  AlarmTests.swift
//  BeerCHILLERTests
//
//  Covers the alarm the app plays itself. The point of these is that "the alarm
//  screen appears" was already true while the app made no sound at all — the
//  screen was the only thing anyone checked. These assert the audible part.
//

import AVFoundation
import XCTest
@testable import BeerCHILLER

final class AlarmSoundTests: XCTestCase {

    override func tearDown() {
        AlarmSound.shared.stop()
        super.tearDown()
    }

    func testTheAlarmToneIsInTheBundle() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "alarm", withExtension: "wav"),
                                "alarm.wav is missing from the app bundle — the "
                                + "alarm would be silent in the foreground")
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let size = attributes[.size] as? Int ?? 0
        XCTAssertGreaterThan(size, 10_000, "alarm.wav is implausibly small")
    }

    /// A loop whose first and last samples are not near silence clicks audibly on
    /// every repeat. The generator asserts this too; this checks the file that
    /// actually shipped.
    func testTheToneLoopsWithoutAClick() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "alarm", withExtension: "wav"))
        let file = try AVAudioFile(forReading: url)
        let frames = AVAudioFrameCount(file.length)
        XCTAssertGreaterThan(frames, 0)

        let format = file.processingFormat
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format,
                                                    frameCapacity: frames))
        try file.read(into: buffer)
        let channel = try XCTUnwrap(buffer.floatChannelData?[0])
        let count = Int(buffer.frameLength)

        let first = abs(channel[0])
        let last = abs(channel[count - 1])
        XCTAssertLessThan(first, 0.01, "the loop does not start at silence")
        XCTAssertLessThan(last, 0.01, "the loop does not end at silence")

        // And it must not be silence throughout, which would satisfy the above.
        var peak: Float = 0
        for index in 0..<count { peak = max(peak, abs(channel[index])) }
        XCTAssertGreaterThan(peak, 0.5, "the tone is inaudibly quiet")
    }

    func testStartingPlaysAndStoppingStops() {
        AlarmSound.shared.start()
        XCTAssertTrue(AlarmSound.shared.isPlaying,
                      "the alarm tone did not start — the foreground alarm would "
                      + "be silent")

        AlarmSound.shared.stop()
        XCTAssertFalse(AlarmSound.shared.isPlaying,
                       "the alarm kept playing after being stopped")
    }

    func testStartingTwiceDoesNotRestart() {
        AlarmSound.shared.start()
        XCTAssertTrue(AlarmSound.shared.isPlaying)
        // A second call must be a no-op rather than starting a second player,
        // which would double the volume and desynchronise the two loops.
        AlarmSound.shared.start()
        XCTAssertTrue(AlarmSound.shared.isPlaying)
        AlarmSound.shared.stop()
    }
}

final class SystemAlarmTests: XCTestCase {

    /// `cancel` runs on every stop, including when no alarm was ever scheduled and
    /// on versions without AlarmKit. It must not throw or trap.
    func testCancelIsSafeWithoutAnAlarm() {
        SystemAlarm.cancel()
        SystemAlarm.cancel()
    }

    /// Guards the availability floor. AlarmKit needs iOS 26.1 here — see the note
    /// in SystemAlarm about the deprecated 26.0 initialiser.
    func testAvailabilityMatchesTheRuntime() {
        if #available(iOS 26.1, *) {
            XCTAssertTrue(SystemAlarm.isAvailable)
        } else {
            XCTAssertFalse(SystemAlarm.isAvailable,
                           "SystemAlarm claims to be available below iOS 26.1")
        }
    }
}
