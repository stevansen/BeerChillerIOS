//
//  Components.swift
//  BeerCHILLER
//
//  Reusable pieces of the main screen. Everything reads its colours from
//  `\.palette`, so the same views serve both visual styles in both appearances.
//

import SwiftUI

// MARK: - Background

/// Solid colour in Classic style, the generated beer artwork in Beer style — a
/// lager in light mode, a dunkel in dark mode, switched by the asset catalog. A
/// scrim sits over it so text stays legible, and the artwork is dropped entirely
/// for a plain gradient when the user asks for reduced transparency.
struct ThemedBackground: View {
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        ZStack {
            if palette.usesPhotoBackground && !reduceTransparency {
                LinearGradient(colors: [palette.background, palette.backgroundSecondary],
                               startPoint: .top, endPoint: .bottom)

                // The artwork is portrait, so `.fill` in landscape asks for a
                // frame far larger than the screen. Left unbounded that ideal size
                // propagates up through the ZStack and pushes the actual UI out of
                // the window — in landscape the dial and every control ended up at
                // y ≈ 700 in a 402 pt tall window, leaving only the header visible.
                // A GeometryReader accepts the proposed size and does not pass its
                // child's ideal size back up, which is what isolates the layout.
                GeometryReader { geometry in
                    Image("BeerBackground")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                }
                .accessibilityHidden(true)

                palette.photoScrim
            } else {
                LinearGradient(colors: [palette.background, palette.backgroundSecondary],
                               startPoint: .top, endPoint: .bottom)
            }
        }
        .ignoresSafeArea()
    }
}

/// Rounded panel used for the control groups.
struct ThemedCard<Content: View>: View {
    @Environment(\.palette) private var palette
    var padding: CGFloat = 16
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(palette.surface)
            )
    }
}

// MARK: - Header

struct BrandHeader: View {
    @Environment(\.palette) private var palette
    @Environment(\.sizeCategory) private var sizeCategory
    @EnvironmentObject private var settings: AppSettings

    var onOpenSettings: () -> Void
    var onOpenHelp: () -> Void
    var onOpenInfo: () -> Void
    /// Landscape trims the header so the vertical budget goes to the controls.
    var isCompact: Bool = false

    /// Grows with the text size, but capped so the glyph cannot push the
    /// wordmark and the menu button off the row at accessibility sizes.
    private var markHeight: CGFloat {
        if sizeCategory.isAccessibilityCategory { return isCompact ? 34 : 42 }
        return isCompact ? 26 : 34
    }

    private var wordmarkFont: Font {
        isCompact ? .title3.weight(.bold) : .title2.weight(.bold)
    }

    var body: some View {
        HStack(spacing: 10) {
            // Brand mark: half bottle, half frost crystal. Sized off the
            // wordmark's font so it tracks Dynamic Type.
            BrandMark(bottleColor: palette.markBottle, frostColor: palette.markFrost)
                .frame(height: markHeight)

            // The original inverts the wordmark between the two styles: amber
            // "Beer" in Classic, amber "CHILLER" in Beer.
            Group {
                if settings.visualStyle == .beer {
                    Text(verbatim: "Beer").foregroundColor(palette.primaryText)
                        + Text(verbatim: "CHILLER").foregroundColor(palette.brandSecondary)
                } else {
                    Text(verbatim: "Beer").foregroundColor(palette.accent)
                        + Text(verbatim: "CHILLER").foregroundColor(palette.brandSecondary)
                }
            }
            .font(wordmarkFont)
            .accessibilityLabel(Text(verbatim: "BeerCHILLER"))

            Spacer(minLength: 8)

            // Flat, one level deep, three titled sections. Every row carries a
            // symbol so the text column does not jump, and the light/dark choice
            // sits here rather than three taps down in Settings.
            Menu {
                Section {
                    Picker(selection: $settings.visualStyle) {
                        ForEach(VisualStyle.allCases, id: \.self) { style in
                            Label(LocalizedStringKey(style.titleKey),
                                  systemImage: style.systemImage)
                                .tag(style)
                        }
                    } label: {
                        Text(LocalizedStringKey("visual_style_title"))
                    }
                    .pickerStyle(.inline)
                } header: {
                    Text(LocalizedStringKey("visual_style_title"))
                }

                Section {
                    Picker(selection: $settings.appearance) {
                        ForEach(AppearanceMode.allCases, id: \.self) { mode in
                            Label(LocalizedStringKey(mode.titleKey),
                                  systemImage: mode.systemImage)
                                .tag(mode)
                        }
                    } label: {
                        Text(LocalizedStringKey("appearance_title"))
                    }
                    .pickerStyle(.inline)
                } header: {
                    Text(LocalizedStringKey("appearance_title"))
                }

                Section {
                    Button {
                        onOpenHelp()
                    } label: {
                        Label(LocalizedStringKey("menu_calculation_model"),
                              systemImage: "function")
                    }

                    Button {
                        onOpenInfo()
                    } label: {
                        Label(LocalizedStringKey("menu_info"), systemImage: "info.circle")
                    }

                    Button {
                        onOpenSettings()
                    } label: {
                        Label(LocalizedStringKey("menu_settings"), systemImage: "gearshape")
                    }
                }
            } label: {
                // The label has to sit on the Menu's *content*: putting
                // .accessibilityLabel on the Menu itself does not reach the
                // button UIKit creates for it, leaving VoiceOver with nothing to
                // announce (caught by testAccessibilityLabelsArePresent).
                Image(systemName: "ellipsis.circle")
                    .font(.title2)
                    .foregroundStyle(palette.primaryText)
                    .frame(width: 44, height: 44)
                    .accessibilityLabel(Text(LocalizedStringKey("menu_open")))
            }
        }
    }
}

