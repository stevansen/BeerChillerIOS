//
//  AppSettings.swift
//  BeerCHILLER
//
//  User-facing preferences, persisted in the shared store. Storage keys match
//  the Android original where the concept is the same.
//

import Foundation
import SwiftUI

/// Visual style, matching the Android "Classic UI" / "Beer UI" modes.
public enum VisualStyle: Int, CaseIterable, Codable, Sendable {
    case classic = 0
    case beer = 1

    public var titleKey: String {
        switch self {
        case .classic: return "style_classic"
        case .beer: return "style_beer"
        }
    }

    /// SF Symbol for the menu row. Every entry in a menu carries one, or none do.
    public var systemImage: String {
        switch self {
        case .classic: return "circle.lefthalf.filled"
        case .beer: return "drop.fill"
        }
    }
}

/// Light/dark override. `system` follows the device setting.
public enum AppearanceMode: Int, CaseIterable, Codable, Sendable {
    case system = 0
    case light = 1
    case dark = 2

    public var titleKey: String {
        switch self {
        case .system: return "appearance_system"
        case .light: return "appearance_light"
        case .dark: return "appearance_dark"
        }
    }

    public var systemImage: String {
        switch self {
        case .system: return "circle.righthalf.filled"
        case .light: return "sun.max"
        case .dark: return "moon"
        }
    }

    public var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

/// Temperature unit, matching the Android UNIT_SYSTEM/CELSIUS/FAHRENHEIT values.
public enum TemperatureUnit: Int, CaseIterable, Codable, Sendable {
    case system = 0
    case celsius = 1
    case fahrenheit = 2

    public var titleKey: String {
        switch self {
        case .system: return "temperature_unit_system"
        case .celsius: return "temperature_unit_celsius"
        case .fahrenheit: return "temperature_unit_fahrenheit"
        }
    }

    /// Resolves `system` against the current locale's measurement system.
    public var resolved: TemperatureUnit {
        guard self == .system else { return self }
        if Locale.current.measurementSystem == .us {
            return .fahrenheit
        }
        return .celsius
    }
}

/// Observable preference store. All mutations write straight through to the
/// shared defaults so the widget and watch see them immediately.
public final class AppSettings: ObservableObject {

    public static let shared = AppSettings()

    @Published public var startTempC: Int {
        didSet { persist(startTempC, SharedStore.Key.startTemp) }
    }
    @Published public var targetTempC: Int {
        didSet { persist(targetTempC, SharedStore.Key.targetTemp) }
    }
    @Published public var deviceTempC: Int {
        didSet { persist(deviceTempC, SharedStore.Key.deviceTemp) }
    }
    @Published public var deviceMode: DeviceMode {
        didSet {
            persist(deviceMode.rawValue, SharedStore.Key.deviceMode)
            // Follow the appliance default when the user switches appliance, the
            // same way the Android UI does.
            if oldValue != deviceMode {
                deviceTempC = deviceMode.defaultTemperatureC
            }
        }
    }
    @Published public var containerType: ContainerType {
        didSet {
            persist(containerType.rawValue, SharedStore.Key.containerType)
            // A 1.0 l can does not exist — fall back to 0.5 l.
            if containerType == .can, volume == .large {
                volume = .medium
            }
        }
    }
    @Published public var volume: VolumeOption {
        didSet { persist(volume.rawValue, SharedStore.Key.volumeIndex) }
    }
    @Published public var orientation: ContainerOrientation {
        didSet { persist(orientation.rawValue, SharedStore.Key.orientation) }
    }
    @Published public var visualStyle: VisualStyle {
        didSet { persist(visualStyle.rawValue, SharedStore.Key.visualStyle) }
    }
    @Published public var appearance: AppearanceMode {
        didSet { persist(appearance.rawValue, SharedStore.Key.appearance) }
    }
    @Published public var temperatureUnit: TemperatureUnit {
        didSet { persist(temperatureUnit.rawValue, SharedStore.Key.temperatureUnit) }
    }

