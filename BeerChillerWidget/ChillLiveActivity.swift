//
//  ChillLiveActivity.swift
//  BeerCHILLERWidget
//
//  Lock-screen Live Activity and Dynamic Island presentation for a running
//  timer — the app's central use case: glanceable "when is my beer cold?".
//
//  The countdown text is a `Text(timerInterval:)`, so the system animates it
//  without the app pushing updates. Only the temperature estimate is pushed,
//  about once a minute.
//

import ActivityKit
import SwiftUI
import WidgetKit

@available(iOS 16.1, *)
struct ChillLiveActivity: Widget {

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ChillActivityAttributes.self) { context in
            LockScreenLiveActivityView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label {
                        Text(temperature(context))
                            .monospacedDigit()
                    } icon: {
                        Image(systemName: "thermometer")
                    }
                    .font(.callout)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: context.attributes.startDate...context.attributes.endDate,
                         countsDown: true)
                        .monospacedDigit()
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 74)
                        .font(.title3.weight(.semibold))
                }

                DynamicIslandExpandedRegion(.center) {
                    Text(LocalizedStringKey("remaining_time"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    ProgressView(timerInterval: context.attributes.startDate...context.attributes.endDate,
                                 countsDown: false) {
                        EmptyView()
                    } currentValueLabel: {
                        EmptyView()
                    }
                    .tint(.orange)
                }
            } compactLeading: {
                Image(systemName: "snowflake")
                    .foregroundStyle(.cyan)
            } compactTrailing: {
                Text(timerInterval: context.attributes.startDate...context.attributes.endDate,
                     countsDown: true)
                    .monospacedDigit()
                    .frame(maxWidth: 44)
            } minimal: {
                Image(systemName: "snowflake")
                    .foregroundStyle(.cyan)
            }
            .keylineTint(.orange)
        }
    }

    private func temperature(_ context: ActivityViewContext<ChillActivityAttributes>) -> String {
        let unit: TemperatureUnit = SharedStore.enumValue(SharedStore.Key.temperatureUnit,
                                                          default: .system)
        return Formatting.temperature(celsius: context.state.currentTemperatureC, unit: unit)
    }
}

@available(iOS 16.1, *)
struct LockScreenLiveActivityView: View {

    let context: ActivityViewContext<ChillActivityAttributes>

    private var unit: TemperatureUnit {
        SharedStore.enumValue(SharedStore.Key.temperatureUnit, default: .system)
    }

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "snowflake")
                        .foregroundStyle(.cyan)
                    Text("BeerCHILLER")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Text(timerInterval: context.attributes.startDate...context.attributes.endDate,
                     countsDown: true)
                    .font(.system(size: 32, weight: .semibold))
                    .monospacedDigit()

                Text(Formatting.endsAt(context.attributes.endDate))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 4) {
                Text(LocalizedStringKey("current_temperature_short"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(Formatting.temperature(celsius: context.state.currentTemperatureC, unit: unit))
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
                Text(String(format: Formatting.localized("widget_target"),
                            Formatting.temperature(celsius: Int(context.attributes.targetTempC.rounded()),
                                                   unit: unit)))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .activityBackgroundTint(Color(hex: 0x123B47).opacity(0.92))
        .activitySystemActionForegroundColor(.white)
    }
}
