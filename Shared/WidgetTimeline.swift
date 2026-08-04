//
//  WidgetTimeline.swift
//  BeerCHILLER
//
//  Pure timeline planning for the widget and the watch complication.
//
//  Extracted out of the extensions so it can be unit-tested: a widget's refresh
//  behaviour is exactly the kind of thing that silently rots, and the extensions
//  themselves are not reachable from the app-hosted test bundle.
//

import Foundation

public enum WidgetTimeline {

    /// How far apart the entries sit.
    public static let step: TimeInterval = 60
    /// Upper bound on entries handed to WidgetKit in one timeline.
    public static let maximumEntries = 60
    /// Refresh interval while no timer runs.
    public static let idleRefresh: TimeInterval = 3600

    /// Dates the widget should render at, for a running session.
    ///
    /// One entry per minute from `date` up to the end, plus a final entry exactly
    /// at `endDate` so the "beer is ready" state appears on time. Returns an
    /// empty array when there is nothing to count down.
    public static func entryDates(for session: ChillSession,
                                  from date: Date) -> [Date] {
        guard !session.isFinished(at: date) else { return [] }

        var dates: [Date] = []
        var cursor = date
        while cursor < session.endDate && dates.count < maximumEntries {
            dates.append(cursor)
            cursor = cursor.addingTimeInterval(step)
        }
        dates.append(session.endDate)
        return dates
    }

    /// When WidgetKit should come back for a new timeline.
    public static func refreshDate(for session: ChillSession?,
                                   from date: Date) -> Date {
        guard let session, !session.isFinished(at: date) else {
            return date.addingTimeInterval(idleRefresh)
        }
        // Either just after the run ends, or when the entry budget runs out —
        // whichever comes first.
        let budgetEnd = date.addingTimeInterval(step * Double(maximumEntries))
        return min(session.endDate.addingTimeInterval(1), budgetEnd)
    }
}
