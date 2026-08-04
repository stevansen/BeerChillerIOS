//
//  CoolingModelTests.swift
//  BeerCHILLER
//
//  Parity tests against the Android original. Every expectation in
//  `AndroidParity` is taken verbatim from the Java unit tests in
//  app/src/test/java/com/bierchiller/app/ so the Swift port cannot drift.
//

import XCTest
@testable import BeerCHILLER

final class CoolingModelTests: XCTestCase {

    /// Helper mirroring `ContainerCoolingModelTest.coolingMinutes`.
    private func coolingMinutes(startTempC: Double,
                                targetTempC: Double,
                                deviceTempC: Double,
                                containerType: ContainerType,
                                volume: VolumeOption,
                                deviceMode: DeviceMode,
                                orientation: ContainerOrientation) -> Int {
        let solution = CoolingModel.solve(startTempC: startTempC,
                                          targetTempC: targetTempC,
                                          deviceTempC: deviceTempC,
                                          containerType: containerType,
                                          volume: volume,
                                          deviceMode: deviceMode,
                                          orientation: orientation)
        return max(1, Int(ceil(solution.seconds / 60.0)))
    }

    // MARK: - ContainerCoolingModelTest parity

    func testMatchesFridgeCalibrationAt12C() {
        XCTAssertEqual(136, coolingMinutes(startTempC: 32.94, targetTempC: 12.0,
                                           deviceTempC: 5.3, containerType: .bottle,
                                           volume: .small, deviceMode: .fridge,
                                           orientation: .standing))
    }

    func testMatchesFridgeCalibrationAt10C() {
        XCTAssertEqual(174, coolingMinutes(startTempC: 32.94, targetTempC: 10.0,
                                           deviceTempC: 5.3, containerType: .bottle,
                                           volume: .small, deviceMode: .fridge,
                                           orientation: .standing))
    }

    func testMatchesFridgeCalibrationAt8C() {
        XCTAssertEqual(239, coolingMinutes(startTempC: 32.94, targetTempC: 8.0,
                                           deviceTempC: 5.3, containerType: .bottle,
                                           volume: .small, deviceMode: .fridge,
                                           orientation: .standing))
    }

    func testMatchesFreezerCalibrationAt6C() {
        XCTAssertEqual(62, coolingMinutes(startTempC: 39.5, targetTempC: 6.0,
                                          deviceTempC: -17.5, containerType: .bottle,
                                          volume: .small, deviceMode: .freezer,
                                          orientation: .standing))
    }

    func testColdBottleFreezerStartAt16CTo12CUsesCorrection() {
        XCTAssertEqual(15, coolingMinutes(startTempC: 16.0, targetTempC: 12.0,
                                          deviceTempC: -18.0, containerType: .bottle,
                                          volume: .small, deviceMode: .freezer,
                                          orientation: .standing))
    }

    func testColdBottleFreezerStartAt16CTo8CUsesCorrection() {
        XCTAssertEqual(33, coolingMinutes(startTempC: 16.0, targetTempC: 8.0,
                                          deviceTempC: -18.0, containerType: .bottle,
                                          volume: .small, deviceMode: .freezer,
                                          orientation: .standing))
    }

    func testColdBottleFreezerStartAt20CInterpolatesCorrection() {
        XCTAssertEqual(37, coolingMinutes(startTempC: 20.0, targetTempC: 8.0,
                                          deviceTempC: -18.0, containerType: .bottle,
                                          volume: .small, deviceMode: .freezer,
                                          orientation: .standing))
    }

    func testColdStartCorrectionDoesNotApplyToCans() {
        XCTAssertEqual(19, coolingMinutes(startTempC: 16.0, targetTempC: 8.0,
                                          deviceTempC: -18.0, containerType: .can,
                                          volume: .small, deviceMode: .freezer,
                                          orientation: .standing))
    }

    func testHalfLiterBottleFridgeExampleMatchesSpecification() {
        XCTAssertEqual(288, coolingMinutes(startTempC: 20.0, targetTempC: 6.0,
                                           deviceTempC: 4.0, containerType: .bottle,
                                           volume: .medium, deviceMode: .fridge,
                                           orientation: .standing))
    }

