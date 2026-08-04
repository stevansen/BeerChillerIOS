//
//  ChillTimerWidget.swift
//  BeerCHILLERWidget
//
//  Home-screen (small/medium/large) and lock-screen (accessory) widget.
//
//  The timeline is built from the session's *end date*, not from a live counter:
//  one entry per minute up to the end, then a final "ready" entry. Nothing needs
//  to refresh the widget on time for the countdown to stay correct.
//

import SwiftUI
import WidgetKit

struct ChillEntry: TimelineEntry {
    let date: Date
    let session: ChillSession?
    let visualStyle: VisualStyle
    let temperatureUnit: TemperatureUnit

    var isRunning: Bool {
        guard let session else { return false }
        return !session.isFinished(at: date)
    }
}

struct ChillTimelineProvider: TimelineProvider {

    func placeholder(in context: Context) -> ChillEntry {
        ChillEntry(date: Date(), session: nil, visualStyle: .classic, temperatureUnit: .system)
    }

    func getSnapshot(in context: Context, completion: @escaping (ChillEntry) -> Void) {
        completion(currentEntry(at: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ChillEntry>) -> Void) {
        let now = Date()
        let entry = currentEntry(at: now)

        guard let session = entry.session, !session.isFinished(at: now) else {
            // Idle: nothing to count down. Check back later in case a timer was
            // started while the widget was not reloaded.
            completion(Timeline(entries: [entry],
                                policy: .after(WidgetTimeline.refreshDate(for: entry.session,
                                                                          from: now))))
            return
        }

        let entries = WidgetTimeline.entryDates(for: session, from: now).map {
            ChillEntry(date: $0,
                       session: session,
                       visualStyle: entry.visualStyle,
                       temperatureUnit: entry.temperatureUnit)
        }
        completion(Timeline(entries: entries,
                            policy: .after(WidgetTimeline.refreshDate(for: session, from: now))))
    }

    private func currentEntry(at date: Date) -> ChillEntry {
        ChillEntry(
            date: date,
            session: SharedStore.loadSession(),
            visualStyle: SharedStore.enumValue(SharedStore.Key.visualStyle, default: .classic),
            temperatureUnit: SharedStore.enumValue(SharedStore.Key.temperatureUnit, default: .system)
        )
    }
}

struct ChillTimerWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "BeerChillerTimerWidget",
                            provider: ChillTimelineProvider()) { entry in
            ChillWidgetView(entry: entry)
        }
        .configurationDisplayName(Text(LocalizedStringKey("widget_name")))
        .description(Text(LocalizedStringKey("widget_description")))
        .supportedFamilies(supportedFamilies)
    }

    private var supportedFamilies: [WidgetFamily] {
        [.systemSmall, .systemMedium, .systemLarge,
         .accessoryCircular, .accessoryRectangular, .accessoryInline]
    }
}

// MARK: - Views

struct ChillWidgetView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var colorScheme
    var entry: ChillEntry

    private var palette: Palette {
        Palette.resolve(style: entry.visualStyle, scheme: colorScheme)
    }

    var body: some View {
        content
            .environment(\.palette, palette)
            .widgetContainerBackground(palette: palette, family: family)
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .accessoryCircular:
            AccessoryCircularChillView(entry: entry)
        case .accessoryRectangular:
            AccessoryRectangularChillView(entry: entry)
        case .accessoryInline:
            AccessoryInlineChillView(entry: entry)
        default:
            HomeScreenChillView(entry: entry, family: family)
        }
    }
}

/// Home-screen families. The beer style uses a warm gradient rather than the
/// photo: widget processes have a tight memory budget and a full-bleed photo
/// buys nothing at this size.
struct HomeScreenChillView: View {
    @Environment(\.palette) private var palette
    var entry: ChillEntry
    var family: WidgetFamily

    private var isSmall: Bool { family == .systemSmall }

