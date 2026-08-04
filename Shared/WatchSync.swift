//
//  WatchSync.swift
//  BeerCHILLER
//
//  Keeps the session in step between iPhone and Apple Watch.
//
//  Both sides are usable on their own: each stores the session locally and each
//  can start or stop a run. `transferUserInfo` is used rather than `sendMessage`
//  so a change still arrives when the counterpart app is not in the foreground.
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
    }

    #if canImport(WatchConnectivity)
    private var session: WCSession? {
        WCSession.isSupported() ? WCSession.default : nil
    }
    #endif

    public func activate() {
        #if canImport(WatchConnectivity)
        guard let session else { return }
        session.delegate = self
        session.activate()
        #endif
    }

    /// Set when a send arrived before the session finished activating.
    private var pendingPayload: [String: Any]?

    /// Pushes the new state to the counterpart. `nil` means "timer stopped".
    public func send(session chillSession: ChillSession?) {
        #if canImport(WatchConnectivity)
        var payload: [String: Any] = [:]
        if let chillSession, let data = try? JSONEncoder().encode(chillSession) {
            payload[PayloadKey.session] = data
        } else {
            payload[PayloadKey.cleared] = true
        }

        guard let session else { return }

        // Activation is asynchronous. Dropping the update when it has not
        // finished yet loses the hand-off for anyone who starts a timer in the
        // first moment after launch, silently — so hold it and flush on
        // activation instead.
        guard session.activationState == .activated else {
            pendingPayload = payload
            session.activate()
            return
        }
        session.transferUserInfo(payload)
        #endif
    }

    #if canImport(WatchConnectivity)
    private func flushPendingPayload(on session: WCSession) {
        guard let payload = pendingPayload,
              session.activationState == .activated else { return }
        pendingPayload = nil
        session.transferUserInfo(payload)
    }
    #endif

    private func apply(_ payload: [String: Any]) {
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
}

#if canImport(WatchConnectivity)
extension WatchSync: WCSessionDelegate {

    // `@objc` is spelled out on every one of these.
    //
    // These satisfy an `@objc optional` protocol requirement, and Swift only
    // infers `@objc` when it recognises the method as doing so. Writing the
    // parameter with the protocol's default value — `userInfo: [String: Any] = [:]`
    // — is enough to lose that match: the method then compiles, looks correct, and
    // is simply never called, because the selector `session:didReceiveUserInfo:`
    // is not exposed to the Objective-C runtime. That is exactly what happened
    // here: transfers were sent and dequeued by WatchConnectivity while the watch
    // app never saw them.
    @objc public func session(_ session: WCSession,
                              activationDidCompleteWith state: WCSessionActivationState,
                              error: Error?) {
        flushPendingPayload(on: session)
    }

    @objc public func session(_ session: WCSession,
                              didReceiveUserInfo userInfo: [String: Any]) {
        DispatchQueue.main.async { [weak self] in
            self?.apply(userInfo)
        }
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
