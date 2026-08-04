//
//  ChillSession.swift
//  BeerCHILLER
//
//  A running cooling timer, persisted so it survives app termination and reboot.
//
//  The session stores absolute dates, never a countdown counter: everything the
//  UI shows is derived from `startDate`/`endDate` against the current wall clock.
//  That is what makes the timer correct after a relaunch, and it is also what
//  lets the widget and the watch render the same state without talking to the app.
//
//  Unlike the Android original — which re-reads the *current* preference values
//  when it estimates the live beer temperature — the session snapshots the inputs
//  it was started with. Changing a slider mid-run therefore no longer distorts a
//  running estimate. (Documented deviation; see README.)
//

import Foundation

public struct ChillSession: Codable, Equatable, Sendable {
    public var startDate: Date
    public var endDate: Date

    // Snapshot of the inputs this run was computed from.
    public var startTempC: Double
    public var targetTempC: Double
    public var deviceTempC: Double
    public var containerType: ContainerType
    public var volume: VolumeOption
    public var deviceMode: DeviceMode
    public var orientation: ContainerOrientation

    public init(startDate: Date,
                endDate: Date,
                startTempC: Double,
                targetTempC: Double,
                deviceTempC: Double,
                containerType: ContainerType,
                volume: VolumeOption,
                deviceMode: DeviceMode,
                orientation: ContainerOrientation) {
        self.startDate = startDate
        self.endDate = endDate
        self.startTempC = startTempC
        self.targetTempC = targetTempC
        self.deviceTempC = deviceTempC
        self.containerType = containerType
        self.volume = volume
        self.deviceMode = deviceMode
        self.orientation = orientation
    }

    // MARK: Derived values

    public var totalSeconds: Double {
        max(0, endDate.timeIntervalSince(startDate))
    }

    public func remainingSeconds(at date: Date = Date()) -> Double {
        max(0, endDate.timeIntervalSince(date))
    }

    public func elapsedSeconds(at date: Date = Date()) -> Double {
        min(max(0, date.timeIntervalSince(startDate)), totalSeconds)
    }

    /// 0…1 progress through the run.
    public func progress(at date: Date = Date()) -> Double {
        guard totalSeconds > 0 else { return 1 }
        return min(max(elapsedSeconds(at: date) / totalSeconds, 0), 1)
    }

    public func isFinished(at date: Date = Date()) -> Bool {
        date >= endDate
    }

    /// The solution this run was computed from, recreated on demand.
    public var solution: CoolingSolution {
        CoolingModel.solve(startTempC: startTempC,
                           targetTempC: targetTempC,
                           deviceTempC: deviceTempC,
                           containerType: containerType,
                           volume: volume,
                           deviceMode: deviceMode,
                           orientation: orientation)
    }

    /// Estimated beer temperature right now, in °C.
    public func currentTemperatureC(at date: Date = Date()) -> Double {
        CoolingModel.currentTemperatureC(solution: solution,
                                        progress: progress(at: date),
                                        startTempC: startTempC,
                                        targetTempC: targetTempC,
                                        deviceTempC: deviceTempC)
    }
}