    func testAlreadyColdEnoughReturnsZero() {
        let solution = CoolingModel.solve(startTempC: 6.0, targetTempC: 8.0,
                                          deviceTempC: 4.0, preset: .referenceBottle,
                                          deviceMode: .fridge, orientation: .standing)
        XCTAssertEqual(0.0, solution.seconds, accuracy: 0.0001)
        XCTAssertEqual(0, CoolingModel.coolingMinutes(for: solution))
    }

    func testTargetAtDeviceTemperatureIsInvalid() {
        let solution = CoolingModel.solve(startTempC: 20.0, targetTempC: 4.0,
                                          deviceTempC: 4.0, preset: .referenceBottle,
                                          deviceMode: .fridge, orientation: .standing)
        XCTAssertFalse(solution.isValid)
        XCTAssertNil(CoolingModel.coolingMinutes(for: solution))
    }

    func testOneLiterCanIsInvalid() {
        XCTAssertFalse(ContainerPreset.preset(for: .can, volume: .large).isValid)
    }

    // MARK: - OrientationFactorTest parity

    func testBottleLyingUsesSmallSlowdownFactor() {
        XCTAssertEqual(0.95,
                       CoolingModel.positionFactor(for: .bottle, orientation: .lying),
                       accuracy: 0.0001)
    }

    func testBottleStandingIsReferencePosition() {
        XCTAssertEqual(1.0,
                       CoolingModel.positionFactor(for: .bottle, orientation: .standing),
                       accuracy: 0.0001)
    }

    func testCanLyingUsesCanSpecificFactor() {
        XCTAssertEqual(0.92,
                       CoolingModel.positionFactor(for: .can, orientation: .lying),
                       accuracy: 0.0001)
    }

    func testDeviceFactors() {
        XCTAssertEqual(1.0, CoolingModel.deviceFactor(for: .fridge), accuracy: 0.0001)
        XCTAssertEqual(0.84, CoolingModel.deviceFactor(for: .freezer), accuracy: 0.0001)
    }

    // MARK: - TemperaturePreferenceDefaultsTest parity

    func testFreshInstallTargetTemperatureDefaultsToEightCelsius() {
        XCTAssertEqual(8, CoolingModel.restoreTemperaturePreference(
            hasSavedValue: false, savedValue: 6,
            defaultValue: CoolingModel.defaultTargetTempC,
            minValue: CoolingModel.minTargetTempC,
            maxValue: CoolingModel.maxTargetTempC))
    }

    func testSavedSixDegreeTargetTemperatureRemainsValid() {
        XCTAssertEqual(6, CoolingModel.restoreTemperaturePreference(
            hasSavedValue: true, savedValue: 6,
            defaultValue: CoolingModel.defaultTargetTempC,
            minValue: CoolingModel.minTargetTempC,
            maxValue: CoolingModel.maxTargetTempC))
    }

    func testTargetTemperaturePreferenceIsClampedToSupportedRange() {
        XCTAssertEqual(CoolingModel.minTargetTempC,
                       CoolingModel.clamp(-20, CoolingModel.minTargetTempC,
                                          CoolingModel.maxTargetTempC))
        XCTAssertEqual(CoolingModel.maxTargetTempC,
                       CoolingModel.clamp(30, CoolingModel.minTargetTempC,
                                          CoolingModel.maxTargetTempC))
    }

    // MARK: - Cold-start factor shape

    func testColdStartFactorEndpoints() {
        // At and below 16 °C the correction is fully applied.
        XCTAssertEqual(1.70, CoolingModel.coldStartFactor(containerType: .bottle,
                                                          deviceMode: .freezer,
                                                          startTempC: 16.0),
                       accuracy: 0.0001)
        XCTAssertEqual(1.70, CoolingModel.coldStartFactor(containerType: .bottle,
                                                          deviceMode: .freezer,
                                                          startTempC: 5.0),
                       accuracy: 0.0001)
        // At and above 24 °C it is not applied.
        XCTAssertEqual(1.0, CoolingModel.coldStartFactor(containerType: .bottle,
                                                         deviceMode: .freezer,
                                                         startTempC: 24.0),
                       accuracy: 0.0001)
        XCTAssertEqual(1.0, CoolingModel.coldStartFactor(containerType: .bottle,
                                                         deviceMode: .freezer,
                                                         startTempC: 30.0),
                       accuracy: 0.0001)
        // Midpoint: smoothstep(0.5) = 0.5 → 1 + 0.7·0.5
        XCTAssertEqual(1.35, CoolingModel.coldStartFactor(containerType: .bottle,
                                                          deviceMode: .freezer,
                                                          startTempC: 20.0),
                       accuracy: 0.0001)
        // Never applies in the fridge, and never to cans.
        XCTAssertEqual(1.0, CoolingModel.coldStartFactor(containerType: .bottle,
                                                         deviceMode: .fridge,
                                                         startTempC: 16.0),
                       accuracy: 0.0001)
        XCTAssertEqual(1.0, CoolingModel.coldStartFactor(containerType: .can,
                                                         deviceMode: .freezer,
                                                         startTempC: 16.0),
                       accuracy: 0.0001)
    }

