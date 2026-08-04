//
//  WatchSync.swift
//  BeerCHILLER
//
//  Keeps the session in step between iPhone and Apple Watch.
//
//  Both sides are usable on their own: each stores the session locally and each
//  can start or stop a run.
//
//  The state is carried as WatchConnectivity's *application context* rather than
//  as a user-info transfer. Two reasons, and the second is what made the
//  hand-off work at all:
//
//  1. It matches the data. There is exactly one current run; a queue of ordered
//     messages is the wrong shape for "here is the latest state", and a queue
//     also replays stale runs when the counterpart has been asleep.
//  2. It can be *pulled*. `receivedApplicationContext` is readable at any time,
//     so the receiver does not depend on a delegate callback arriving. With
//     `transferUserInfo` the phone demonstrably sent the payload and the watch's
//     WCSession dequeued it, yet `didReceiveUserInfo` never ran — reading the
//     context on activation and on every foreground sidesteps that entirely.
//
//  `sendMessage` is used on top when the counterpart is reachable, purely so an
//  open app updates immediately instead of at the system's discretion.
//

import Foundation
#if canImport(WatchConnectivity)
import WatchConnectivity
#endif

public final class WatchSync: NSObject, ObservableObject {

    public static let shared = WatchSync()

    private enum PayloadKey {
        static let session = "session"
        static let cleared = "cleared"
        /// Lets the receiver ignore a context it has already applied, and makes
        /// two successive identical contexts distinguishable.
        static let sentAt = "sentAt"
    }

    #if canImport(WatchConnectivity)
    private var session: WCSession? {
        WCSession.isSupported() ? WCSession.default : nil
    }
    #endif

    /// Set when a send arrived before the session finished activating.
    private var pendingPayload: [String: Any]?
    /// Timestamp of the last context applied, so the same one is not re-applied.
    private var lastAppliedAt: Double = 0

    public func activate() {
        #if canImport(WatchConnectivity)
        guard let session else { return }
        session.delegate = self
        session.activate()
        #endif
    }

    // MARK: - Sending

    /// Pushes the new state to the counterpart. `nil` means "timer stopped".
    public func send(session chillSession: ChillSession?) {
        #if canImport(WatchConnectivity)
        var payload: [String: Any] = [PayloadKey.sentAt: Date().timeIntervalSince1970]
        if let chillSession, let data = try? JSONEncoder().encode(chillSession) {
            payload[PayloadKey.session] = data
        } else {
            payload[PayloadKey.cleared] = true
        }

        guard let session else { return }

        // Activation is asynchronous. Dropping the update while it is still in
        // flight would silently lose the hand-off for anyone who starts a timer
        // in the first moment after launch.
        guard session.activationState == .activated else {
            pendingPayload = payload
            session.activate()
            return
        }
        deliver(payload, over: session)
        #endif
    }

    #if canImport(WatchConnectivity)
    private func deliver(_ payload: [String: Any], over session: WCSession) {
        do {
            try session.updateApplicationContext(payload)
        } catch {
            // Keep it for the next activation rather than losing the update.
            pendingPayload = payload
        }
        // Immediate nudge when the counterpart is on screen; best-effort only,
        // the context above is what actually guarantees the state arrives.
        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil, errorHandler: nil)
        }
    }

    private func flushPendingPayload(on session: WCSession) {
        guard let payload = pendingPayload,
              session.activationState == .activated else { return }
        pendingPayload = nil
        deliver(payload, over: session)
    }
    #endif

    // MARK: - Receiving

    /// Reads whatever the counterpart last sent, without waiting for a callback.
    /// Called on activation, on reachability changes and whenever the app comes
    /// to the foreground.
    public func adoptReceivedContext() {
        #if canImport(WatchConnectivity)
        guard let session, session.activationState == .activated else { return }
        let context = session.receivedApplicationContext
        guard !context.isEmpty else { return }
        apply(context)
        #endif
    }

    private func apply(_ payload: [String: Any]) {
        // Ignore a context that has already been applied — `adoptReceivedContext`
        // is called from several places and the same context stays readable.
        let sentAt = payload[PayloadKey.sentAt] as? Double ?? 0
        if sentAt > 0, sentAt <= lastAppliedAt { return }

        // The application context stays readable indefinitely, so a freshly
        // launched app would otherwise re-adopt whatever the counterpart last
        // sent — resurrecting a run the user had already cleared on this side.
        // Only a context newer than this side's own last change may win.
        if sentAt > 0, sentAt < SharedStore.sessionChangedAt { return }

        lastAppliedAt = max(lastAppliedAt, sentAt)

        if payload[PayloadKey.cleared] as? Bool == true {
            SharedStore.save(nil)
            return
        }
        guard let data = payload[PayloadKey.session] as? Data,
              let incoming = try? JSONDecoder().decode(ChillSession.self, from: data) else {
            return
        }
        SharedStore.save(incoming)
    }

    private func applyOnMain(_ payload: [String: Any]) {
        DispatchQueue.main.async { [weak self] in
            self?.apply(payload)
        }
    }
}

#if canImport(WatchConnectivity)
extension WatchSync: WCSessionDelegate {

    // `@objc` is spelled out on every one of these.
    //
    // These satisfy `@objc optional` protocol requirements, and Swift only infers
    // `@objc` when it recognises a method as doing so. Writing a parameter with
    // the protocol's own default value — `userInfo: [String: Any] = [:]` — is
    // enough to lose that match: the method then compiles, looks correct, and is
    // never called, because the selector is not exposed to the Objective-C
    // runtime.

    @objc public func session(_ session: WCSession,
                              activationDidCompleteWith state: WCSessionActivationState,
                              error: Error?) {
        flushPendingPayload(on: session)
        // Pull whatever arrived while this side was not running.
        let context = session.receivedApplicationContext
        if !context.isEmpty {
            applyOnMain(context)
        }
    }

    @objc public func sessionReachabilityDidChange(_ session: WCSession) {
        flushPendingPayload(on: session)
        let context = session.receivedApplicationContext
        if !context.isEmpty {
            applyOnMain(context)
        }
    }

    @objc public func session(_ session: WCSession,
                              didReceiveApplicationContext applicationContext: [String: Any]) {
        applyOnMain(applicationContext)
    }

    @objc public func session(_ session: WCSession,
                              didReceiveMessage message: [String: Any]) {
        applyOnMain(message)
    }

    @objc public func session(_ session: WCSession,
                              didReceiveUserInfo userInfo: [String: Any]) {
        applyOnMain(userInfo)
    }

    #if os(iOS)
    @objc public func sessionDidBecomeInactive(_ session: WCSession) {}

    @objc public func sessionDidDeactivate(_ session: WCSession) {
        // Re-activate so a switched watch keeps syncing.
        session.activate()
    }
    #endif
}
#endif
