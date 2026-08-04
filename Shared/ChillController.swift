//
//  ChillController.swift
//  BeerCHILLER
//
//  Owns the running timer: persistence, the completion notification, the widget
//  timelines, the Live Activity and the watch handoff.
//
//  Nothing here keeps a countdown in memory. The session is a pair of dates in
//  shared storage; every consumer derives its own view of "now". That is what
//  makes the timer survive termination and reboot.
//

import Foundation
import Combine

#if canImport(WidgetKit)
import WidgetKit
#endif
#if canImport(ActivityKit)
import ActivityKit
#endif
#if canImport(UserNotifications)
import UserNotifications
#endif

public final class ChillController: ObservableObject {

    public static let shared = ChillController(settings: .shared)

    /// The running session, or `nil` when idle.
    @Published public private(set) var session: ChillSession?
    /// Ticks while a session runs, to drive the countdown.
    @Published public private(set) var now: Date = Date()
    /// Set when the target temperature was reached and the user has not
    /// acknowledged it yet.
    @Published public var isShowingAlarm = false

    public let settings: AppSettings

    private var timer: AnyCancellable?
    private var observers: [NSObjectProtocol] = []

    public init(settings: AppSettings) {
        self.settings = settings
        #if DEBUG
        SharedStore.seedFromLaunchArgumentsIfRequested()
        #endif
        self.session = SharedStore.loadSession()
        reconcileOnLaunch()
        startTickingIfNeeded()

        let observer = NotificationCenter.default.addObserver(
            forName: SharedStore.sessionDidChangeNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.reloadFromStore()
        }
        observers.append(observer)

        #if DEBUG
        // `-startTimerOnLaunch` goes through the full start path — notification,
        // Live Activity and the watch handoff — so the hand-off can be exercised
        // without driving the UI.
        if ProcessInfo.processInfo.arguments.contains("-startTimerOnLaunch") {
            DispatchQueue.main.async { [weak self] in _ = self?.start() }
        }
        #endif
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    // MARK: - Derived state

    public var isRunning: Bool {
        guard let session else { return false }
        return !session.isFinished(at: now)
    }

    public var remainingSeconds: Double {
        session?.remainingSeconds(at: now) ?? 0
    }

    public var progress: Double {
        session?.progress(at: now) ?? 0
    }

    /// Live estimate while running; the plain calculation while idle.
    public var currentTemperatureC: Double? {
        guard let session else { return nil }
        return session.currentTemperatureC(at: now)
    }

    // MARK: - Lifecycle

    /// Starts a run from the current settings. Returns `false` if the inputs do
    /// not produce a valid cooling time.
    @discardableResult
    public func start() -> Bool {
        guard let newSession = settings.makeSession() else { return false }
        session = newSession
        SharedStore.save(newSession)
        isShowingAlarm = false

        scheduleCompletionNotification(for: newSession)
        startLiveActivity(for: newSession)
        reloadWidgets()
        startTickingIfNeeded()
        WatchSync.shared.send(session: newSession)
        return true
    }

    public func stop() {
        session = nil
        SharedStore.save(nil)
        isShowingAlarm = false

        cancelCompletionNotification()
        endLiveActivity()
        reloadWidgets()
        stopTicking()
        WatchSync.shared.send(session: nil)
    }

    /// Called when the user dismisses the "your beer is cold" screen.
    public func acknowledgeAlarm() {
        isShowingAlarm = false
        stop()
    }

    /// Re-reads shared storage — used when the widget, the watch or another
    /// process changed the session.
    public func reloadFromStore() {
        let stored = SharedStore.loadSession()
        guard stored != session else { return }
        session = stored
        startTickingIfNeeded()
    }

    /// On launch a stored session may already be finished (app was killed, phone
    /// was off). Show the alarm state instead of a stale countdown.
    private func reconcileOnLaunch() {
        guard let session else { return }
        if session.isFinished() {
            isShowingAlarm = true
        }
    }

    // MARK: - Ticking

    private func startTickingIfNeeded() {
        guard session != nil, timer == nil else {
            if session == nil { stopTicking() }
            return
        }
        now = Date()
        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] date in self?.tick(date) }
    }

    private func stopTicking() {
        timer?.cancel()
        timer = nil
    }

    private func tick(_ date: Date) {
        now = date
        guard let session else {
            stopTicking()
            return
        }
        if session.isFinished(at: date) {
            isShowingAlarm = true
            stopTicking()
            endLiveActivity()
            reloadWidgets()
        } else {
            updateLiveActivity(for: session, at: date)
        }
    }

    /// Call from `scenePhase` changes: recompute immediately instead of waiting
    /// for the next tick.
    public func refreshNow() {
        now = Date()
        reloadFromStore()
        if let session, session.isFinished(at: now) {
            isShowingAlarm = true
        }
        startTickingIfNeeded()
    }

    // MARK: - Notifications

    private static let completionRequestIdentifier = "beerchiller.completion"

    private func scheduleCompletionNotification(for session: ChillSession) {
        #if canImport(UserNotifications)
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.completionRequestIdentifier])

        let content = UNMutableNotificationContent()
        content.title = Formatting.localized("alarm_ringing")
        content.body = Formatting.localized("alarm_detail")
        content.sound = .default
        content.interruptionLevel = .timeSensitive

        let interval = max(1, session.endDate.timeIntervalSinceNow)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(identifier: Self.completionRequestIdentifier,
                                           content: content,
                                           trigger: trigger)
        center.add(request)
        #endif
    }

    private func cancelCompletionNotification() {
        #if canImport(UserNotifications)
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [Self.completionRequestIdentifier])
        #endif
    }

    /// Asks for notification permission. Called the first time a timer starts,
    /// so the prompt has obvious context.
    public func requestNotificationAuthorizationIfNeeded() {
        #if canImport(UserNotifications)
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else { return }
            center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        }
        #endif
    }

    // MARK: - Widgets

    private func reloadWidgets() {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    // MARK: - Live Activity

    #if canImport(ActivityKit) && os(iOS)
    @available(iOS 16.1, *)
    private var currentActivity: Activity<ChillActivityAttributes>? {
        Activity<ChillActivityAttributes>.activities.first
    }
    #endif

    private func startLiveActivity(for session: ChillSession) {
        #if canImport(ActivityKit) && os(iOS)
        guard #available(iOS 16.1, *) else { return }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        // Never stack activities.
        Task { await endAllActivities() }

        let attributes = ChillActivityAttributes(session: session)
        let state = ChillActivityAttributes.ContentState(
            currentTemperatureC: session.currentTemperatureC()
        )
        do {
            if #available(iOS 16.2, *) {
                _ = try Activity.request(
                    attributes: attributes,
                    content: ActivityContent(state: state, staleDate: session.endDate),
                    pushType: nil
                )
            } else {
                _ = try Activity.request(attributes: attributes,
                                         contentState: state,
                                         pushType: nil)
            }
        } catch {
            // A Live Activity is a nice-to-have; the notification is the contract.
        }
        #endif
    }

    private func updateLiveActivity(for session: ChillSession, at date: Date) {
        #if canImport(ActivityKit) && os(iOS)
        guard #available(iOS 16.1, *) else { return }
        // The countdown itself is rendered by the system from the date range;
        // only the temperature estimate needs pushing, and once a minute is plenty.
        guard Int(date.timeIntervalSince1970) % 60 == 0 else { return }
        guard let activity = currentActivity else { return }
        let state = ChillActivityAttributes.ContentState(
            currentTemperatureC: session.currentTemperatureC(at: date)
        )
        Task {
            if #available(iOS 16.2, *) {
                await activity.update(ActivityContent(state: state, staleDate: session.endDate))
            } else {
                await activity.update(using: state)
            }
        }
        #endif
    }

    private func endLiveActivity() {
        #if canImport(ActivityKit) && os(iOS)
        guard #available(iOS 16.1, *) else { return }
        Task { await endAllActivities() }
        #endif
    }

    #if canImport(ActivityKit) && os(iOS)
    @available(iOS 16.1, *)
    private func endAllActivities() async {
        for activity in Activity<ChillActivityAttributes>.activities {
            if #available(iOS 16.2, *) {
                await activity.end(nil, dismissalPolicy: .immediate)
            } else {
                await activity.end(dismissalPolicy: .immediate)
            }
        }
    }
    #endif
}
