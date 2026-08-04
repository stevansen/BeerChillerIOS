//
//  CoolingModel.swift
//  BeerCHILLER
//
//  1:1 port of the "BeerChiller Calibrated V2" cooling model from the Android
//  original (app/src/main/java/com/bierchiller/app/MainActivity.java).
//
//  The drink and its container are treated as one lumped cooling system; the
//  fridge/freezer air is a constant-temperature reservoir. Cooling slows as the
//  beer approaches device temperature, modelled with an empirical convection
//  exponent n = 0.15.
//
//      Δ₀ = T₀ − T_D                       starting temperature difference
//      θ  = (T_Z − T_D) / (T₀ − T_D)       dimensionless target ratio
//
//      t = τ₀ · f_D · f_P · (25/Δ₀)^n · f_cold · ((θ^−n − 1) / n)
//
//      θ(t) = (1 + n · t/τ_eff)^(−1/n)     progress curve for live temperature
//      T(t) = T_D + (T₀ − T_D) · θ(t)
//
//  NOTE ON THE REPOSITORY README: the README documents the formula without the
//  f_cold term. The shipped Java implementation *does* apply it
//  (MainActivity.coldBottleFreezerStartFactor, line 1664 ff.) and the unit test
//  `coldBottleFreezerStartAt16CTo12CUsesCorrection` pins it. The implementation
//  is authoritative here, so f_cold is ported. See `coldStartFactor(...)`.
//

import Foundation

// MARK: - Domain enums

/// Container material/shape. Raw values match the Android constants so
/// persisted preferences stay compatible.
public enum ContainerType: Int, CaseIterable, Codable, Sendable {
    case bottle = 0
    case can = 1
}

/// Appliance the drink is placed in.
public enum DeviceMode: Int, CaseIterable, Codable, Sendable {
    case freezer = 0
    case fridge = 1

    /// Default appliance air temperature in °C, per the Android original.
    public var defaultTemperatureC: Int {
        switch self {
        case .freezer: return CoolingModel.freezerTemperatureC
        case .fridge: return CoolingModel.fridgeTemperatureC
        }
    }
}

/// How the container sits in the appliance.
public enum ContainerOrientation: Int, CaseIterable, Codable, Sendable {
    case lying = 0
    case standing = 1
}

/// Volume slot. `large` (1.0 l) exists for bottles only.
public enum VolumeOption: Int, CaseIterable, Codable, Sendable {
    case small = 0   // 0.33 l
    case medium = 1  // 0.5 l
    case large = 2   // 1.0 l

    public var liters: Double {
        switch self {
        case .small: return 0.33
        case .medium: return 0.5
        case .large: return 1.0
        }
    }
}

// MARK: - Container presets

/// Calibrated per-container constants. `baseTauMinutes` (τ₀) is the calibrated
/// base time; the geometric/thermal fields are carried over from the Android
/// preset table for documentation and validity checking.
public struct ContainerPreset: Equatable, Sendable {
    public let containerType: ContainerType
    public let volumeLiters: Double
    public let baseTauMinutes: Double
    public let beerMassKg: Double
    public let containerMassKg: Double
    public let containerHeatCapacity: Double
    public let diameterMeters: Double
    public let lengthMeters: Double
    public let includeEndFaces: Bool

    public var isValid: Bool {
        volumeLiters > 0
            && baseTauMinutes > 0
            && beerMassKg > 0
            && containerMassKg > 0
            && containerHeatCapacity > 0
            && diameterMeters > 0
            && lengthMeters > 0
    }

    /// The 0.33 l glass bottle the model was calibrated against (214 g glass).
    public static let referenceBottle = ContainerPreset(
        containerType: .bottle, volumeLiters: 0.33, baseTauMinutes: 87,
        beerMassKg: 0.33, containerMassKg: 0.214, containerHeatCapacity: 840,
        diameterMeters: 0.061, lengthMeters: 0.235, includeEndFaces: false
    )

    static let invalid = ContainerPreset(
        containerType: .bottle, volumeLiters: 0, baseTauMinutes: 0,
        beerMassKg: 0, containerMassKg: 0, containerHeatCapacity: 0,
        diameterMeters: 0, lengthMeters: 0, includeEndFaces: false
    )

