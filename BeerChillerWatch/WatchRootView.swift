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
        VStack(spacing: 10) {
            Image(systemName: "snowflake")
                .font(.system(size: 34))
                .foregroundStyle(palette.accent)
            Text(LocalizedStringKey("alarm_ringing"))
                .font(.headline)
                .multilineTextAlignment(.center)
                .foregroundStyle(palette.primaryText)
            Button {
                controller.acknowledgeAlarm()
            } label: {
                Text(LocalizedStringKey("stop_alarm"))
                    .frame(maxWidth: .infinity)
            }
            .tint(palette.accent)
        }
    }

    private func runningState(_ session: ChillSession) -> some View {
        VStack(spacing: 8) {
            ProgressView(value: session.progress(at: controller.now)) {
                Text(LocalizedStringKey("remaining_time"))
                    .font(.caption2)
                    .foregroundStyle(palette.secondaryText)
            }
            .tint(palette.dialProgress)

            Text(timerInterval: controller.now...session.endDate, countsDown: true)
                .font(.system(size: 32, weight: .semibold))
                .monospacedDigit()
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .foregroundStyle(palette.primaryText)

            Text(Formatting.temperature(celsius: session.currentTemperatureC(at: controller.now),
                                        unit: settings.temperatureUnit))
                .font(.footnote)
                .foregroundStyle(palette.secondaryText)

            Text(Formatting.endsAt(session.endDate))
                .font(.caption2)
                .foregroundStyle(palette.secondaryText)

            Button {
                controller.stop()
            } label: {
                Text(LocalizedStringKey("stop"))
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var idleState: some View {
        VStack(spacing: 8) {
            Text(LocalizedStringKey("cooling_time"))
                .font(.caption2)
                .foregroundStyle(palette.secondaryText)

            Text(settings.coolingMinutes.map(Formatting.minutes)
                 ?? Formatting.localized("check_inputs_short"))
                .font(.system(size: 30, weight: .semibold))
                .monospacedDigit()
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .foregroundStyle(palette.primaryText)

            Button {
                controller.requestNotificationAuthorizationIfNeeded()
                controller.start()
            } label: {
                Text(LocalizedStringKey("watch_start"))
                    .frame(maxWidth: .infinity)
            }
            .tint(palette.accent)
            .disabled((settings.coolingMinutes ?? 0) <= 0)
        }
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
