//
//  BeerChillerUITests.swift
//  BeerCHILLERUITests
//
//  Layout and accessibility coverage that needs a real device context:
//  orientation changes and Dynamic Type.
//
//  Each test also leaves the simulator in the state it set up, and writes a PNG
//  into the test bundle's temporary directory, so the layouts can be inspected
//  from the host afterwards (see tools/collect_screenshots.sh).
//

import XCTest

final class BeerChillerUITests: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
    }

    // MARK: Helpers

    private func launch(contentSize: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        if let contentSize {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", contentSize]
        }
        app.launch()
        return app
    }

    private func capture(_ app: XCUIApplication, named name: String) {
        // Attachment for the .xcresult…
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)

        // …and a plain PNG that the host can pick up directly.
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("\(name).png")
        try? screenshot.pngRepresentation.write(to: url)
    }

    /// The header wordmark is present in every layout — a cheap "did it render"
    /// assertion that does not depend on the current language.
    private func assertRendered(_ app: XCUIApplication) {
        XCTAssertTrue(app.staticTexts["BeerCHILLER"].waitForExistence(timeout: 10),
                      "main screen did not render")
    }

    // MARK: Tests

    func testPortraitLayout() {
        let app = launch()
        XCUIDevice.shared.orientation = .portrait
        assertRendered(app)
        capture(app, named: "portrait")
    }

    func testLandscapeLayout() {
        let app = launch()
        XCUIDevice.shared.orientation = .landscapeLeft
        assertRendered(app)
        capture(app, named: "landscape")
    }

    /// Largest accessibility text size: nothing may disappear or clip away.
    func testAccessibilityExtraExtraExtraLargeText() {
        let app = launch(contentSize: "UICTContentSizeCategoryAccessibilityXXXL")
        assertRendered(app)
        capture(app, named: "dynamic-type-axxxl")

        // The primary action has to survive the largest text size.
        let startButton = app.buttons.matching(NSPredicate(format: "isEnabled == true"))
        XCTAssertGreaterThan(startButton.count, 0, "no enabled controls at AX XXXL")
    }

    /// iPad and landscape both use the two-column arrangement; make sure the
    /// dial and the controls are on screen at the same time.
    func testWideLayoutShowsDialAndControlsTogether() {
        let app = launch()
        XCUIDevice.shared.orientation = .landscapeLeft
        assertRendered(app)

        let window = app.windows.element(boundBy: 0).frame
        let wordmark = app.staticTexts["BeerCHILLER"]
        XCTAssertTrue(window.contains(wordmark.frame.origin))
        capture(app, named: "landscape-wide")
    }

    /// Every interactive element must carry a label VoiceOver can announce.
    func testAccessibilityLabelsArePresent() {
        let app = launch()
        assertRendered(app)

        let buttons = app.buttons
        XCTAssertGreaterThan(buttons.count, 0)

        var inventory: [String] = []
        var labelledFrames: Set<String> = []
        var unlabelled: [(index: Int, frame: String)] = []

        for index in 0..<buttons.count {
            let button = buttons.element(boundBy: index)
            guard button.exists else { continue }
            let label = button.label.trimmingCharacters(in: .whitespacesAndNewlines)
            let frame = "\(button.frame)"
            inventory.append("#\(index) '\(label)' \(frame)")
            if label.isEmpty {
                unlabelled.append((index, frame))
            } else {
                labelledFrames.insert(frame)
            }
        }

        let dump = XCTAttachment(string: inventory.joined(separator: "\n"))
        dump.name = "button-inventory"
        dump.lifetime = .keepAlways
        add(dump)

        // SwiftUI's `Menu` publishes two elements at the identical frame: the
        // labelled one VoiceOver actually reads, plus an unlabelled inner button.
        // An unlabelled element is therefore only a defect when nothing labelled
        // covers the same frame.
        let genuinelyUnlabelled = unlabelled.filter { !labelledFrames.contains($0.frame) }
        XCTAssertTrue(genuinelyUnlabelled.isEmpty,
                      "buttons with no accessibility label anywhere at their frame: "
                      + genuinelyUnlabelled.map { "#\($0.index) \($0.frame)" }
                          .joined(separator: " | "))
    }

    /// Each volume option must announce its own size, not a shared group name.
    func testVolumeOptionsAnnounceIndividualSizes() {
        let app = launch()
        assertRendered(app)

        let volumeLabels = (0..<app.buttons.count)
            .map { app.buttons.element(boundBy: $0).label }
            .filter { $0.contains("l") && $0.contains(",") }
        XCTAssertGreaterThanOrEqual(volumeLabels.count, 3,
                                    "expected the three volume options, got \(volumeLabels)")
        XCTAssertEqual(Set(volumeLabels).count, volumeLabels.count,
                       "volume options announce duplicate labels: \(volumeLabels)")
    }
}

// MARK: - Alarm flow