    var body: some View {
        VStack(alignment: .leading, spacing: isSmall ? 4 : 8) {
            HStack(spacing: 6) {
                Image(systemName: "snowflake")
                    .foregroundStyle(palette.accent)
                Text("BeerCHILLER")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(palette.secondaryText)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            if let session = entry.session, entry.isRunning {
                Text(LocalizedStringKey("remaining_time"))
                    .font(.caption2)
                    .foregroundStyle(palette.secondaryText)

                // The system renders and updates this countdown itself.
                Text(timerInterval: entry.date...session.endDate, countsDown: true)
                    .font(.system(size: isSmall ? 26 : 34, weight: .semibold))
                    .monospacedDigit()
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .foregroundStyle(palette.primaryText)

                if family != .systemSmall {
                    Text(Formatting.endsAt(session.endDate))
                        .font(.caption)
                        .foregroundStyle(palette.secondaryText)
                }

                Text(temperatureLine(session))
                    .font(.caption2)
                    .foregroundStyle(palette.secondaryText)
                    .lineLimit(1)
            } else if entry.session != nil {
                Text(LocalizedStringKey("alarm_ringing"))
                    .font(.system(size: isSmall ? 18 : 24, weight: .semibold))
                    .foregroundStyle(palette.primaryText)
                    .minimumScaleFactor(0.6)
                Text(LocalizedStringKey("alarm_detail"))
                    .font(.caption)
                    .foregroundStyle(palette.secondaryText)
                    .lineLimit(2)
            } else {
                Text(LocalizedStringKey("no_timer"))
                    .font(.system(size: isSmall ? 24 : 32, weight: .semibold))
                    .foregroundStyle(palette.primaryText)
                Text(LocalizedStringKey("widget_tap_to_start"))
                    .font(.caption)
                    .foregroundStyle(palette.secondaryText)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func temperatureLine(_ session: ChillSession) -> String {
        let current = Formatting.temperature(celsius: session.currentTemperatureC(at: entry.date),
                                             unit: entry.temperatureUnit)
        let target = Formatting.temperature(celsius: Int(session.targetTempC.rounded()),
                                            unit: entry.temperatureUnit)
        return "\(current) → \(String(format: Formatting.localized("widget_target"), target))"
    }
}

/// Lock-screen circular: a progress ring with the remaining minutes.
struct AccessoryCircularChillView: View {
    var entry: ChillEntry

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            if let session = entry.session, entry.isRunning {
                Gauge(value: session.progress(at: entry.date)) {
                    Image(systemName: "snowflake")
                } currentValueLabel: {
                    Text("\(Int((session.remainingSeconds(at: entry.date) / 60).rounded(.up)))")
                        .minimumScaleFactor(0.5)
                }
                .gaugeStyle(.accessoryCircular)
            } else {
                VStack(spacing: 1) {
                    Image(systemName: "snowflake")
                        .font(.title3)
                    Text(verbatim: "–")
                        .font(.caption2)
                }
            }
        }
    }
}

struct AccessoryRectangularChillView: View {
    var entry: ChillEntry

    var body: some View {
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
                Text(LocalizedStringKey("alarm_ringing"))
                    .font(.headline)
            } else {
                Text(LocalizedStringKey("widget_tap_to_start"))
                    .font(.caption)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct AccessoryInlineChillView: View {
    var entry: ChillEntry

    var body: some View {
        if let session = entry.session, entry.isRunning {
            Text("\(Image(systemName: "snowflake")) \(Formatting.compactRemaining(seconds: session.remainingSeconds(at: entry.date)))")
        } else if entry.session != nil {
            Text(LocalizedStringKey("alarm_ringing"))
        } else {
            Text(LocalizedStringKey("widget_tap_to_start"))
        }
    }
}

// MARK: - Background compatibility

private extension View {
    /// `containerBackground` is required from iOS 17 on and unavailable before it.
    @ViewBuilder
    func widgetContainerBackground(palette: Palette, family: WidgetFamily) -> some View {
        let isAccessory = family == .accessoryCircular
            || family == .accessoryRectangular
            || family == .accessoryInline

        if #available(iOS 17.0, *) {
            if isAccessory {
                containerBackground(.clear, for: .widget)
            } else {
                containerBackground(for: .widget) {
                    LinearGradient(colors: [palette.background, palette.backgroundSecondary],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                }
            }
        } else {
            if isAccessory {
                self
            } else {
                padding(14)
                    .background(
                        LinearGradient(colors: [palette.background, palette.backgroundSecondary],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
            }
        }
    }
}
