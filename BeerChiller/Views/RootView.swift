//
//  RootView.swift
//  BeerCHILLER
//
//  Layout host. Three arrangements share one set of components:
//
//   * compact width, tall      → single column (iPhone portrait)
//   * compact/regular, short   → two columns, dial beside the controls
//                                (iPhone landscape)
//   * regular width, tall      → single column with a larger dial and wider
//                                margins (iPad portrait, Split View)
//

import SwiftUI

struct RootView: View {

    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var controller: ChillController
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// One sheet, selected by case.
    ///
    /// This replaced four separate `.sheet` modifiers stacked on the same view.
    /// That arrangement is a documented SwiftUI fragility — one presentation per
    /// view is the supported shape — but to be clear about the evidence: the four
    /// sheet version was *not* observed failing. It was replaced defensively after
    /// a stale simulator screenshot made it look as though the alarm sheet never
    /// appeared. Both forms present the alarm correctly on relaunch after the end
    /// time; this one is simply the arrangement Apple supports.
    private enum ActiveSheet: Int, Identifiable {
        case settings, help, info, alarm
        var id: Int { rawValue }
    }

    @State private var activeSheet: ActiveSheet?

    private var palette: Palette {
        Palette.resolve(style: settings.visualStyle, scheme: colorScheme)
    }

    var body: some View {
        GeometryReader { geometry in
            let isWide = geometry.size.width > geometry.size.height
            let isRegular = horizontalSizeClass == .regular

            ZStack {
                ThemedBackground()

                Group {
                    if isWide {
                        wideLayout(geometry: geometry, isRegular: isRegular)
                    } else {
                        tallLayout(geometry: geometry, isRegular: isRegular)
                    }
                }
                .padding(.horizontal, isRegular ? 40 : 20)
            }
        }
        .environment(\.palette, palette)
        .sheet(item: $activeSheet) { sheet in
            Group {
                switch sheet {
                case .settings: SettingsView()
                case .help:     HelpView()
                case .info:     InfoView(onOpenHelp: { activeSheet = .help })
                case .alarm:    AlarmView()
                }
            }
            .environment(\.palette, palette)
        }
        // The alarm is driven by the controller rather than by a tap, so it is
        // mirrored into `activeSheet` both on launch and whenever it changes.
        .onAppear {
            if controller.isShowingAlarm { activeSheet = .alarm }
        }
        .onChange(of: controller.isShowingAlarm) { isShowing in
            if isShowing {
                activeSheet = .alarm
            } else if activeSheet == .alarm {
                activeSheet = nil
            }
        }
        .onChange(of: activeSheet) { sheet in
            // Dismissing the alarm sheet by any route acknowledges the alarm.
            if sheet != .alarm && controller.isShowingAlarm {
                controller.acknowledgeAlarm()
            }
        }
    }

    // MARK: Layouts

