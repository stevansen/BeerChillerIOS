//
//  BeerChillerWatchApp.swift
//  BeerCHILLER Watch App
//
//  Standalone: the watch keeps its own copy of the session and can start and
//  stop a run without the phone. WatchConnectivity keeps the two in step when
//  both are reachable.
//

import SwiftUI
import WatchKit

@main
struct BeerChillerWatchApp: App {

    @StateObject private var settings = AppSettings.shared
    @StateObject private var controller = ChillController.shared
    @Environment(\.scenePhase) private var scenePhase

    init() {
        WatchSync.shared.activate()
    }

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environmentObject(settings)
                .environmentObject(controller)
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                // Pull the counterpart's latest state rather than waiting for a
                // delegate callback that may never arrive.
                WatchSync.shared.adoptReceivedContext()
                controller.refreshNow()
            }
        }
    }
}
