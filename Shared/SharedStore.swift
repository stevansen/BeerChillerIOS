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

    /// True when this process is actually a member of the App Group.
    ///
    /// `containerURL(forSecurityApplicationGroupIdentifier:)` is the only signal
    /// that answers this. A round-trip write-then-read does not: measured against
    /// a deliberately non-existent group, `UserDefaults(suiteName:)` hands back a
    /// working suite and the round-trip succeeds, because the writes land in a
    /// plist inside this app's own container. The data is simply invisible to the
    /// widget and the watch — the app keeps working and nothing is shared, which
    /// is the kind of defect noticed weeks later.
    ///
    ///     group.com.bierchiller.app.shared        containerURL present, round-trip true
    ///     group.com.bierchiller.app.doesnotexist  containerURL nil,     round-trip true
    ///
    /// Two notes for whoever adds another kind of shared storage, or a macOS or
    /// Mac Catalyst target. Both are identifiers that need a team prefix and fail
    /// quietly without one, and the two rules are not the same rule:
    ///
    /// * **App Groups** need the prefix on macOS and Mac Catalyst only —
    ///   `$(TeamIdentifierPrefix)group.…` — while iOS, watchOS and tvOS use the
    ///   identifier bare. A single shared literal is therefore wrong on the Mac
    ///   and right everywhere else, which is the worst shape a constant can have.
    /// * **Keychain access groups** need the prefix on *every* platform, and it
    ///   is a different build setting: `$(AppIdentifierPrefix)com.example.shared`.
    ///   The two prefixes usually expand to the same team identifier but are not
    ///   guaranteed to, so they are not interchangeable.
    ///
    /// Resolve such an identifier per platform instead of sharing one literal,
    /// and assert the thing itself — the container, or a keychain round trip
    /// against a second target — never the string.
    ///
    /// Neither applies today: there is no macOS or Catalyst target, and the app
    /// never touches the keychain. Checked rather than assumed — no `SecItem`
    /// call anywhere in the sources, and `keychain-access-groups` appears in none
    /// of the four entitlements files.
    public static var isSharingContainer: Bool {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) != nil
    }

    public static let defaults: UserDefaults = {
        if isSharingContainer, let suite = UserDefaults(suiteName: appGroupIdentifier) {
            return suite
        }
        // Unsigned or misconfigured build: keep working on standard defaults
        // rather than pretending the group is there.
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
    ///   -seedNoSession         nothing running
    ///   -seedStyle classic|beer          visual style
    ///   -seedAppearance system|light|dark
    ///
    /// The style and appearance arguments exist for the App Store screenshots:
    /// both live in the App Group, which `-key value` launch arguments cannot
    /// reach — those only populate the *standard* defaults' argument domain, and
    /// this app deliberately reads a suite so the widget and the watch see the
    /// same values. Editing the simulator's plist from outside is the
    /// alternative, and it loses races with `cfprefsd`.
    ///
    /// Called from both `AppSettings.init` and `ChillController.init` because
    /// either may come first depending on the target, so it runs at most once —
    /// a second pass would restart the seeded session's clock and shift the
    /// countdown between two screenshots that are supposed to match.
    private static var hasSeeded = false

    static func seedFromLaunchArgumentsIfRequested() {
        guard !hasSeeded else { return }
        hasSeeded = true

        let arguments = ProcessInfo.processInfo.arguments
        let now = Date()

        func value(after flag: String) -> String? {
            guard let index = arguments.firstIndex(of: flag),
                  arguments.index(after: index) < arguments.endIndex else { return nil }
            return arguments[arguments.index(after: index)]
        }

        if let style = value(after: "-seedStyle") {
            let styles: [String: VisualStyle] = ["classic": .classic, "beer": .beer]
            if let resolved = styles[style.lowercased()] {
                defaults.set(resolved.rawValue, forKey: Key.visualStyle)
            }
        }
        if let appearance = value(after: "-seedAppearance") {
            let modes: [String: AppearanceMode] = ["system": .system, "light": .light,
                                                   "dark": .dark]
            if let resolved = modes[appearance.lowercased()] {
                defaults.set(resolved.rawValue, forKey: Key.appearance)
            }
        }

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