    private func tallLayout(geometry: GeometryProxy, isRegular: Bool) -> some View {
        let dialSize = min(geometry.size.width * (isRegular ? 0.55 : 0.86),
                           geometry.size.height * 0.34)
        // The header stays pinned so it never scrolls under the status bar or
        // the Dynamic Island.
        return VStack(spacing: 0) {
            header
                .padding(.bottom, 4)

            ScrollView(showsIndicators: false) {
                VStack(spacing: isRegular ? 24 : 16) {
                    dial.frame(width: dialSize, height: dialSize)
                    containerControls
                    appliancePanel
                    actionRow
                }
                .frame(maxWidth: isRegular ? 620 : .infinity)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
        }
    }

    /// Landscape and Split View. The whole point of this arrangement is that
    /// nothing important sits below the fold: the earlier version put the
    /// controls in a scroll view, which pushed the appliance temperature *and*
    /// the start button out of sight — you had to scroll to start a timer.
    ///
    /// Getting it to fit costs two things: a trimmed header, and temperature
    /// controls whose label sits above the stepper so three fit in one row.
    private func wideLayout(geometry: GeometryProxy, isRegular: Bool) -> some View {
        let columnSpacing: CGFloat = isRegular ? 28 : 18
        // The dial takes just over a third of the width, and never more height
        // than is left once the header and the safe area are accounted for.
        // On iPhone: 0.30 rather than a bigger share, because each of the three
        // compact temperature cells needs ~150 pt for its value chip to hold
        // "-18 °C" without truncating. iPad has width to spare, so the dial takes
        // more of it and the control column is capped and centred instead.
        let dialSize = min(geometry.size.width * (isRegular ? 0.38 : 0.30),
                           geometry.size.height - (isRegular ? 96 : 66))

        return VStack(spacing: 6) {
            BrandHeader(
                onOpenSettings: { activeSheet = .settings },
                onOpenHelp: { activeSheet = .help },
                onOpenInfo: { activeSheet = .info },
                isCompact: !isRegular
            )

            HStack(alignment: .center, spacing: columnSpacing) {
                if isRegular { Spacer(minLength: 0) }

                dial
                    .frame(width: dialSize, height: dialSize)

                // Fits without scrolling at every normal text size; the largest
                // accessibility sizes fall back to a scroll view rather than
                // clipping.
                ViewThatFits(in: .vertical) {
                    wideControls
                    ScrollView(showsIndicators: false) { wideControls }
                }
                // Capped on iPad so the three temperature cells stay a compact
                // group instead of stretching across the whole column.
                .frame(maxWidth: isRegular ? 560 : .infinity)

                if isRegular { Spacer(minLength: 0) }
            }
            .frame(maxHeight: .infinity)
        }
        .padding(.vertical, 6)
    }

    /// Right-hand column of the wide layout.
    ///
    /// The temperature controls use their compact form here on every size class.
    /// The full portrait rows were tried on iPad and were worse: in a column that
    /// wide, the label and its stepper end up ~300 pt apart and stop reading as
    /// one control. iPad gets a larger dial and more generous spacing instead.
    private var wideControls: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                ThemedSegments(options: ContainerType.allCases,
                               label: { $0 == .bottle
                                   ? Formatting.localized("container_bottle")
                                   : Formatting.localized("container_can") },
                               selection: $settings.containerType)

                ThemedSegments(options: ContainerOrientation.allCases,
                               label: { $0 == .lying
                                   ? Formatting.localized("orientation_lying")
                                   : Formatting.localized("orientation_standing") },
                               selection: $settings.orientation)
            }

            ThemedSegments(options: VolumeOption.allCases,
                           label: { Formatting.volume($0) },
                           isEnabled: { settings.isVolumeAvailable($0) },
                           selection: $settings.volume)
                .accessibilityElement(children: .contain)
                .accessibilityLabel(Text(LocalizedStringKey("bottle_size")))

            ThemedCard(padding: 12) {
                VStack(spacing: 10) {
                    ThemedSegments(options: DeviceMode.allCases,
                                   label: { $0 == .freezer
                                       ? Formatting.localized("freezer")
                                       : Formatting.localized("fridge") },
                                   selection: $settings.deviceMode)

                    HStack(alignment: .top, spacing: 8) {
                        CompactTemperatureCell(
                            titleKey: "start_temperature",
                            value: Formatting.temperature(celsius: settings.startTempC,
                                                          unit: settings.temperatureUnit),
                            canDecrease: settings.startTempC > CoolingModel.minStartTempC,
                            canIncrease: settings.startTempC < CoolingModel.maxStartTempC,
                            onStep: settings.stepStartTemp)

                        CompactTemperatureCell(
                            titleKey: "target_temperature",
                            value: Formatting.temperature(celsius: settings.targetTempC,
                                                          unit: settings.temperatureUnit),
                            canDecrease: settings.targetTempC > CoolingModel.minTargetTempC,
                            canIncrease: settings.targetTempC < CoolingModel.maxTargetTempC,
                            onStep: settings.stepTargetTemp)

                        CompactTemperatureCell(
                            titleKey: "device_temperature",
                            value: Formatting.temperature(celsius: settings.deviceTempC,
                                                          unit: settings.temperatureUnit),
                            canDecrease: settings.deviceTempC > CoolingModel.minDeviceTempC,
                            canIncrease: settings.deviceTempC < CoolingModel.maxDeviceTempC,
                            onStep: settings.stepDeviceTemp)
                    }
                }
            }
            .disabled(controller.isRunning)
            .opacity(controller.isRunning ? 0.6 : 1)