// MARK: - Dial

/// The cooling dial: a ticked ring with a progress arc and a stacked label.
/// While idle it shows the calculated cooling time; while running, the countdown
/// and the estimated current temperature.
struct CoolingDial: View {
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var title: LocalizedStringKey
    var value: String
    var subtitle: String?
    var progress: Double
    var isRunning: Bool

    private let tickCount = 96

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            ZStack {
                Circle()
                    .fill(palette.chip)
                    .padding(size * 0.09)
                    .shadow(color: palette.shadow, radius: 14, y: 6)

                TickRing(tickCount: tickCount,
                         progress: isRunning ? progress : 0,
                         trackColor: palette.dialTrack,
                         progressColor: palette.dialProgress,
                         showsProgress: isRunning)
                    .animation(reduceMotion ? nil : .linear(duration: 0.9), value: progress)

                VStack(spacing: size * 0.03) {
                    Text(title)
                        .font(.system(size: max(13, size * 0.075), weight: .regular))
                        .foregroundStyle(palette.secondaryText)
                        .textCase(palette.usesPhotoBackground ? .uppercase : nil)

                    Text(value)
                        .font(.system(size: max(28, size * 0.175), weight: .semibold))
                        .foregroundStyle(palette.primaryText)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                        .monospacedDigit()

                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: max(12, size * 0.062)))
                            .foregroundStyle(palette.secondaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                }
                .padding(.horizontal, size * 0.18)
            }
            .frame(width: size, height: size)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct TickRing: View {
    var tickCount: Int
    var progress: Double
    var trackColor: Color
    var progressColor: Color
    var showsProgress: Bool

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let outerRadius = min(size.width, size.height) / 2
            let tickLength = outerRadius * 0.11
            let lineWidth = max(1.5, outerRadius * 0.018)

            for index in 0..<tickCount {
                let fraction = Double(index) / Double(tickCount)
                let angle = fraction * 2 * .pi - .pi / 2
                let isDone = showsProgress && fraction <= progress

                let start = CGPoint(x: center.x + cos(angle) * (outerRadius - tickLength),
                                    y: center.y + sin(angle) * (outerRadius - tickLength))
                let end = CGPoint(x: center.x + cos(angle) * outerRadius,
                                  y: center.y + sin(angle) * outerRadius)

                var path = Path()
                path.move(to: start)
                path.addLine(to: end)
                context.stroke(path,
                               with: .color(isDone ? progressColor : trackColor),
                               lineWidth: isDone ? lineWidth * 1.5 : lineWidth)
            }
        }
    }
}

// MARK: - Segmented control

/// Pill-shaped segmented control matching the original's look while behaving
/// like a native control (single selection, full VoiceOver traits).
struct ThemedSegments<Value: Hashable>: View {
    @Environment(\.palette) private var palette

    var options: [Value]
    var label: (Value) -> String
    var isEnabled: (Value) -> Bool = { _ in true }
    @Binding var selection: Value

    var body: some View {
        HStack(spacing: 6) {
            ForEach(options, id: \.self) { option in
                let selected = option == selection
                let enabled = isEnabled(option)
                Button {
                    selection = option
                } label: {
                    Text(label(option))
                        .font(.body.weight(selected ? .semibold : .regular))
                        .foregroundStyle(
                            !enabled ? palette.disabledText
                                : selected ? palette.selectedText : palette.unselectedText
                        )
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 44)
                        .background(
                            Capsule(style: .continuous)
                                .fill(selected ? palette.selectedFill : palette.chip)
                        )
                }
                .buttonStyle(.plain)
                .disabled(!enabled)
                .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
            }
        }
        .padding(5)
        .background(
            Capsule(style: .continuous).fill(palette.surface.opacity(0.7))
        )
    }
}

