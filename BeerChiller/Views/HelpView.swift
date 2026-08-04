//
//  HelpView.swift
//  BeerCHILLER
//
//  The localized "calculation model" page. The Android original ships the same
//  markdown files and renders the LaTeX with a bundled KaTeX + WebView. On iOS
//  that would mean shipping a browser stack for ten static documents, so the
//  formulas are typeset natively instead (see MathFormula.swift) — no WebView,
//  works offline, scales with Dynamic Type, readable by VoiceOver.
//

import SwiftUI

struct HelpView: View {

    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @ScaledMetric(relativeTo: .body) private var mathSize: CGFloat = 17

    @State private var blocks: [HelpBlock] = []
    @State private var didFail = false

    var body: some View {
        NavigationStack {
            ScrollView {
                if didFail {
                    Text(LocalizedStringKey("help_load_error"))
                        .font(.body)
                        .foregroundStyle(palette.secondaryText)
                        .padding()
                } else {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(blocks) { block in
                            view(for: block)
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: 700, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .background(palette.background.ignoresSafeArea())
            .navigationTitle(Text(LocalizedStringKey("calculation_model_title")))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button { dismiss() } label: {
                        Text(LocalizedStringKey("close"))
                    }
                }
            }
        }
        .task { load() }
    }

    @ViewBuilder
    private func view(for block: HelpBlock) -> some View {
        switch block.kind {
        case .title:
            HelpRichText(line: block.text, size: mathSize, style: .title)
                .foregroundStyle(palette.primaryText)

        case .heading:
            HelpRichText(line: block.text, size: mathSize, style: .heading)
                .foregroundStyle(palette.primaryText)
                .padding(.top, 8)

        case .paragraph:
            HelpRichText(line: block.text, size: mathSize, style: .body)
                .foregroundStyle(palette.primaryText)
                .fixedSize(horizontal: false, vertical: true)

        case .bullet:
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\u{2022}").foregroundStyle(palette.secondaryText)
                HelpRichText(line: block.text, size: mathSize, style: .body)
                    .foregroundStyle(palette.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.leading, 4)

        case .formula:
            FormulaCard(latex: block.text, size: mathSize)

        case .tableRow:
            HelpRichText(line: block.text, size: mathSize, style: .tableRow)
                .foregroundStyle(palette.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func load() {
        guard blocks.isEmpty else { return }
        guard let markdown = HelpLoader.markdownForCurrentLanguage() else {
            didFail = true
            return
        }
        blocks = HelpMarkdownParser.parse(markdown)
    }
}

// MARK: - Display formula

/// A centred, typeset formula on its own card. Wide formulas scroll sideways
/// rather than shrinking to illegibility or clipping.
private struct FormulaCard: View {
    @Environment(\.palette) private var palette
    let latex: String
    let size: CGFloat

    private var node: MathNode { MathParser.parse(latex) }

    var body: some View {
        // Centred when it fits; only the handful of very wide formulas fall back
        // to sideways scrolling, which beats clipping or shrinking them.
        ViewThatFits(in: .horizontal) {
            MathView(node: node, size: size * 1.1)
                .padding(.vertical, 14)
                .padding(.horizontal, 18)
                .frame(maxWidth: .infinity)

            ScrollView(.horizontal, showsIndicators: false) {
                MathView(node: node, size: size * 1.1)
                    .padding(.vertical, 14)
                    .padding(.horizontal, 18)
            }
        }
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(palette.surface)
        )
        // VoiceOver gets the plain-text form; the visual layout is decoration.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(MathSpeech.describe(node)))
    }
}

// MARK: - Prose with inline maths

/// One line of help prose. Inline `\( … \)` spans are typeset as maths, `**…**`
/// as bold, everything else as body text — all concatenated into a single `Text`
/// so the line wraps and shares one baseline.
private struct HelpRichText: View {
    enum Style { case title, heading, body, tableRow }

    let line: String
    let size: CGFloat
    let style: Style

    var body: some View {
        segments.reduce(Text("")) { partial, segment in
            switch segment {
            case let .literal(value, bold):
                return partial + Text(value).font(bold ? boldFont : font)
            case let .math(latex):
                return partial + MathTextBuilder.inlineText(latex, size: mathSize)
            }
        }
    }

    private var font: Font {
        switch style {
        case .title: return .system(size: size * 1.4, weight: .bold)
        case .heading: return .system(size: size * 1.05, weight: .semibold)
        case .body: return .system(size: size)
        case .tableRow: return .system(size: size * 0.85, design: .monospaced)
        }
    }

    private var boldFont: Font {
        switch style {
        case .title: return .system(size: size * 1.4, weight: .bold)
        case .heading: return .system(size: size * 1.05, weight: .bold)
        case .body: return .system(size: size, weight: .semibold)
        case .tableRow: return .system(size: size * 0.85, design: .monospaced)
        }
    }

    private var mathSize: CGFloat {
        switch style {
        case .title: return size * 1.4
        case .heading: return size * 1.05
        case .body: return size
        case .tableRow: return size * 0.85
        }
    }

    private enum Segment {
        case literal(String, bold: Bool)
        case math(String)
    }

    private var segments: [Segment] {
        var result: [Segment] = []
        var remainder = Substring(line)

        while let open = remainder.range(of: "\\(") {
            let before = String(remainder[remainder.startIndex..<open.lowerBound])
            result.append(contentsOf: Self.literals(before))

            let afterOpen = remainder[open.upperBound...]
            guard let close = afterOpen.range(of: "\\)") else {
                result.append(contentsOf: Self.literals(String(afterOpen)))
                return result
            }
            result.append(.math(String(afterOpen[afterOpen.startIndex..<close.lowerBound])))
            remainder = afterOpen[close.upperBound...]
        }
        result.append(contentsOf: Self.literals(String(remainder)))
        return result
    }

    /// Splits plain prose on `**` so emphasis survives.
    private static func literals(_ text: String) -> [Segment] {
        guard text.contains("**") else {
            return text.isEmpty ? [] : [.literal(text, bold: false)]
        }
        var result: [Segment] = []
        var isBold = false
        for part in text.components(separatedBy: "**") {
            if !part.isEmpty {
                result.append(.literal(part, bold: isBold))
            }
            isBold.toggle()
        }
        return result
    }
}

// MARK: - Spoken form

/// Turns a formula into something VoiceOver can read out. Symbols become words,
/// because "Δ₀ = T₀ − T_D" read character by character is useless.
enum MathSpeech {

    static func describe(_ node: MathNode) -> String {
        let raw = spoken(node)
            .replacingOccurrences(of: "  ", with: " ")
        return raw.trimmingCharacters(in: .whitespaces)
    }

    private static func spoken(_ node: MathNode) -> String {
        switch node {
        case let .variable(value):
            return " " + (words[value] ?? value) + " "
        case let .plain(value):
            return words[value] ?? value
        case let .function(value):
            return " " + value + " "
        case let .row(children):
            return children.map(spoken).joined()
        case let .superscript(base, exponent):
            return spoken(base) + Formatting.localized("math_to_the_power_of")
                + spoken(exponent) + " "
        case let .subscript(base, index):
            return spoken(base) + " " + Formatting.localized("math_sub")
                + " " + spoken(index) + " "
        case let .subsuperscript(base, index, exponent):
            return spoken(.subscript(base: base, index: index))
                + Formatting.localized("math_to_the_power_of") + spoken(exponent) + " "
        case let .fraction(numerator, denominator):
            return " " + spoken(numerator) + Formatting.localized("math_divided_by")
                + spoken(denominator) + " "
        case let .delimited(_, content, _):
            return " ( " + spoken(content) + " ) "
        case let .dotted(base):
            return spoken(base)
        }
    }

    private static let words: [String: String] = [
        "Δ": "Delta", "Θ": "Theta", "δ": "delta", "θ": "theta",
        "τ": "tau", "α": "alpha", "β": "beta", "λ": "lambda",
        "ρ": "rho", "π": "pi",
        "\u{2212}": " minus ", "+": " plus ", "=": " = ",
        "\u{00B7}": " × ", "×": " × ", "∼": " ~ ", "≈": " ≈ ",
        "≤": " ≤ ", "≥": " ≥ ", "≠": " ≠ ",
        "⌈": " ", "⌉": " ", "⌊": " ", "⌋": " ",
    ]
}

// MARK: - Loading

enum HelpLoader {

    /// Picks the help file matching the user's language, falling back to English.
    static func markdownForCurrentLanguage() -> String? {
        for code in candidateLanguageCodes() {
            if let url = Bundle.main.url(forResource: "cooling_model_\(code)",
                                         withExtension: "md"),
               let text = try? String(contentsOf: url, encoding: .utf8) {
                return text
            }
        }
        return nil
    }

    private static func candidateLanguageCodes() -> [String] {
        var codes: [String] = []
        for identifier in Bundle.main.preferredLocalizations + Locale.preferredLanguages {
            let base = Locale(identifier: identifier).identifier
                .split(separator: "-").first
                .map(String.init) ?? identifier
            if !codes.contains(base) { codes.append(base) }
        }
        if !codes.contains("en") { codes.append("en") }
        return codes
    }
}

// MARK: - Markdown parsing

struct HelpBlock: Identifiable {
    enum Kind { case title, heading, paragraph, bullet, formula, tableRow }
    let id = UUID()
    let kind: Kind
    /// For `.formula` this is raw LaTeX; otherwise the raw line, inline maths and
    /// emphasis markers intact, to be handled at render time.
    let text: String
}

enum HelpMarkdownParser {

    static func parse(_ markdown: String) -> [HelpBlock] {
        var blocks: [HelpBlock] = []
        var formulaLines: [String] = []
        var inFormula = false

        for rawLine in markdown.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)

            // Display maths: \[ … \]
            if line == "\\[" {
                inFormula = true
                formulaLines = []
                continue
            }
            if line == "\\]" {
                inFormula = false
                let latex = formulaLines.joined(separator: " ")
                    .trimmingCharacters(in: .whitespaces)
                if !latex.isEmpty {
                    blocks.append(HelpBlock(kind: .formula, text: latex))
                }
                continue
            }
            if inFormula {
                formulaLines.append(line)
                continue
            }

            if line.isEmpty { continue }

            if line.hasPrefix("## ") {
                blocks.append(HelpBlock(kind: .heading, text: String(line.dropFirst(3))))
            } else if line.hasPrefix("# ") {
                blocks.append(HelpBlock(kind: .title, text: String(line.dropFirst(2))))
            } else if line.hasPrefix("- ") || line.hasPrefix("* ") {
                blocks.append(HelpBlock(kind: .bullet, text: String(line.dropFirst(2))))
            } else if line.hasPrefix("|") {
                // Skip the |---|---| separator rows.
                let stripped = line.replacingOccurrences(of: "|", with: "")
                    .replacingOccurrences(of: "-", with: "")
                    .replacingOccurrences(of: ":", with: "")
                    .trimmingCharacters(in: .whitespaces)
                guard !stripped.isEmpty else { continue }
                let cells = line.split(separator: "|", omittingEmptySubsequences: true)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                blocks.append(HelpBlock(kind: .tableRow,
                                        text: cells.joined(separator: "   \u{00B7}   ")))
            } else {
                blocks.append(HelpBlock(kind: .paragraph, text: line))
            }
        }
        return blocks
    }
}