    private var isLoading = true

    public init() {
        #if DEBUG
        // Has to run before the first read below: this initialiser is what turns
        // the stored defaults into published state, so a style seeded afterwards
        // would not be picked up until something wrote to it again.
        SharedStore.seedFromLaunchArgumentsIfRequested()
        #endif
        startTempC = SharedStore.int(SharedStore.Key.startTemp,
                                     default: CoolingModel.defaultStartTempC,
                                     min: CoolingModel.minStartTempC,
                                     max: CoolingModel.maxStartTempC)
        targetTempC = SharedStore.int(SharedStore.Key.targetTemp,
                                      default: CoolingModel.defaultTargetTempC,
                                      min: CoolingModel.minTargetTempC,
                                      max: CoolingModel.maxTargetTempC)
        deviceTempC = SharedStore.int(SharedStore.Key.deviceTemp,
                                      default: CoolingModel.defaultDeviceTempC,
                                      min: CoolingModel.minDeviceTempC,
                                      max: CoolingModel.maxDeviceTempC)
        deviceMode = SharedStore.enumValue(SharedStore.Key.deviceMode, default: .freezer)
        containerType = SharedStore.enumValue(SharedStore.Key.containerType, default: .bottle)
        volume = SharedStore.enumValue(SharedStore.Key.volumeIndex, default: .small)
        orientation = SharedStore.enumValue(SharedStore.Key.orientation, default: .standing)
        visualStyle = SharedStore.enumValue(SharedStore.Key.visualStyle, default: .classic)
        appearance = SharedStore.enumValue(SharedStore.Key.appearance, default: .system)
        temperatureUnit = SharedStore.enumValue(SharedStore.Key.temperatureUnit, default: .system)
        isLoading = false
    }

    private func persist(_ value: Int, _ key: String) {
        guard !isLoading else { return }
        SharedStore.defaults.set(value, forKey: key)
    }

    // MARK: Derived

    /// `nil` when the current input combination cannot be computed.
    public var solution: CoolingSolution {
        CoolingModel.solve(startTempC: Double(startTempC),
                           targetTempC: Double(targetTempC),
                           deviceTempC: Double(deviceTempC),
                           containerType: containerType,
                           volume: volume,
                           deviceMode: deviceMode,
                           orientation: orientation)
    }

    public var coolingMinutes: Int? {
        CoolingModel.coolingMinutes(for: solution)
    }

    /// True when the selected volume is not offered for the selected container.
    public func isVolumeAvailable(_ option: VolumeOption) -> Bool {
        ContainerPreset.preset(for: containerType, volume: option).isValid
    }

    /// Builds a session for "start now".
    public func makeSession(startingAt date: Date = Date()) -> ChillSession? {
        let solution = self.solution
        guard solution.isValid, solution.seconds > 0 else { return nil }
        return ChillSession(startDate: date,
                            endDate: date.addingTimeInterval(solution.seconds),
                            startTempC: Double(startTempC),
                            targetTempC: Double(targetTempC),
                            deviceTempC: Double(deviceTempC),
                            containerType: containerType,
                            volume: volume,
                            deviceMode: deviceMode,
                            orientation: orientation)
    }

    // MARK: Stepping (clamped, Android parity)

    public func stepStartTemp(_ delta: Int) {
        startTempC = CoolingModel.clamp(startTempC + delta,
                                        CoolingModel.minStartTempC,
                                        CoolingModel.maxStartTempC)
    }

    public func stepTargetTemp(_ delta: Int) {
        targetTempC = CoolingModel.clamp(targetTempC + delta,
                                         CoolingModel.minTargetTempC,
                                         CoolingModel.maxTargetTempC)
    }

    public func stepDeviceTemp(_ delta: Int) {
        deviceTempC = CoolingModel.clamp(deviceTempC + delta,
                                         CoolingModel.minDeviceTempC,
                                         CoolingModel.maxDeviceTempC)
    }
}
