//
//  AlarmView.swift
//  BeerCHILLER
//
//  Shown when the target temperature is reached, including on relaunch if the
//  app was terminated while the timer ran.
//

import SwiftUI

struct AlarmView: View {

    @EnvironmentObject private var controller: ChillController
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var isPulsing = false

    var body: some View {
        ZStack {
            ThemedBackground()

            VStack(spacing: 28) {
                Spacer()

                Image(systemName: "snowflake")
                    .font(.system(size: 84, weight: .light))
                    .foregroundStyle(palette.accent)
                    .scaleEffect(isPulsing ? 1.06 : 1.0)
                    .animation(reduceMotion ? nil
                               : .easeInOut(duration: 1.2).repeatForever(autoreverses: true),
                               value: isPulsing)
                    .accessibilityHidden(true)

                VStack(spacing: 10) {
                    Text(LocalizedStringKey("alarm_ringing"))
                        .font(.largeTitle.weight(.bold))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(palette.primaryText)
                        .accessibilityIdentifier("alarm.title")

                    Text(LocalizedStringKey("alarm_detail"))
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(palette.secondaryText)

                    if let session = controller.session {
                        Text(Formatting.temperature(celsius: session.targetTempC,
                                                    unit: settings.temperatureUnit))
                            .font(.title2.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(palette.primaryText)
                            .padding(.top, 4)
                    }
                }
                .padding(.horizontal, 24)

                Spacer()

                PrimaryActionButton(titleKey: "stop_alarm",
                                    systemImage: "stop.fill",
                                    isEnabled: true) {
                    controller.acknowledgeAlarm()
                }
                .accessibilityIdentifier("alarm.stop")
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        .onAppear { isPulsing = true }
        .interactiveDismissDisabled()
    }
}
