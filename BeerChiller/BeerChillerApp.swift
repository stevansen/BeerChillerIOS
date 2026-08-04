//
//  BeerChillerApp.swift
//  BeerCHILLER
//

import SwiftUI

extension View {
    /// Applies a light/dark override only when the user actually chose one, so
    /// `AppearanceMode.system` leaves the window's scheme entirely untouched
    /// rather than relying on `preferredColorScheme(nil)` behaving as a no-op.
    @ViewBuilder
    func appearanceOverride(_ scheme: ColorScheme?) -> some View {
        if let scheme {
            preferredColorScheme(scheme)
        } else {
            self
        }
    }
}

@main
struct BeerChillerApp: App {

    @StateObject private var settings = AppSettings.shared
    @StateObject private var controller = ChillController.shared
    @Environment(\.scenePhase) private var scenePhase

    init() {
        WatchSync.shared.activate()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(settings)
                .environmentObject(controller)
                .appearanceOverride(settings.appearance.colorScheme)
        }
        .onChange(of: scenePhase) { phase in
            // Coming back from the background: recompute against the wall clock
            // instead of trusting a timer that was suspended.
            if phase == .active {
                // Pull the counterpart's latest state rather than waiting for a
                // delegate callback that may never arrive.
                WatchSync.shared.adoptReceivedContext()
                controller.refreshNow()
            }
        }
    }
}