            actionRow
        }
    }

    // MARK: Sections

    private var header: some View {
        BrandHeader(
            onOpenSettings: { activeSheet = .settings },
            onOpenHelp: { activeSheet = .help },
            onOpenInfo: { activeSheet = .info }
        )
    }

    private var dial: some View {
        CoolingDial(title: dialTitleKey,
                    value: dialValue,
                    subtitle: dialSubtitle,
                    progress: controller.progress,
                    isRunning: controller.isRunning)
            .accessibilityLabel(Text(dialTitleKey))
            .accessibilityValue(Text(dialAccessibilityValue))
    }

    private var containerControls: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                ThemedSegments(options: ContainerType.allCases,
                               label: { $0 == .bottle
                                   ? Formatting.localized("container_bottle")
                                   : Formatting.localized("container_can") },
                               selection: $settings.containerType)

                ThemedSegments(options: ContainerOrientation.allCases,
                               label: { $0 == .lying
                                   ? Formatting.localized("orientation_lying")
                                   : Formatting.localized("orientation_standing") },
                               selection: $settings.orientation)
            }

            ThemedSegments(options: VolumeOption.allCases,
                           label: { Formatting.volume($0) },
                           isEnabled: { settings.isVolumeAvailable($0) },
                           selection: $settings.volume)
                // `children: .contain` names the group *and* keeps each option's
                // own label. A plain .accessibilityLabel here would override the
                // children, making all three sizes announce "bottle size".
                .accessibilityElement(children: .contain)
                .accessibilityLabel(Text(LocalizedStringKey("bottle_size")))
        }
    }

    private var appliancePanel: some View {
        ThemedCard {
            VStack(spacing: 14) {
                ThemedSegments(options: DeviceMode.allCases,
                               label: { $0 == .freezer
                                   ? Formatting.localized("freezer")
                                   : Formatting.localized("fridge") },
                               selection: $settings.deviceMode)

                temperatureRows
            }
        }
        .disabled(controller.isRunning)
        .opacity(controller.isRunning ? 0.6 : 1)
    }

    /// The three full-width temperature controls, shared by the portrait layout
    /// and the regular-width wide layout.
    @ViewBuilder
    private var temperatureRows: some View {
        TemperatureRow(titleKey: "start_temperature",
                       systemImage: "thermometer",
                       value: Formatting.temperature(celsius: settings.startTempC,
                                                     unit: settings.temperatureUnit),
                       canDecrease: settings.startTempC > CoolingModel.minStartTempC,
                       canIncrease: settings.startTempC < CoolingModel.maxStartTempC,
                       onStep: settings.stepStartTemp)

        TemperatureRow(titleKey: "target_temperature",
                       systemImage: "scope",
                       value: Formatting.temperature(celsius: settings.targetTempC,
                                                     unit: settings.temperatureUnit),
                       canDecrease: settings.targetTempC > CoolingModel.minTargetTempC,
                       canIncrease: settings.targetTempC < CoolingModel.maxTargetTempC,
                       onStep: settings.stepTargetTemp)

        TemperatureRow(titleKey: "device_temperature",
                       systemImage: "snowflake",
                       value: Formatting.temperature(celsius: settings.deviceTempC,
                                                     unit: settings.temperatureUnit),
                       canDecrease: settings.deviceTempC > CoolingModel.minDeviceTempC,
                       canIncrease: settings.deviceTempC < CoolingModel.maxDeviceTempC,
                       onStep: settings.stepDeviceTemp)
    }

    private var actionRow: some View {
        HStack(spacing: 12) {
            PrimaryActionButton(titleKey: "start_timer",
                                systemImage: "play.fill",
                                isEnabled: !controller.isRunning && (settings.coolingMinutes ?? 0) > 0) {
                controller.requestNotificationAuthorizationIfNeeded()
                controller.start()
            }
            .accessibilityIdentifier("action.start")

            SecondaryActionButton(titleKey: "stop",
                                  isEnabled: controller.isRunning) {
                controller.stop()
            }
            .accessibilityIdentifier("action.stop")
        }
    }

    // MARK: Dial content

    private var dialTitleKey: LocalizedStringKey {
        controller.isRunning
            ? LocalizedStringKey("remaining_time")
            : LocalizedStringKey("cooling_time")
    }

    private var dialValue: String {
        if controller.isRunning {
            return Formatting.countdown(seconds: controller.remainingSeconds)
        }
        guard let minutes = settings.coolingMinutes else {
            return Formatting.localized("check_inputs_short")
        }
        return Formatting.minutes(minutes)
    }

    private var dialSubtitle: String? {
        if controller.isRunning, let session = controller.session {
            let temperature = Formatting.temperature(celsius: session.currentTemperatureC(at: controller.now),
                                                    unit: settings.temperatureUnit)
            return "\(Formatting.localized("current_temperature_short")) \(temperature)"
        }
        guard let minutes = settings.coolingMinutes, minutes > 0 else { return nil }
        return Formatting.endsAt(Date().addingTimeInterval(Double(minutes) * 60))
    }

    private var dialAccessibilityValue: String {
        var parts = [dialValue]
        if let subtitle = dialSubtitle { parts.append(subtitle) }
        return parts.joined(separator: ", ")
    }
}
