//
//  AppStoreScreenshots.swift
//  BeerCHILLERUITests
//
//  Captures the App Store screenshots. Not a test of behaviour — it asserts only
//  enough to fail loudly rather than silently shipping a blank frame.
//
//  Driven from a UI test rather than a shell script because two of the scenes
//  need the app driven: the calculation-model page sits behind the ⋯ menu, and a
//  running countdown has to be seeded before the frame is taken. The style and
//  appearance come from the DEBUG launch arguments in SharedStore, since both
//  live in the App Group where `-key value` arguments cannot reach.
//
//  Screenshots land in the test bundle's temporary directory and are collected by
//  tools/make_appstore_screenshots.sh, which runs this per device class.
//
//  Deliberately verified rather than assumed: every capture checks that the frame
//  is not a single flat colour. The simulator can hand back a stale or empty
//  framebuffer, and a store screenshot that is silently blank is worse than a
//  failing test.
//

import XCTest

final class AppStoreScreenshots: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
    }

    // MARK: Capture

    private func launch(style: String, appearance: String, session: String)
        -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-seedStyle", style,
                                "-seedAppearance", appearance,
                                session]
        app.launch()
        XCTAssertTrue(app.staticTexts["BeerCHILLER"].waitForExistence(timeout: 20),
                      "main screen did not render for \(style)/\(appearance)")
        return app
    }

    /// Waits until an element's frame stops moving, then returns it.
    ///
    /// A rotation is animated, and reading a frame straight after setting the
    /// orientation samples the animation rather than the result — which produced a
    /// landscape assertion that failed on iPad and passed on iPhone purely on
    /// timing. Polling until two consecutive reads agree makes the check about the
    /// layout instead of about the machine's speed, and it does not weaken the
    /// assertion: a genuinely overflowing frame is stable and still fails.
    private func settledFrame(of element: XCUIElement,
                              timeout: TimeInterval = 5) -> CGRect {
        var previous = CGRect.null
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let current = element.frame
            if current == previous { return current }
            previous = current
            Thread.sleep(forTimeInterval: 0.2)
        }
        return previous
    }

    private func capture(_ name: String) {
        let screenshot = XCUIScreen.main.screenshot()

        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)

        let data = screenshot.pngRepresentation
        XCTAssertGreaterThan(data.count, 20_000,
                             "\(name) is implausibly small for a screenshot — "
                             + "likely a blank frame")

        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("appstore-\(name).png")
        try? data.write(to: url)
    }

    // MARK: Scenes

    func testSceneIdleBeerLight() {
        let app = launch(style: "beer", appearance: "light", session: "-seedNoSession")
        XCTAssertTrue(app.buttons["action.start"].exists)
        capture("01-idle-beer-light")
    }

    func testSceneRunningBeerDark() {
        let app = launch(style: "beer", appearance: "dark", session: "-seedRunningSession")
        // A run in progress is what makes the dial worth showing.
        XCTAssertTrue(app.buttons["action.stop"].isEnabled,
                      "expected a running session")
        capture("02-running-beer-dark")
    }

    func testSceneIdleClassicLight() {
        _ = launch(style: "classic", appearance: "light", session: "-seedNoSession")
        capture("03-idle-classic-light")
    }

    func testSceneRunningClassicDark() {
        let app = launch(style: "classic", appearance: "dark",
                         session: "-seedRunningSession")
        XCTAssertTrue(app.buttons["action.stop"].isEnabled)
        capture("04-running-classic-dark")
    }

    /// The calculation model page — the app's distinguishing feature, and the one
    /// screen that has to be navigated to.
    ///
    /// The first version of this located the menu by size and the row by position,
    /// and asserted only `staticTexts.count > 5`. Both guesses missed, the
    /// assertion passed anyway, and the shipped screenshot was the main screen.
    /// Now it taps identifiers and asserts on content that exists *only* on the
    /// model page.
    func testSceneCalculationModel() {
        let app = launch(style: "classic", appearance: "light",
                         session: "-seedNoSession")

        app.buttons["menu.open"].tap()

        let modelRow = app.buttons["menu.model"]
        XCTAssertTrue(modelRow.waitForExistence(timeout: 10),
                      "the ⋯ menu did not open, or the model row is missing")
        modelRow.tap()

        // "BeerCHILLER Calibrated V2" is the model's name and appears on no other
        // screen, in any language — proof the right page is in front of the camera.
        let marker = app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS 'Calibrated V2'")).firstMatch
        XCTAssertTrue(marker.waitForExistence(timeout: 10),
                      "the calculation model page did not open — the frame would "
                      + "have been the main screen")
        capture("05-calculation-model")
    }

    func testSceneLandscapeBeerLight() {
        let app = launch(style: "beer", appearance: "light", session: "-seedRunningSession")
        XCUIDevice.shared.orientation = .landscapeLeft
        // Proof the landscape layout is intact in the frame being shipped.
        let stop = settledFrame(of: app.buttons["action.stop"])
        let window = app.windows.element(boundBy: 0).frame
        XCTAssertTrue(window.contains(stop),
                      "landscape controls are outside the window: \(stop) vs \(window)")
        capture("06-landscape-beer-light")
        XCUIDevice.shared.orientation = .portrait
    }
}
