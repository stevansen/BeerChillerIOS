//
//  WatchRootView.swift
//  BeerCHILLER Watch App
//
//  Two tabs: the timer, and the inputs. watchOS is always dark, so the palette
//  is resolved with `.dark` and only the two visual styles differ.
//

import SwiftUI
import WatchKit

struct WatchRootView: View {

    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var controller: ChillController

    private var palette: Palette {
        Palette.resolve(style: settings.visualStyle, scheme: .dark)
    }

    var body: some View {
        TabView {
            WatchTimerView()
            WatchInputsView()
        }
        .tabViewStyle(.page)
        .environment(\.palette, palette)
        .onChange(of: controller.isShowingAlarm) { isShowing in
            // A distinct haptic when the beer is ready.
            if isShowing {
                WKInterfaceDevice.current().play(.notification)
            }
        }
    }
}

// MARK: - Timer tab

struct WatchTimerView: View {

    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var controller: ChillController
    @Environment(\.palette) private var palette

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                if controller.isShowingAlarm {
                    readyState
                } else if let session = controller.session, controller.isRunning {
                    runningState(session)
                } else {
                    idleState
                }
            }
            .padding(.horizontal, 4)
        }
        .background(
            LinearGradient(colors: [palette.background, palette.backgroundSecondary],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        )
    }

    private var readyState: some View {
        VStack(spacing: 6) {
            ChillRing(progress: 1, isRunning: true) {
                Image(systemName: "snowflake")
                    .font(.system(size: 30, weight: .light))
                    .foregroundStyle(palette.accent)
            }

            Text(LocalizedStringKey("alarm_ringing"))
                .font(.footnote.weight(.semibold))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .foregroundStyle(palette.primaryText)

            Button {
                controller.acknowledgeAlarm()
            } label: {
                Text(LocalizedStringKey("stop_alarm"))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity)
            }
            .tint(palette.accent)
        }
    }

    private func runningState(_ session: ChillSession) -> some View {
        VStack(spacing: 6) {
            ChillRing(progress: session.progress(at: controller.now), isRunning: true) {
                VStack(spacing: 0) {
                    Text(timerInterval: controller.now...session.endDate, countsDown: true)
                        .font(.system(size: 30, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                        .foregroundStyle(palette.primaryText)

                    Text(Formatting.temperature(
                        celsius: session.currentTemperatureC(at: controller.now),
                        unit: settings.temperatureUnit))
                        .font(.caption2)
                        .monospacedDigit()
                        .foregroundStyle(palette.secondaryText)
                }
                .padding(.horizontal, 4)
            }

            Text(Formatting.endsAt(session.endDate))
                .font(.caption2)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .foregroundStyle(palette.secondaryText)

            Button {
                controller.stop()
            } label: {
                Text(LocalizedStringKey("stop"))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var idleState: some View {
        VStack(spacing: 6) {
            ChillRing(progress: 0, isRunning: false) {
                VStack(spacing: 0) {
                    Text(settings.coolingMinutes.map(Formatting.minutes)
                         ?? Formatting.localized("check_inputs_short"))
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                        .foregroundStyle(palette.primaryText)

                    Text(LocalizedStringKey("cooling_time"))
                        .font(.system(size: 10))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(palette.secondaryText)
                }
                .padding(.horizontal, 4)
            }

            Button {
                controller.requestNotificationAuthorizationIfNeeded()
                controller.start()
            } label: {
                Text(LocalizedStringKey("watch_start"))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
            }
            .tint(palette.accent)
            .disabled((settings.coolingMinutes ?? 0) <= 0)
        }
    }
}

/// The watch's counterpart to the phone's dial: a progress ring with the value
/// inside it. A ring rather than a linear `ProgressView` because that is the
/// idiom watchOS uses for timers, and because it puts the number in the middle of
/// a round display instead of leaving the corners empty.
///
/// Sized against the screen so it fits a 40 mm watch without scrolling — the ring
/// plus the end time plus the button have to live in about 170 pt of height.
private struct ChillRing<Content: View>: View {
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var progress: Double
    var isRunning: Bool
    @ViewBuilder var content: Content

    /// Sized from the actual screen instead of the available space: inside a
    /// scroll view the available height is unbounded, so a self-sizing ring grew
    /// until it pushed the end time and the stop button off the display.
    private var side: CGFloat {
        let bounds = WKInterfaceDevice.current().screenBounds
        // 0.45 leaves room for the end time and a full-height button below on a
        // 40 mm watch; at 0.52 the button was clipped by the bottom bezel.
        return min(bounds.width - 16, bounds.height * 0.45)
    }

    var body: some View {
        let lineWidth = max(5, side * 0.075)

        return ZStack {
            Circle()
                .stroke(palette.dialTrack, lineWidth: lineWidth)

            if isRunning {
                Circle()
                    .trim(from: 0, to: max(0.001, min(progress, 1)))
                    .stroke(palette.dialProgress,
                            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(reduceMotion ? nil : .linear(duration: 0.9),
                               value: progress)
            }

            content
        }
        .frame(width: side, height: side)
    }
}

// MARK: - Inputs tab

/// Seven settings on a screen that shows three rows at a time, so the shape of
/// each row matters.
///
/// The three either/or choices — container, position, appliance — used to be
/// `Picker`s, which on watchOS push a whole selection screen to flip one of two
/// values. They are now rows that toggle in place: one tap instead of tap,
/// choose, go back. Volume keeps a picker because it has three options.
///
/// The volume row is also no longer labelled "bottle size"; that was simply wrong
/// with a can selected, and on the watch the label sits right next to the value
/// where the contradiction is obvious.
struct WatchInputsView: View {

    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var controller: ChillController
    @Environment(\.palette) private var palette

    var body: some View {
        List {
            WatchToggleRow(titleKey: "picker_container",
                           value: settings.containerType == .bottle
                               ? Formatting.localized("container_bottle")
                               : Formatting.localized("container_can")) {
                settings.containerType = settings.containerType == .bottle ? .can : .bottle
            }

            // Cycles rather than picking: a `Picker` put the label above the value
            // while every other row here puts the value first, and it pushed a
            // screen for what is at most three options. Cycling keeps all four
            // choice rows identical in look and in behaviour.
            WatchToggleRow(titleKey: "picker_volume",
                           value: Formatting.volume(settings.volume)) {
                let available = VolumeOption.allCases.filter(settings.isVolumeAvailable)
                guard let index = available.firstIndex(of: settings.volume) else {
                    settings.volume = available.first ?? .small
                    return
                }
                settings.volume = available[(index + 1) % available.count]
            }

            WatchToggleRow(titleKey: "picker_appliance",
                           value: settings.deviceMode == .freezer
                               ? Formatting.localized("freezer")
                               : Formatting.localized("fridge")) {
                settings.deviceMode = settings.deviceMode == .freezer ? .fridge : .freezer
            }

            WatchToggleRow(titleKey: "picker_position",
                           value: settings.orientation == .standing
                               ? Formatting.localized("orientation_standing")
                               : Formatting.localized("orientation_lying")) {
                settings.orientation = settings.orientation == .standing ? .lying : .standing
            }

            temperatureStepper(shortKey: "watch_temp_start",
                               spokenKey: "start_temperature",
                               value: settings.startTempC,
                               range: CoolingModel.minStartTempC...CoolingModel.maxStartTempC,
                               onStep: settings.stepStartTemp)

            temperatureStepper(shortKey: "watch_temp_target",
                               spokenKey: "target_temperature",
                               value: settings.targetTempC,
                               range: CoolingModel.minTargetTempC...CoolingModel.maxTargetTempC,
                               onStep: settings.stepTargetTemp)

            temperatureStepper(shortKey: "picker_appliance",
                               spokenKey: "device_temperature",
                               value: settings.deviceTempC,
                               range: CoolingModel.minDeviceTempC...CoolingModel.maxDeviceTempC,
                               onStep: settings.stepDeviceTemp)
        }
        .disabled(controller.isRunning)
    }

    /// `Stepper` is kept for the temperatures rather than a toggle: they have a
    /// range, and on watchOS a focused Stepper is driven by the Digital Crown,
    /// which beats tapping ±1 twenty times. The value leads and the label is
    /// secondary, because the value is what you came to read.
    /// `shortKey` is what the row shows; `spokenKey` is the full wording VoiceOver
    /// announces, so shortening the visible label costs nothing in clarity.
    private func temperatureStepper(shortKey: String,
                                    spokenKey: String,
                                    value: Int,
                                    range: ClosedRange<Int>,
                                    onStep: @escaping (Int) -> Void) -> some View {
        Stepper {
            VStack(alignment: .leading, spacing: 0) {
                Text(Formatting.temperature(celsius: value, unit: settings.temperatureUnit))
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(palette.primaryText)

                Text(LocalizedStringKey(shortKey))
                    .font(.caption2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .foregroundStyle(palette.secondaryText)
            }
        } onIncrement: {
            if value < range.upperBound { onStep(1) }
        } onDecrement: {
            if value > range.lowerBound { onStep(-1) }
        }
        .accessibilityLabel(Text(LocalizedStringKey(spokenKey)))
        .accessibilityValue(Text(Formatting.temperature(celsius: value,
                                                        unit: settings.temperatureUnit)))
    }
}

/// An either/or setting that flips on tap instead of pushing a selection screen.
private struct WatchToggleRow: View {
    @Environment(\.palette) private var palette

    var titleKey: String
    var value: String
    var toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            HStack(spacing: 6) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(value)
                        .font(.body.weight(.medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(palette.primaryText)

                    Text(LocalizedStringKey(titleKey))
                        .font(.caption2)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(palette.secondaryText)
                }

                Spacer(minLength: 4)

                // Signals that the row cycles rather than opening something.
                Image(systemName: "arrow.trianglehead.2.clockwise")
                    .font(.caption)
                    .foregroundStyle(palette.secondaryText)
                    .accessibilityHidden(true)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(LocalizedStringKey(titleKey)))
        .accessibilityValue(Text(value))
        .accessibilityHint(Text(LocalizedStringKey("watch_toggle_hint")))
    }
}