    /// Mirrors `MainActivity.containerPresetFor`. A 1.0 l can has no preset and
    /// is reported invalid.
    public static func preset(for type: ContainerType, volume: VolumeOption) -> ContainerPreset {
        switch type {
        case .can:
            switch volume {
            case .small:
                return ContainerPreset(
                    containerType: .can, volumeLiters: 0.33, baseTauMinutes: 85,
                    beerMassKg: 0.33, containerMassKg: 0.015, containerHeatCapacity: 900,
                    diameterMeters: 0.066, lengthMeters: 0.115, includeEndFaces: true
                )
            case .medium:
                return ContainerPreset(
                    containerType: .can, volumeLiters: 0.5, baseTauMinutes: 105,
                    beerMassKg: 0.5, containerMassKg: 0.018, containerHeatCapacity: 900,
                    diameterMeters: 0.066, lengthMeters: 0.168, includeEndFaces: true
                )
            case .large:
                return .invalid
            }
        case .bottle:
            switch volume {
            case .small:
                return .referenceBottle
            case .medium:
                return ContainerPreset(
                    containerType: .bottle, volumeLiters: 0.5, baseTauMinutes: 110,
                    beerMassKg: 0.5, containerMassKg: 0.3, containerHeatCapacity: 840,
                    diameterMeters: 0.07, lengthMeters: 0.21, includeEndFaces: false
                )
            case .large:
                return ContainerPreset(
                    containerType: .bottle, volumeLiters: 1.0, baseTauMinutes: 155,
                    beerMassKg: 1.0, containerMassKg: 0.65, containerHeatCapacity: 840,
                    diameterMeters: 0.085, lengthMeters: 0.29, includeEndFaces: false
                )
            }
        }
    }
}

// MARK: - Solution

/// Result of one model evaluation.
public struct CoolingSolution: Equatable, Sendable {
    /// `false` when the inputs cannot produce a cooling curve (e.g. target at or
    /// below device temperature, or an unsupported container).
    public let isValid: Bool
    /// Total cooling time in seconds. `0` means "already cold enough".
    public let seconds: Double
    /// θ at the target temperature.
    public let thetaTarget: Double

    static let invalid = CoolingSolution(isValid: false, seconds: 0, thetaTarget: 0)
}

// MARK: - The model

public enum CoolingModel {

    // Empirical constants — identical to the Android original.

    /// Convection exponent `n`.
    public static let convectionExponent = 0.15
    /// Reference temperature difference for the Δ-correction, in K.
    public static let deltaReferenceC = 25.0

    static let deviceFactorFridge = 1.0
    static let deviceFactorFreezer = 0.84

    static let bottlePositionFactorStanding = 1.0
    static let bottlePositionFactorLying = 0.95
    static let canPositionFactorStanding = 1.0
    static let canPositionFactorLying = 0.92

    /// Below this start temperature the freezer cold-start correction is fully
    /// applied; above `coldStartNoCorrectionC` it is not applied at all.
    static let coldStartFullCorrectionC = 16.0
    static let coldStartNoCorrectionC = 24.0
    static let coldStartMaxExtraFactor = 0.70

    // Appliance defaults and input bounds (Android parity).

    public static let freezerTemperatureC = -18
    public static let fridgeTemperatureC = 4

    public static let defaultStartTempC = 22
    public static let defaultTargetTempC = 8
    public static let defaultDeviceTempC = freezerTemperatureC

    public static let minStartTempC = -5
    public static let maxStartTempC = 40
    public static let minTargetTempC = -5
    public static let maxTargetTempC = 20
    public static let minDeviceTempC = -30
    public static let maxDeviceTempC = 5

    // MARK: Factors

    /// f_D — appliance factor.
    public static func deviceFactor(for mode: DeviceMode) -> Double {
        mode == .freezer ? deviceFactorFreezer : deviceFactorFridge
    }

    /// f_P — container position factor. Cans gain more from lying flat than
    /// bottles do, because more of the wall touches cold air.
    public static func positionFactor(for type: ContainerType,
                                      orientation: ContainerOrientation) -> Double {
        switch type {
        case .can:
            return orientation == .lying ? canPositionFactorLying : canPositionFactorStanding
        case .bottle:
            return orientation == .lying ? bottlePositionFactorLying : bottlePositionFactorStanding
        }
    }

    /// f_cold — empirical correction for bottles that start out already cool in
    /// a freezer, where the calibrated curve otherwise finishes too early.
    /// Ramps smoothly (smoothstep) from 1.0 at 24 °C to 1.70 at 16 °C and below.
    /// Applies to bottles in the freezer only.
    public static func coldStartFactor(containerType: ContainerType,
                                       deviceMode: DeviceMode,
                                       startTempC: Double) -> Double {
        guard containerType == .bottle, deviceMode == .freezer else { return 1.0 }
        let x = (coldStartNoCorrectionC - startTempC)
            / (coldStartNoCorrectionC - coldStartFullCorrectionC)
        return 1.0 + coldStartMaxExtraFactor * smoothstep01(x)
    }

    private static func smoothstep01(_ value: Double) -> Double {
        let x = min(max(value, 0.0), 1.0)
        return x * x * (3.0 - 2.0 * x)
    }

    // MARK: Solve