// MARK: - Temperature row

/// Label + minus/value/plus, the same arrangement as the Android layout.
struct TemperatureRow: View {
    @Environment(\.palette) private var palette

    var titleKey: String
    var systemImage: String
    var value: String
    var canDecrease: Bool
    var canIncrease: Bool
    var onStep: (Int) -> Void

    var body: some View {
        HStack(spacing: 12) {
            if palette.usesPhotoBackground {
                Image(systemName: systemImage)
                    .font(.title3)
                    .foregroundStyle(palette.accent)
                    .frame(width: 26)
                    .accessibilityHidden(true)
            }

            // These labels are single compound nouns in several languages
            // ("Gerätetemperatur", "Apparaattemperatuur"), so they cannot wrap at
            // a space. Allow two lines and a little shrink instead of truncating.
            Text(LocalizedStringKey(titleKey))
                .font(.subheadline)
                .foregroundStyle(palette.primaryText)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 8)

            HStack(spacing: 8) {
                stepButton(symbol: "minus", enabled: canDecrease, delta: -1)

                Text(value)
                    .font(.body.weight(.medium))
                    .monospacedDigit()
                    .foregroundStyle(palette.primaryText)
                    .frame(minWidth: 72, minHeight: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(palette.chip)
                    )

                stepButton(symbol: "plus", enabled: canIncrease, delta: 1)
            }
        }
        // One accessibility element with an adjustable value beats three
        // separate buttons for VoiceOver users.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(LocalizedStringKey(titleKey)))
        .accessibilityValue(Text(value))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: if canIncrease { onStep(1) }
            case .decrement: if canDecrease { onStep(-1) }
            @unknown default: break
            }
        }
    }

    private func stepButton(symbol: String, enabled: Bool, delta: Int) -> some View {
        Button {
            onStep(delta)
        } label: {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(enabled ? palette.primaryText : palette.disabledText)
                .frame(width: 44, height: 44)
                .background(Circle().fill(palette.chip))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

/// Landscape variant of `TemperatureRow`: the label sits *above* the stepper so
/// three of them fit side by side. Same 44 pt hit targets, same single
/// adjustable accessibility element — only the arrangement differs.
struct CompactTemperatureCell: View {
    @Environment(\.palette) private var palette

    var titleKey: String
    var value: String
    var canDecrease: Bool
    var canIncrease: Bool
    var onStep: (Int) -> Void

    var body: some View {
        VStack(spacing: 6) {
            Text(LocalizedStringKey(titleKey))
                .font(.caption2)
                .foregroundStyle(palette.secondaryText)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            HStack(spacing: 3) {
                stepButton(symbol: "minus", enabled: canDecrease, delta: -1)

                Text(value)
                    .font(.subheadline.weight(.medium))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    .foregroundStyle(palette.primaryText)
                    .frame(minWidth: 56, maxWidth: .infinity, minHeight: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(palette.chip)
                    )

                stepButton(symbol: "plus", enabled: canIncrease, delta: 1)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(LocalizedStringKey(titleKey)))
        .accessibilityValue(Text(value))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: if canIncrease { onStep(1) }
            case .decrement: if canDecrease { onStep(-1) }
            @unknown default: break
            }
        }
    }

    private func stepButton(symbol: String, enabled: Bool, delta: Int) -> some View {
        Button {
            onStep(delta)
        } label: {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(enabled ? palette.primaryText : palette.disabledText)
                .frame(width: 44, height: 44)
                .background(Circle().fill(palette.chip))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

// MARK: - Action buttons

struct PrimaryActionButton: View {
    @Environment(\.palette) private var palette

    var titleKey: String
    var systemImage: String
    var isEnabled: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                Text(LocalizedStringKey(titleKey))
                    .font(.body.weight(.semibold))
            }
            .foregroundStyle(isEnabled ? palette.accentText : palette.disabledText)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 52)
            .background(
                Capsule(style: .continuous)
                    .fill(isEnabled ? palette.accent : palette.chip)
            )
            // Refuse vertical compression: without this the button silently
            // shrinks and clips its label when the column is short, instead of
            // letting ViewThatFits switch to the scrolling variant.
            .fixedSize(horizontal: false, vertical: true)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

struct SecondaryActionButton: View {
    @Environment(\.palette) private var palette

    var titleKey: String
    var isEnabled: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(LocalizedStringKey(titleKey))
                .font(.body)
                .foregroundStyle(isEnabled ? palette.primaryText : palette.disabledText)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 52)
                .background(
                    Capsule(style: .continuous)
                        .fill(palette.chip.opacity(isEnabled ? 1 : 0.5))
                )
                .fixedSize(horizontal: false, vertical: true)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}