    // MARK: - Live temperature curve

    func testCurrentTemperatureStartsAtStartAndEndsAtTarget() {
        let start = 22.0, target = 8.0, device = -18.0
        let solution = CoolingModel.solve(startTempC: start, targetTempC: target,
                                          deviceTempC: device, preset: .referenceBottle,
                                          deviceMode: .freezer, orientation: .standing)
        XCTAssertTrue(solution.isValid)

        let atStart = CoolingModel.currentTemperatureC(solution: solution, progress: 0,
                                                       startTempC: start, targetTempC: target,
                                                       deviceTempC: device)
        XCTAssertEqual(start, atStart, accuracy: 0.0001)

        let atEnd = CoolingModel.currentTemperatureC(solution: solution, progress: 1,
                                                     startTempC: start, targetTempC: target,
                                                     deviceTempC: device)
        XCTAssertEqual(target, atEnd, accuracy: 0.0001)
    }

    func testCurrentTemperatureIsMonotonicallyDecreasing() {
        let start = 22.0, target = 8.0, device = -18.0
        let solution = CoolingModel.solve(startTempC: start, targetTempC: target,
                                          deviceTempC: device, preset: .referenceBottle,
                                          deviceMode: .freezer, orientation: .standing)
        var previous = Double.infinity
        for step in 0...20 {
            let value = CoolingModel.currentTemperatureC(
                solution: solution, progress: Double(step) / 20.0,
                startTempC: start, targetTempC: target, deviceTempC: device)
            XCTAssertLessThanOrEqual(value, previous + 1e-9,
                                     "temperature rose at step \(step)")
            previous = value
        }
    }

    func testCurrentTemperatureClampsOutOfRangeProgress() {
        let start = 22.0, target = 8.0, device = 4.0
        let solution = CoolingModel.solve(startTempC: start, targetTempC: target,
                                          deviceTempC: device, preset: .referenceBottle,
                                          deviceMode: .fridge, orientation: .standing)
        XCTAssertEqual(start, CoolingModel.currentTemperatureC(
            solution: solution, progress: -5, startTempC: start,
            targetTempC: target, deviceTempC: device), accuracy: 0.0001)
        XCTAssertEqual(target, CoolingModel.currentTemperatureC(
            solution: solution, progress: 5, startTempC: start,
            targetTempC: target, deviceTempC: device), accuracy: 0.0001)
    }

    // MARK: - Guard rails

    func testLyingContainerCoolsFasterThanStanding() {
        let lying = coolingMinutes(startTempC: 22, targetTempC: 8, deviceTempC: -18,
                                   containerType: .can, volume: .small,
                                   deviceMode: .freezer, orientation: .lying)
        let standing = coolingMinutes(startTempC: 22, targetTempC: 8, deviceTempC: -18,
                                      containerType: .can, volume: .small,
                                      deviceMode: .freezer, orientation: .standing)
        XCTAssertLessThan(lying, standing)
    }

    func testLargerBottleTakesLonger() {
        let small = coolingMinutes(startTempC: 22, targetTempC: 8, deviceTempC: 4,
                                   containerType: .bottle, volume: .small,
                                   deviceMode: .fridge, orientation: .standing)
        let large = coolingMinutes(startTempC: 22, targetTempC: 8, deviceTempC: 4,
                                   containerType: .bottle, volume: .large,
                                   deviceMode: .fridge, orientation: .standing)
        XCTAssertLessThan(small, large)
    }

