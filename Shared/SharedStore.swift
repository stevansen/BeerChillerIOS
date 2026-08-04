//
//  SharedStore.swift
//  BeerCHILLER
//
//  One storage location shared by the app, the widget extension and the watch
//  app. Uses the App Group container when it is available and falls back to
//  standard defaults otherwise, so the app still works if the group entitlement
//  is missing (e.g. an unsigned local build).
//

import Foundation

public enum SharedStore {

    /// App Group identifier. Declared in every target's entitlements.
    public static let appGroupIdentifier = "group.com.bierchiller.app.shared"

    /// Notification posted (locally) whenever the shared session changes.
    public static let sessionDidChangeNotification = Notification.Name("BeerChillerSessionDidChange")

    public static let defaults: UserDefaults = {
        if let suite = UserDefaults(suiteName: appGroupIdentifier) {
            // Round-trip probe: an entitlement-less build hands back a suite that
            // silently drops writes on device. Verify before trusting it.
            let probeKey = "__beerchiller_probe"
            suite.set(true, forKey: probeKey)
            if suite.bool(forKey: probeKey) {
                suite.removeObject(forKey: probeKey)
                return suite
            }
        }
        return .standard
    }()

    // MARK: Keys

    enum Key {
        static let session = "chillSession"
        /// When this side last changed the session itself. Used to reject a stale
        /// application context that would otherwise resurrect a cleared run.
        static let sessionChangedAt = "chillSessionChangedAt"

        static let startTemp = "startTemp"
        static let targetTemp = "targetTemp"
        static let deviceTemp = "deviceTemp"
        static let deviceMode = "deviceMode"
        static let containerType = "containerType"
        static let volumeIndex = "volumeIndex"
        static let orientation = "orientation"
        static let visualStyle = "visualMode"
        static let appearance = "appearanceMode"
        static let temperatureUnit = "temperatureUnit"
    }

    // MARK: Session

    public static func loadSession() -> ChillSession? {
        guard let data = defaults.data(forKey: Key.session) else { return nil }
        return try? JSONDecoder().decode(ChillSession.self, from: data)
    }

    public static func save(_ session: ChillSession?) {
        if let session, let data = try? JSONEncoder().encode(session) {
            defaults.set(data, forKey: Key.session)
        } else {
            defaults.removeObject(forKey: Key.session)
        }
        defaults.set(Date().timeIntervalSince1970, forKey: Key.sessionChangedAt)
        NotificationCenter.default.post(name: sessionDidChangeNotification, object: nil)
    }

    /// Wall-clock time of this side's last session change, 0 if it never changed.
    public static var sessionChangedAt: Double {
        defaults.double(forKey: Key.sessionChangedAt)
    }

    #if DEBUG
    /// Seeds a session from a launch argument so UI tests can start from a given
    /// state without waiting out a real cooling time. Debug builds only.
    ///
    ///   -seedFinishedSession   a run that ended a minute ago
    ///   -seedRunningSession    a run that is 40 % through a 34-minute cool-down
    static func seedFromLaunchArgumentsIfRequested() {
        let arguments = ProcessInfo.processInfo.arguments
        let now = Date()

        func store(totalMinutes: Double, progress: Double, endedAgo: TimeInterval = 0) {
            let total = totalMinutes * 60
            let start = now.addingTimeInterval(-total * progress - endedAgo)
            save(ChillSession(startDate: start,
                              endDate: start.addingTimeInterval(total),
                              startTempC: 22, targetTempC: 8, deviceTempC: -18,
                              containerType: .bottle, volume: .small,
                              deviceMode: .freezer, orientation: .standing))
        }

        if arguments.contains("-seedFinishedSession") {
            store(totalMinutes: 34, progress: 1, endedAgo: 60)
        } else if arguments.contains("-seedRunningSession") {
            store(totalMinutes: 34, progress: 0.4)
        } else if arguments.contains("-seedNoSession") {
            save(nil)
        }
    }
    #endif

    // MARK: Small typed helpers

    static func int(_ key: String, default defaultValue: Int,
                    min minValue: Int, max maxValue: Int) -> Int {
        let hasValue = defaults.object(forKey: key) != nil
        return CoolingModel.restoreTemperaturePreference(
            hasSavedValue: hasValue,
            savedValue: defaults.integer(forKey: key),
            defaultValue: defaultValue,
            minValue: minValue,
            maxValue: maxValue
        )
    }

    static func enumValue<T: RawRepresentable>(_ key: String, default defaultValue: T) -> T
    where T.RawValue == Int {
        guard defaults.object(forKey: key) != nil,
              let value = T(rawValue: defaults.integer(forKey: key)) else {
            return defaultValue
        }
        return value
    }
}
