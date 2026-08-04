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

struct WatchInputsView: View {

    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var controller: ChillController
    @Environment(\.palette) private var palette

    var body: some View {
        List {
            Picker(selection: $settings.containerType) {
                Text(LocalizedStringKey("container_bottle")).tag(ContainerType.bottle)
                Text(LocalizedStringKey("container_can")).tag(ContainerType.can)
            } label: {
                Text(LocalizedStringKey("picker_container"))
            }

            Picker(selection: $settings.volume) {
                ForEach(VolumeOption.allCases.filter(settings.isVolumeAvailable), id: \.self) {
                    Text(Formatting.volume($0)).tag($0)
                }
            } label: {
                Text(LocalizedStringKey("bottle_volume"))
            }

            Picker(selection: $settings.deviceMode) {
                Text(LocalizedStringKey("freezer")).tag(DeviceMode.freezer)
                Text(LocalizedStringKey("fridge")).tag(DeviceMode.fridge)
            } label: {
                Text(LocalizedStringKey("picker_appliance"))
            }

            Picker(selection: $settings.orientation) {
                Text(LocalizedStringKey("orientation_lying")).tag(ContainerOrientation.lying)
                Text(LocalizedStringKey("orientation_standing")).tag(ContainerOrientation.standing)
            } label: {
                Text(LocalizedStringKey("picker_position"))
            }

            stepper(titleKey: "start_temperature",
                    value: settings.startTempC,
                    range: CoolingModel.minStartTempC...CoolingModel.maxStartTempC) {
                settings.stepStartTemp($0)
            }

            stepper(titleKey: "target_temperature",
                    value: settings.targetTempC,
                    range: CoolingModel.minTargetTempC...CoolingModel.maxTargetTempC) {
                settings.stepTargetTemp($0)
            }

            stepper(titleKey: "device_temperature",
                    value: settings.deviceTempC,
                    range: CoolingModel.minDeviceTempC...CoolingModel.maxDeviceTempC) {
                settings.stepDeviceTemp($0)
            }
        }
        .disabled(controller.isRunning)
    }

    private func stepper(titleKey: String,
                         value: Int,
                         range: ClosedRange<Int>,
                         onStep: @escaping (Int) -> Void) -> some View {
        Stepper {
            VStack(alignment: .leading, spacing: 1) {
                Text(LocalizedStringKey(titleKey))
                    .font(.caption2)
                    .foregroundStyle(palette.secondaryText)
                Text(Formatting.temperature(celsius: value, unit: settings.temperatureUnit))
                    .font(.body.weight(.medium))
                    .monospacedDigit()
            }
        } onIncrement: {
            if value < range.upperBound { onStep(1) }
        } onDecrement: {
            if value > range.lowerBound { onStep(-1) }
        }
    }
}
