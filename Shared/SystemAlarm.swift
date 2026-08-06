//
//  SystemAlarm.swift
//  BeerCHILLER
//
//  A real alarm — the kind that rings through the silent switch and through
//  Focus, and keeps ringing until it is dismissed — rather than a notification
//  that chimes once and is gone.
//
//  Until iOS 26 no third-party app could do this. The app therefore scheduled a
//  `UNNotification` with `interruptionLevel = .timeSensitive`, which is the
//  closest a notification gets: it can break through Focus if the user allows it,
//  but the ring/silent switch still silences it and it never repeats. For a timer
//  whose whole purpose is "tell me when the beer is cold, I have walked away",
//  that is a real limitation.
//
//  AlarmKit (iOS 26) closes it. `AlarmManager` schedules a countdown that the
//  system owns, so it survives the app being suspended or killed, and it presents
//  the full-screen alert itself.
//
//  Requires iOS **26.1**, not 26.0: `AlarmPresentation.Alert`'s 26.0 initialiser
//  takes a `stopButton` that 26.1 deprecates ("no longer used"). Calling the
//  deprecated one to reach 26.0 would build a warning into a project that has
//  none, for the benefit of a single point release. Anyone below 26.1 keeps the
//  notification, which still works.
//
//  The notification is scheduled either way. Two alerts is the failure mode to
//  prefer over none, and `cancel` clears both.
//

import Foundation
#if canImport(AlarmKit)
import AlarmKit
import SwiftUI
#endif

public enum SystemAlarm {

    /// Stable across launches so a run started before the app was killed can
    /// still be stopped.
    private static let alarmID = UUID(uuidString: "B33C4111-0000-4000-8000-000000000001")!

    /// Whether this device can present a real alarm.
    public static var isAvailable: Bool {
        #if canImport(AlarmKit)
        if #available(iOS 26.1, *) { return true }
        #endif
        return false
    }

    #if canImport(AlarmKit)
    @available(iOS 26.1, *)
    private struct Metadata: AlarmMetadata {}
    #endif

    /// Asks for permission, if it has not been decided yet.
    ///
    /// Returns whether an alarm may be scheduled. A refusal is not an error: the
    /// notification path stays in place and the app keeps working.
    @discardableResult
    public static func requestAuthorization() async -> Bool {
        #if canImport(AlarmKit)
        if #available(iOS 26.1, *) {
            let manager = AlarmManager.shared
            switch manager.authorizationState {
            case .authorized:
                return true
            case .denied:
                return false
            case .notDetermined:
                let state = try? await manager.requestAuthorization()
                return state == .authorized
            @unknown default:
                return false
            }
        }
        #endif
        return false
    }

    /// Schedules the alarm for the end of a run. Does nothing when unavailable or
    /// not permitted, so callers do not need to branch.
    public static func schedule(endingIn seconds: TimeInterval) async {
        #if canImport(AlarmKit)
        if #available(iOS 26.1, *) {
            guard seconds > 0, await requestAuthorization() else { return }

            let alert = AlarmPresentation.Alert(
                title: LocalizedStringResource("alarm_ringing"),
                secondaryButton: nil,
                secondaryButtonBehavior: nil)

            // The countdown presentation is what the system shows while the timer
            // runs — in the Dynamic Island and on the Lock Screen.
            let countdown = AlarmPresentation.Countdown(
                title: LocalizedStringResource("cooling_time"),
                pauseButton: nil)

            let attributes = AlarmAttributes<Metadata>(
                presentation: AlarmPresentation(alert: alert, countdown: countdown),
                metadata: Metadata(),
                tintColor: Color(red: 0.91, green: 0.71, blue: 0.13))

            let configuration = AlarmManager.AlarmConfiguration.timer(
                duration: seconds,
                attributes: attributes)

            // A previous run's alarm would otherwise sit in the system's list.
            try? AlarmManager.shared.cancel(id: alarmID)
            _ = try? await AlarmManager.shared.schedule(id: alarmID,
                                                        configuration: configuration)
        }
        #endif
    }

    /// Stops a ringing alarm and removes a pending one. Safe to call always.
    public static func cancel() {
        #if canImport(AlarmKit)
        if #available(iOS 26.1, *) {
            // `stop` silences one that is ringing; `cancel` removes one that is
            // still counting down. Which applies depends on timing, so do both.
            try? AlarmManager.shared.stop(id: alarmID)
            try? AlarmManager.shared.cancel(id: alarmID)
        }
        #endif
    }
}
