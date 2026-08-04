//
//  Formatting.swift
//  BeerCHILLER
//
//  Temperature, duration and volume formatting. All localized strings come from
//  the String Catalog using the original Android keys, so the ten translations
//  carry over unchanged.
//
//  Temperatures are stored in Celsius everywhere and converted only for display,
//  matching the Android original (which also steps the underlying value in whole
//  degrees Celsius regardless of the display unit).
//

import Foundation

public enum Formatting {

    // MARK: Temperature

    public static func celsiusToFahrenheit(_ celsius: Double) -> Double {
        celsius * 9.0 / 5.0 + 32.0
    }

    /// Whole-degree temperature, e.g. "22 °C" / "72 °F".
    public static func temperature(celsius: Int, unit: TemperatureUnit) -> String {
        switch unit.resolved {
        case .fahrenheit:
            let value = Int((celsiusToFahrenheit(Double(celsius))).rounded())
            return String(format: localized("degrees_fahrenheit"), value)
        default:
            return String(format: localized("degrees_celsius"), celsius)
        }
    }

    /// One-decimal temperature for the live estimate, e.g. "12,4 °C".
    public static func temperature(celsius: Double, unit: TemperatureUnit) -> String {
        switch unit.resolved {
        case .fahrenheit:
            return String(format: localized("degrees_fahrenheit_decimal"),
                          celsiusToFahrenheit(celsius))
        default:
            return String(format: localized("degrees_celsius_decimal"), celsius)
        }
    }

    /// Unit suffix on its own, for accessibility strings and compact widgets.
    public static func unitSuffix(_ unit: TemperatureUnit) -> String {
        unit.resolved == .fahrenheit ? "°F" : "°C"
    }

    // MARK: Duration

    /// Cooling time headline, e.g. "279 min".
    public static func minutes(_ value: Int) -> String {
        String(format: localized("minutes_short"), value)
    }

    /// Countdown as mm:ss, switching to m:ss past 100 minutes — the same rule the
    /// Android original applies so the digits never overflow the dial.
    public static func countdown(seconds: Double) -> String {
        let total = Int(ceil(max(0, seconds)))
        let minutes = total / 60
        let secs = total % 60
        if minutes < 100 {
            return String(format: "%02d:%02d", minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }

    /// Short "1 h 23 min" style label used by the compact widget families.
    public static func compactRemaining(seconds: Double) -> String {
        let total = Int(ceil(max(0, seconds)))
        let hours = total / 3600
        let remainingMinutes = (total % 3600) / 60
        if hours > 0 {
            return "\(hours) h \(remainingMinutes) min"
        }
        return minutes(max(0, remainingMinutes))
    }

    /// Wall-clock end time, respecting the user's 12/24-hour setting.
    public static func endTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }

    /// "Ends at 21:23"
    public static func endsAt(_ date: Date) -> String {
        String(format: localized("ends_at"), endTime(date))
    }

    // MARK: Volume

    public static func volume(_ option: VolumeOption) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        // Matches the original's labels exactly: 0,33 l — 0,5 l — 1,0 l.
        formatter.minimumFractionDigits = option == .small ? 2 : 1
        formatter.maximumFractionDigits = 2
        let number = formatter.string(from: NSNumber(value: option.liters)) ?? "\(option.liters)"
        return "\(number) l"
    }

    // MARK: Helper

    /// Looks a key up in the app's String Catalog.
    static func localized(_ key: String) -> String {
        NSLocalizedString(key, bundle: .main, comment: "")
    }
}
