//
//  ChillActivityAttributes.swift
//  BeerCHILLER
//
//  Live Activity payload, shared between the app (which starts and updates the
//  activity) and the widget extension (which renders it).
//
//  ActivityKit requires iOS 16.1; the app's deployment target is 16.0, so every
//  use of this type is behind an availability check.
//

#if canImport(ActivityKit)
import ActivityKit
import Foundation

@available(iOS 16.1, *)
public struct ChillActivityAttributes: ActivityAttributes {

    /// Values that change while the timer runs.
    public struct ContentState: Codable, Hashable {
        /// Estimated beer temperature in °C at the moment of the update.
        public var currentTemperatureC: Double

        public init(currentTemperatureC: Double) {
            self.currentTemperatureC = currentTemperatureC
        }
    }

    // Fixed for the lifetime of the activity.
    public var startDate: Date
    public var endDate: Date
    public var startTempC: Double
    public var targetTempC: Double
    public var deviceTempC: Double
    public var containerTypeRaw: Int
    public var volumeRaw: Int
    public var deviceModeRaw: Int
    public var orientationRaw: Int

    public init(session: ChillSession) {
        startDate = session.startDate
        endDate = session.endDate
        startTempC = session.startTempC
        targetTempC = session.targetTempC
        deviceTempC = session.deviceTempC
        containerTypeRaw = session.containerType.rawValue
        volumeRaw = session.volume.rawValue
        deviceModeRaw = session.deviceMode.rawValue
        orientationRaw = session.orientation.rawValue
    }

    /// Rebuilds the session so the Live Activity view can use the same helpers
    /// as the rest of the app.
    public var session: ChillSession {
        ChillSession(startDate: startDate,
                     endDate: endDate,
                     startTempC: startTempC,
                     targetTempC: targetTempC,
                     deviceTempC: deviceTempC,
                     containerType: ContainerType(rawValue: containerTypeRaw) ?? .bottle,
                     volume: VolumeOption(rawValue: volumeRaw) ?? .small,
                     deviceMode: DeviceMode(rawValue: deviceModeRaw) ?? .freezer,
                     orientation: ContainerOrientation(rawValue: orientationRaw) ?? .standing)
    }
}
#endif