    func testTemperatureBoundsMatchAndroid() {
        XCTAssertEqual(-5, CoolingModel.minStartTempC)
        XCTAssertEqual(40, CoolingModel.maxStartTempC)
        XCTAssertEqual(-5, CoolingModel.minTargetTempC)
        XCTAssertEqual(20, CoolingModel.maxTargetTempC)
        XCTAssertEqual(-30, CoolingModel.minDeviceTempC)
        XCTAssertEqual(5, CoolingModel.maxDeviceTempC)
        XCTAssertEqual(22, CoolingModel.defaultStartTempC)
        XCTAssertEqual(8, CoolingModel.defaultTargetTempC)
        XCTAssertEqual(-18, CoolingModel.defaultDeviceTempC)
        XCTAssertEqual(-18, DeviceMode.freezer.defaultTemperatureC)
        XCTAssertEqual(4, DeviceMode.fridge.defaultTemperatureC)
    }
}

// MARK: - Widget timeline planning

final class WidgetTimelineTests: XCTestCase {

    private func session(minutes: Double, startedMinutesAgo: Double,
                         now: Date) -> ChillSession {
        let start = now.addingTimeInterval(-startedMinutesAgo * 60)
        return ChillSession(startDate: start,
                            endDate: start.addingTimeInterval(minutes * 60),
                            startTempC: 22, targetTempC: 8, deviceTempC: -18,
                            containerType: .bottle, volume: .small,
                            deviceMode: .freezer, orientation: .standing)
    }

    func testEntriesAreOneMinuteApartAndEndExactlyAtTheEndDate() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let run = session(minutes: 10, startedMinutesAgo: 0, now: now)

        let dates = WidgetTimeline.entryDates(for: run, from: now)

        // 10 minute-entries plus the closing entry at endDate.
        XCTAssertEqual(dates.count, 11)
        XCTAssertEqual(dates.first, now)
        XCTAssertEqual(dates.last, run.endDate)
        for index in 1..<(dates.count - 1) {
            XCTAssertEqual(dates[index].timeIntervalSince(dates[index - 1]),
                           WidgetTimeline.step, accuracy: 0.001)
        }
        XCTAssertTrue(dates.allSatisfy { $0 <= run.endDate })
    }

    func testEntryCountIsCappedForVeryLongRuns() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        // Nine hours: far more minutes than WidgetKit should be handed.
        let run = session(minutes: 540, startedMinutesAgo: 0, now: now)

        let dates = WidgetTimeline.entryDates(for: run, from: now)
        XCTAssertEqual(dates.count, WidgetTimeline.maximumEntries + 1)
        // The cap must not fake an early finish: the last entry is the real end.
        XCTAssertEqual(dates.last, run.endDate)
    }

    func testFinishedSessionProducesNoCountdownEntries() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let run = session(minutes: 10, startedMinutesAgo: 30, now: now)
        XCTAssertTrue(run.isFinished(at: now))
        XCTAssertTrue(WidgetTimeline.entryDates(for: run, from: now).isEmpty)
    }

    func testRefreshDateFallsBackToIdleIntervalWithoutASession() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        XCTAssertEqual(WidgetTimeline.refreshDate(for: nil, from: now),
                       now.addingTimeInterval(WidgetTimeline.idleRefresh))
    }

    func testRefreshDateIsJustAfterTheEndForShortRuns() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let run = session(minutes: 10, startedMinutesAgo: 0, now: now)
        XCTAssertEqual(WidgetTimeline.refreshDate(for: run, from: now),
                       run.endDate.addingTimeInterval(1))
    }

    func testRefreshDateIsBoundedByTheEntryBudgetForLongRuns() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let run = session(minutes: 540, startedMinutesAgo: 0, now: now)
        let expected = now.addingTimeInterval(
            WidgetTimeline.step * Double(WidgetTimeline.maximumEntries))
        XCTAssertEqual(WidgetTimeline.refreshDate(for: run, from: now), expected)
        XCTAssertLessThan(WidgetTimeline.refreshDate(for: run, from: now), run.endDate)
    }

    func testFinishedSessionRefreshesOnTheIdleSchedule() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let run = session(minutes: 10, startedMinutesAgo: 30, now: now)
        XCTAssertEqual(WidgetTimeline.refreshDate(for: run, from: now),
                       now.addingTimeInterval(WidgetTimeline.idleRefresh))
    }
}

