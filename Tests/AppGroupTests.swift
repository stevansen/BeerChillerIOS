//
//  AppGroupTests.swift
//  BeerCHILLERTests
//
//  The App Group is what lets the widget and the watch app see a running timer.
//  When the entitlement is missing or the identifier is misspelt, nothing throws:
//  the app falls back to its own defaults and simply shares nothing. Without a
//  test, the first sign is a widget that never updates.
//

import XCTest
@testable import BeerCHILLER

final class AppGroupTests: XCTestCase {

    /// The authoritative check. Fails the build on a missing entitlement or a
    /// typo in the identifier, either of which is otherwise silent.
    func testTheAppGroupContainerResolves() {
        XCTAssertTrue(SharedStore.isSharingContainer,
                      "no container for \(SharedStore.appGroupIdentifier) — the "
                      + "entitlement is missing or the identifier does not match "
                      + "the one in the four .entitlements files, and the widget "
                      + "and watch app would silently see no data")
    }

    func testSharedDefaultsAreTheGroupSuite() {
        XCTAssertNotEqual(SharedStore.defaults, .standard,
                          "SharedStore fell back to standard defaults, so nothing "
                          + "is shared with the widget or the watch")
    }

    /// Guards the reasoning behind `isSharingContainer`: a round trip is not
    /// evidence of membership. If this ever starts failing, Apple changed the
    /// behaviour and the simpler check would become viable again.
    func testARoundTripAloneProvesNothing() {
        let bogus = "group.com.bierchiller.app.doesnotexist"
        XCTAssertNil(FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: bogus))

        let suite = UserDefaults(suiteName: bogus)
        XCTAssertNotNil(suite, "a non-member group still yields a usable suite")
        suite?.set(true, forKey: "__probe")
        XCTAssertTrue(suite?.bool(forKey: "__probe") == true,
                      "the round trip succeeds even for a group this app is not "
                      + "a member of — which is why it cannot be used as the check")
        suite?.removeObject(forKey: "__probe")
    }
}
