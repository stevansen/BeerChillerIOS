//
//  BeerChillerWatchWidgetBundle.swift
//  BeerCHILLER Watch Complications
//
//  Watch-face complications for the running timer. Same timeline strategy as the
//  iOS widget: derived from the session's end date, so the face stays correct
//  without frequent budgeted refreshes.
//

import SwiftUI
import WidgetKit

@main
struct BeerChillerWatchWidgetBundle: WidgetBundle {
    var body: some Widget {
        ChillComplication()
    }
}

struct ChillComplicationEntry: TimelineEntry {
    let date: Date
    let session: ChillSession?
    let temperatureUnit: TemperatureUnit

    var isRunning: Bool {
        guard let session else { return false }
        return !session.isFinished(at: date)
    }
}

struct ChillComplicationProvider: TimelineProvider {

    func placeholder(in context: Context) -> ChillComplicationEntry {
        ChillComplicationEntry(date: Date(), session: nil, temperatureUnit: .system)
    }

    func getSnapshot(in context: Context,
                     completion: @escaping (ChillComplicationEntry) -> Void) {
        completion(entry(at: Date()))
    }

    func getTimeline(in context: Context,
                     completion: @escaping (Timeline<ChillComplicationEntry>) -> Void) {
        let now = Date()
        let current = entry(at: now)

        guard let session = current.session, !session.isFinished(at: now) else {
            completion(Timeline(entries: [current],
                                policy: .after(WidgetTimeline.refreshDate(for: current.session,
                                                                          from: now))))
            return
        }

        let entries = WidgetTimeline.entryDates(for: session, from: now).map {
            ChillComplicationEntry(date: $0,
                                   session: session,
                                   temperatureUnit: current.temperatureUnit)
        }
        completion(Timeline(entries: entries,
                            policy: .after(WidgetTimeline.refreshDate(for: session, from: now))))
    }

    private func entry(at date: Date) -> ChillComplicationEntry {
        ChillComplicationEntry(
            date: date,
            session: SharedStore.loadSession(),
            temperatureUnit: SharedStore.enumValue(SharedStore.Key.temperatureUnit,
                                                   default: .system)
        )
    }
}

struct ChillComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "BeerChillerComplication",
                            provider: ChillComplicationProvider()) { entry in
            ChillComplicationView(entry: entry)
        }
        .configurationDisplayName(Text(LocalizedStringKey("widget_name")))
        .description(Text(LocalizedStringKey("widget_description")))
        .supportedFamilies([.accessoryCircular, .accessoryCorner,
                            .accessoryInline, .accessoryRectangular])
    }
}

struct ChillComplicationView: View {
    @Environment(\.widgetFamily) private var family
    var entry: ChillComplicationEntry

    var body: some View {
        switch family {
        case .accessoryCorner:
            cornerView
        case .accessoryInline:
            inlineView
        case .accessoryRectangular:
            rectangularView
        default:
            circularView
        }
    }

    private var remainingMinutes: Int {
        guard let session = entry.session else { return 0 }
        return Int((session.remainingSeconds(at: entry.date) / 60).rounded(.up))
    }

    private var circularView: some View {
        ZStack {
            AccessoryWidgetBackground()
            if let session = entry.session, entry.isRunning {
                Gauge(value: session.progress(at: entry.date)) {
                    Image(systemName: "snowflake")
                } currentValueLabel: {
                    Text("\(remainingMinutes)").minimumScaleFactor(0.5)
                }
                .gaugeStyle(.accessoryCircular)
            } else {
                Image(systemName: "snowflake").font(.title3)
            }
        }
    }

    private var cornerView: some View {
        Group {
            if let session = entry.session, entry.isRunning {
                Text("\(remainingMinutes)")
                    .font(.title3.weight(.semibold))
                    .widgetLabel {
                        ProgressView(value: session.progress(at: entry.date))
                            .tint(.orange)
                    }
            } else {
                Image(systemName: "snowflake")
                    .font(.title3)
                    .widgetLabel { Text(verbatim: "BeerCHILLER") }
            }
        }
    }

    private var inlineView: some View {
        Group {
            if let session = entry.session, entry.isRunning {
                Text("\(Image(systemName: "snowflake")) \(Formatting.compactRemaining(seconds: session.remainingSeconds(at: entry.date)))")
            } else if entry.session != nil {
                Text(LocalizedStringKey("alarm_ringing"))
            } else {
                Text(LocalizedStringKey("widget_tap_to_start"))
            }
        }
    }

    private var rectangularView: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("BeerCHILLER")
                .font(.caption2.weight(.semibold))
                .widgetAccentable()
            if let session = entry.session, entry.isRunning {
                Text(timerInterval: entry.date...session.endDate, countsDown: true)
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
                Text(Formatting.temperature(celsius: session.currentTemperatureC(at: entry.date),
                                            unit: entry.temperatureUnit))
                    .font(.caption2)
            } else if entry.session != nil {
                Text(LocalizedStringKey("alarm_ringing")).font(.headline)
            } else {
                Text(LocalizedStringKey("widget_tap_to_start")).font(.caption2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