// MARK: - Help-page formula typesetting

/// These tests parse every formula in every one of the ten localized help files.
/// They exist because two unhandled LaTeX commands shipped unnoticed: `\text{min}`
/// printed "textmin", and `\le` — used 30 times across the files — printed a
/// literal "le" instead of "≤". A command the parser does not know is exactly the
/// kind of defect that is invisible in code review and obvious on screen.
final class HelpFormulaTests: XCTestCase {

    /// Command names that must never survive into rendered output.
    private let leakedCommands = [
        "text", "mathrm", "frac", "left", "right", "cdot", "times",
        "leq", "geq", "neq", "le", "ge", "ne", "sim", "approx",
        "dot", "lceil", "rceil", "lfloor", "rfloor",
        "Delta", "delta", "theta", "Theta", "tau", "alpha", "beta",
        "lambda", "rho", "infty",
    ]

    private func helpMarkdown() throws -> [(name: String, text: String)] {
        let urls = Bundle.main.urls(forResourcesWithExtension: "md", subdirectory: nil) ?? []
        let helpURLs = urls.filter { $0.lastPathComponent.hasPrefix("cooling_model_") }
        XCTAssertEqual(helpURLs.count, 10,
                       "expected ten localized help files, found \(helpURLs.count)")
        return try helpURLs.map {
            (name: $0.lastPathComponent, text: try String(contentsOf: $0, encoding: .utf8))
        }
    }

    /// Both display maths (`\[ … \]`) and inline maths (`\( … \)`).
    private func formulas(in markdown: String) -> [String] {
        var result: [String] = []

        var displayLines: [String] = []
        var inDisplay = false
        for rawLine in markdown.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line == "\\[" { inDisplay = true; displayLines = []; continue }
            if line == "\\]" {
                inDisplay = false
                result.append(displayLines.joined(separator: " "))
                continue
            }
            if inDisplay { displayLines.append(line); continue }

            var remainder = Substring(line)
            while let open = remainder.range(of: "\\("),
                  let close = remainder.range(of: "\\)", range: open.upperBound..<remainder.endIndex) {
                result.append(String(remainder[open.upperBound..<close.lowerBound]))
                remainder = remainder[close.upperBound...]
            }
        }
        return result.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    func testNoLatexCommandNameSurvivesParsing() throws {
        var checked = 0
        for file in try helpMarkdown() {
            for latex in formulas(in: file.text) {
                let flattened = MathParser.parse(latex).flattenedText
                checked += 1
                for command in leakedCommands {
                    XCTAssertFalse(
                        flattened.contains(command),
                        "\(file.name): \"\(latex)\" rendered as \"\(flattened)\" — "
                        + "leftover LaTeX command \"\(command)\"")
                }
                // A stray backslash means something was not consumed at all.
                XCTAssertFalse(flattened.contains("\\"),
                               "\(file.name): \"\(latex)\" rendered as \"\(flattened)\"")
            }
        }
        XCTAssertGreaterThan(checked, 100, "suspiciously few formulas found: \(checked)")
    }

    func testTextCommandIsTakenLiterallyAndKeepsItsUnit() {
        // The final formula of every help file.
        let flattened = MathParser.parse("t_{app} \\approx 62\\,\\text{min}").flattenedText
        XCTAssertTrue(flattened.contains("min"), flattened)
        XCTAssertFalse(flattened.contains("textmin"), flattened)
        // Thin space between the number and the unit, not a plain space.
        XCTAssertTrue(flattened.contains("62\u{2009}min"), flattened)
    }

    func testShortRelationCommandsBecomeSymbols() {
        for (latex, symbol) in [("T_0 \\le T_Z", "≤"),
                                ("a \\ge b", "≥"),
                                ("a \\ne b", "≠")] {
            let flattened = MathParser.parse(latex).flattenedText
            XCTAssertTrue(flattened.contains(symbol),
                          "\(latex) rendered as \(flattened)")
        }
    }

    func testUnitAfterNumberGetsAThinSpaceAndStaysUpright() {
        let node = MathParser.parse("\\Delta_{ref}=25K")
        XCTAssertTrue(node.flattenedText.contains("25\u{2009}K"), node.flattenedText)
    }
}
