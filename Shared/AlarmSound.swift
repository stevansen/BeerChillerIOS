//
//  AlarmSound.swift
//  BeerCHILLER
//
//  The sound the app plays itself while the alarm screen is up.
//
//  This existed as a gap rather than a decision: the app scheduled a notification
//  for the moment the beer is ready, and if you happened to have the app open the
//  alarm screen appeared in complete silence. Nothing announced it. Sitting next
//  to the phone and looking away was enough to miss it.
//
//  Deliberately separate from the notification and from AlarmKit:
//
//    * a notification only fires when the app is *not* frontmost
//    * AlarmKit needs iOS 26 and the user's permission
//
//  so this is the one part that works everywhere, on every supported version.
//

import Foundation
#if canImport(AVFoundation) && !os(watchOS)
import AVFoundation
#endif

public final class AlarmSound {

    public static let shared = AlarmSound()

    #if canImport(AVFoundation) && !os(watchOS)
    private var player: AVAudioPlayer?
    #endif

    private init() {}

    /// Starts the looping tone. Safe to call when it is already playing.
    public func start() {
        #if canImport(AVFoundation) && !os(watchOS)
        guard player?.isPlaying != true else { return }
        guard let url = Bundle.main.url(forResource: "alarm", withExtension: "wav") else {
            return
        }

        // `.playback` rather than `.ambient` is what makes the alarm audible with
        // the ring/silent switch set to silent. That is the whole point of an
        // alarm — the Clock app behaves the same way — but it is also why the
        // sound stops the moment the run is acknowledged: an app that keeps
        // playing over the silent switch and does not stop is a bug report.
        //
        // `.duckOthers` lowers music rather than killing it, so the tone is heard
        // without ending whatever the user was listening to.
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [.duckOthers])
        try? session.setActive(true)

        guard let player = try? AVAudioPlayer(contentsOf: url) else { return }
        player.numberOfLoops = -1
        player.volume = 1
        player.prepareToPlay()
        player.play()
        self.player = player
        #endif
    }

    public func stop() {
        #if canImport(AVFoundation) && !os(watchOS)
        player?.stop()
        player = nil
        // Hand the session back so music that was ducked returns to full volume.
        try? AVAudioSession.sharedInstance()
            .setActive(false, options: .notifyOthersOnDeactivation)
        #endif
    }

    public var isPlaying: Bool {
        #if canImport(AVFoundation) && !os(watchOS)
        return player?.isPlaying == true
        #else
        return false
        #endif
    }
}