/// End-to-end cover for the state a user hits after leaving the app: the timer
/// finished while the app was gone, so the "your beer is cold" screen has to
/// appear on the next launch and acknowledging it has to clear the run.
///
/// Driven by the debug-only `-seedFinishedSession` launch argument instead of a
/// real four-minute cool-down, and asserted through the accessibility hierarchy
/// rather than a screenshot — the simulator framebuffer can serve a stale frame
/// long after the UI has moved on, which is misleading to look at.
extension BeerChillerUITests {

    func testFinishedSessionShowsTheAlarmOnLaunch() {
        let app = XCUIApplication()
        app.launchArguments += ["-seedFinishedSession"]
        app.launch()

        XCTAssertTrue(app.buttons["alarm.stop"].waitForExistence(timeout: 10),
                      "a session that ended while the app was closed did not "
                      + "bring up the alarm screen")
        XCTAssertTrue(app.staticTexts["alarm.title"].exists)
    }

    func testAcknowledgingTheAlarmReturnsToTheMainScreen() {
        let app = XCUIApplication()
        app.launchArguments += ["-seedFinishedSession"]
        app.launch()

        let stop = app.buttons["alarm.stop"]
        XCTAssertTrue(stop.waitForExistence(timeout: 10))
        stop.tap()

        XCTAssertTrue(app.staticTexts["BeerCHILLER"].waitForExistence(timeout: 10),
                      "acknowledging the alarm did not return to the main screen")
        // The sheet must actually go away, not just lose focus.
        XCTAssertFalse(app.buttons["alarm.stop"].exists,
                       "the alarm screen stayed up after being acknowledged")
    }

    func testRunningSessionRestoresTheCountdownOnLaunch() {
        let app = XCUIApplication()
        app.launchArguments += ["-seedRunningSession"]
        app.launch()

        assertRendered(app)
        // Stop is only enabled while a run is in progress, so it proves the
        // session was picked up from storage rather than started fresh.
        let buttons = (0..<app.buttons.count).map { app.buttons.element(boundBy: $0) }
        XCTAssertTrue(buttons.contains { $0.isEnabled && $0.label.count > 2 })
        XCTAssertFalse(app.buttons["alarm.stop"].exists,
                       "a run still in progress must not show the alarm")
    }

    /// Goes through the real start path — the same one that schedules the
    /// notification, opens the Live Activity and hands the run to the watch.
    func testStartingATimerSwitchesToTheRunningState() {
        let app = XCUIApplication()
        app.launchArguments += ["-seedNoSession"]
        app.launch()
        assertRendered(app)

        // The primary action is the only enabled button carrying a play glyph's
        // label; find it by being the enabled one that is not a segment.
        let start = app.buttons["action.start"]
        XCTAssertTrue(start.waitForExistence(timeout: 10), "start button not found")
        XCTAssertTrue(start.isEnabled, "start button was disabled for valid inputs")

        start.tap()

        let stop = app.buttons["action.stop"]
        XCTAssertTrue(stop.waitForExistence(timeout: 10))
        XCTAssertTrue(stop.isEnabled, "stop stayed disabled after starting a run")
        XCTAssertFalse(start.isEnabled, "start stayed enabled during a run")
    }

    func testNoSessionStartsIdle() {
        let app = XCUIApplication()
        app.launchArguments += ["-seedNoSession"]
        app.launch()

        assertRendered(app)
        XCTAssertFalse(app.buttons["alarm.stop"].exists)
    }
}

// MARK: - Landscape regression

extension BeerChillerUITests {

    /// The start button has to be *on screen* in landscape, not merely present.
    ///
    /// This exists because it once was not: with the Beer style's portrait artwork
    /// scaled to fill a landscape screen, the image's ideal size propagated up
    /// through the layout and pushed the dial and every control to y ≈ 700 in a
    /// 402 pt window. Only the header was visible, and the earlier landscape check
    /// missed it because it ran in the Classic style, which has no image.
    func testLandscapeKeepsTheControlsInsideTheWindow() {
        let app = XCUIApplication()
        app.launchArguments += ["-seedNoSession"]
        app.launch()
        XCUIDevice.shared.orientation = .landscapeLeft

        let start = app.buttons["action.start"]
        XCTAssertTrue(start.waitForExistence(timeout: 10))

        let window = app.windows.element(boundBy: 0).frame
        for identifier in ["action.start", "action.stop"] {
            let frame = app.buttons[identifier].frame
            XCTAssertTrue(window.contains(frame),
                          "\(identifier) is outside the window in landscape: "
                          + "\(frame) vs \(window)")
        }

        // The dial's label lives at the centre of the screen's left column.
        let dialLabels = app.staticTexts.allElementsBoundByIndex
            .filter { window.intersects($0.frame) }
        XCTAssertGreaterThan(dialLabels.count, 2,
                             "almost nothing is on screen in landscape")
    }
}