    /// Evaluates the cooling curve. Mirrors
    /// `MainActivity.calculateCoolingModelSeconds`.
    public static func solve(startTempC: Double,
                             targetTempC: Double,
                             deviceTempC: Double,
                             preset: ContainerPreset,
                             deviceMode: DeviceMode,
                             orientation: ContainerOrientation) -> CoolingSolution {
        guard deviceTempC > -273.15, targetTempC > deviceTempC, preset.isValid else {
            return .invalid
        }
        // Already at or below the target: nothing to wait for.
        if targetTempC >= startTempC {
            return CoolingSolution(isValid: true, seconds: 0, thetaTarget: 1)
        }

        let delta0 = startTempC - deviceTempC
        guard delta0.isFinite, delta0 > 0 else { return .invalid }

        let thetaTarget = (targetTempC - deviceTempC) / delta0
        guard thetaTarget.isFinite, thetaTarget > 0, thetaTarget < 1 else { return .invalid }

        let deltaCorrection = pow(deltaReferenceC / delta0, convectionExponent)
        let temperatureTerm = (pow(thetaTarget, -convectionExponent) - 1.0) / convectionExponent
        let coldStart = coldStartFactor(containerType: preset.containerType,
                                        deviceMode: deviceMode,
                                        startTempC: startTempC)

        let minutes = preset.baseTauMinutes
            * deviceFactor(for: deviceMode)
            * positionFactor(for: preset.containerType, orientation: orientation)
            * deltaCorrection
            * coldStart
            * temperatureTerm

        let seconds = minutes * 60.0
        guard seconds.isFinite, seconds >= 0 else { return .invalid }
        return CoolingSolution(isValid: true, seconds: seconds, thetaTarget: thetaTarget)
    }

    /// Convenience overload taking the discrete UI selection.
    public static func solve(startTempC: Double,
                             targetTempC: Double,
                             deviceTempC: Double,
                             containerType: ContainerType,
                             volume: VolumeOption,
                             deviceMode: DeviceMode,
                             orientation: ContainerOrientation) -> CoolingSolution {
        solve(startTempC: startTempC,
              targetTempC: targetTempC,
              deviceTempC: deviceTempC,
              preset: ContainerPreset.preset(for: containerType, volume: volume),
              deviceMode: deviceMode,
              orientation: orientation)
    }

    /// Whole-minute cooling time as shown in the UI.
    /// Returns `nil` for invalid input, `0` when the drink is already cold enough,
    /// otherwise at least 1 (matching `MainActivity.calculateCoolingMinutes`).
    public static func coolingMinutes(for solution: CoolingSolution) -> Int? {
        guard solution.isValid else { return nil }
        if solution.seconds <= 0 { return 0 }
        return max(1, Int(ceil(solution.seconds / 60.0)))
    }

    /// Estimated beer temperature after `elapsedSeconds` of a run whose total
    /// duration is `solution.seconds`. Mirrors
    /// `MainActivity.calculateCurrentBeerTemperature`, including the clamp into
    /// [target, start].
    public static func currentTemperatureC(solution: CoolingSolution,
                                          elapsedSeconds: Double,
                                          startTempC: Double,
                                          targetTempC: Double,
                                          deviceTempC: Double) -> Double {
        guard solution.isValid, solution.seconds > 0 else { return targetTempC }

        let temperatureTerm = (pow(solution.thetaTarget, -convectionExponent) - 1.0)
            / convectionExponent
        guard temperatureTerm.isFinite, temperatureTerm > 0 else { return targetTempC }

        let clampedElapsed = min(max(elapsedSeconds, 0), solution.seconds)
        let tauEffective = solution.seconds / temperatureTerm
        let theta = pow(1.0 + convectionExponent * clampedElapsed / tauEffective,
                        -1.0 / convectionExponent)
        let temperature = deviceTempC + (startTempC - deviceTempC) * theta
        return min(max(temperature, targetTempC), startTempC)
    }

    /// Same as above but expressed as fraction of the total run (0…1), which is
    /// what the Android view layer passes in.
    public static func currentTemperatureC(solution: CoolingSolution,
                                           progress: Double,
                                           startTempC: Double,
                                           targetTempC: Double,
                                           deviceTempC: Double) -> Double {
        let clamped = min(max(progress, 0), 1)
        return currentTemperatureC(solution: solution,
                                   elapsedSeconds: solution.seconds * clamped,
                                   startTempC: startTempC,
                                   targetTempC: targetTempC,
                                   deviceTempC: deviceTempC)
    }

    // MARK: Preferences

    public static func clamp(_ value: Int, _ minValue: Int, _ maxValue: Int) -> Int {
        max(minValue, min(value, maxValue))
    }

    /// Mirrors `MainActivity.restoreTemperaturePreference`: fall back to the
    /// default on a fresh install, otherwise clamp the stored value.
    public static func restoreTemperaturePreference(hasSavedValue: Bool,
                                                    savedValue: Int,
                                                    defaultValue: Int,
                                                    minValue: Int,
                                                    maxValue: Int) -> Int {
        guard hasSavedValue else { return defaultValue }
        return clamp(savedValue, minValue, maxValue)
    }
}
