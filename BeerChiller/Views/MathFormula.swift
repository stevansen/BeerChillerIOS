//
//  MathFormula.swift
//  BeerCHILLER
//
//  A small typesetter for the LaTeX subset used by the localized help pages.
//
//  The first version of the help screen flattened the formulas to Unicode text.
//  That fails in three visible ways: Unicode has no subscript capitals, so `T_D`
//  kept its underscore; fractions collapsed to `(a − b)/(c − d)` on one line; and
//  hyphens stood in for minus signs. This renders the formulas as real layout
//  instead — stacked fractions with a rule, true sub/superscripts, italic
//  variables against upright numerals, and proper minus signs.
//
//  Everything scales with Dynamic Type via a single base size.
//

import SwiftUI

// MARK: - Model

indirect enum MathNode {
    /// A variable — set in italic, per maths convention.
    case variable(String)
    /// A numeral or operator — set upright.
    case plain(String)
    /// A function name such as `ln`, set upright.
    case function(String)
    /// Several nodes in sequence.
    case row([MathNode])
    case superscript(base: MathNode, exponent: MathNode)
    case `subscript`(base: MathNode, index: MathNode)
    /// Both at once, stacked on the same base.
    case subsuperscript(base: MathNode, index: MathNode, exponent: MathNode)
    /// A stacked fraction.
    case fraction(numerator: MathNode, denominator: MathNode)
    /// A parenthesised group whose delimiters grow with the content.
    case delimited(open: String, content: MathNode, close: String)
    /// A base with a combining dot above (time derivative).
    case dotted(MathNode)
}

// MARK: - Parser

/// Recursive-descent parser for the commands the help files actually use.
/// Anything unrecognised is passed through as plain text rather than dropped, so
/// a formula never silently loses a term.
struct MathParser {

    private let scalars: [Character]
    private var index = 0

    init(_ latex: String) {
        scalars = Array(latex)
    }

    static func parse(_ latex: String) -> MathNode {
        var parser = MathParser(latex)
        return parser.parseSequence(until: nil)
    }

    // MARK: Scanning

    private var current: Character? {
        index < scalars.count ? scalars[index] : nil
    }

    private mutating func advance() -> Character? {
        guard index < scalars.count else { return nil }
        defer { index += 1 }
        return scalars[index]
    }

    private mutating func skipSpaces() {
        while let character = current, character == " " || character == "\t" {
            index += 1
        }
    }

    /// Reads a `{…}` group without interpreting it, brace-balanced.
    private mutating func readRawGroup() -> String {
        skipSpaces()
        guard current == "{" else {
            return advance().map(String.init) ?? ""
        }
        index += 1
        var depth = 1
        var content = ""
        while let character = advance() {
            if character == "{" {
                depth += 1
            } else if character == "}" {
                depth -= 1
                if depth == 0 { break }
            }
            content.append(character)
        }
        return content
    }

    private mutating func readCommand() -> String {
        var name = ""
        while let character = current, character.isLetter {
            name.append(character)
            index += 1
        }
        // Single non-letter commands: \, \; \! \(
        if name.isEmpty, let character = advance() {
            name = String(character)
        }
        return name
    }

    // MARK: Grammar

    private mutating func parseSequence(until terminator: Character?) -> MathNode {
        var nodes: [MathNode] = []
        while let character = current {
            if let terminator, character == terminator {
                index += 1
                break
            }
            // `\right)` ends a delimited group; leave it for the caller.
            if character == "\\", peekCommand() == "right" {
                break
            }
            guard let node = parseWithScripts() else { continue }
            nodes.append(node)
        }
        return Self.normalize(nodes)
    }

    /// Unit symbols that may follow a numeral directly in these documents.
    /// Deliberately a short allow-list of upper-case SI symbols: lower-case
    /// single letters like `n`, `t` or `k` are variables here, not units.
    private static let unitSymbols: Set<Character> = ["K", "J", "W"]

    /// Relations get a consistent hair space on both sides, and any literal
    /// spaces around them are dropped so `a=b` and `a = b` typeset identically.
    private static let relations: Set<String> = ["=", "∼", "≈", "≤", "≥", "≠", "\u{00B7}"]

    private static func normalize(_ nodes: [MathNode]) -> MathNode {
        var result: [MathNode] = []
        for node in nodes {
            if case let .plain(value) = node, relations.contains(value) {
                while case let .plain(last)? = result.last, last.trimmingCharacters(
                    in: .whitespaces).isEmpty {
                    result.removeLast()
                }
                result.append(.plain("\u{2009}" + value + "\u{2009}"))
                continue
            }
            // A space directly after a relation is already covered by the padding.
            if case let .plain(value) = node,
               value.trimmingCharacters(in: .whitespaces).isEmpty,
               case let .plain(last)? = result.last,
               relations.contains(last.trimmingCharacters(in: .whitespaces)) {
                continue
            }
            result.append(node)
        }
        return result.count == 1 ? result[0] : .row(result)
    }

    private func peekCommand() -> String? {
        var cursor = index + 1
        var name = ""
        while cursor < scalars.count, scalars[cursor].isLetter {
            name.append(scalars[cursor])
            cursor += 1
        }
        return name.isEmpty ? nil : name
    }

    /// An atom plus any `_`/`^` attached to it.
    private mutating func parseWithScripts() -> MathNode? {
        guard var base = parseAtom() else { return nil }
        var index_: MathNode?
        var exponent: MathNode?

        while let character = current, character == "_" || character == "^" {
            index += 1
            guard let script = parseAtom() else { break }
            if character == "_" {
                index_ = script
            } else {
                exponent = script
            }
        }

        switch (index_, exponent) {
        case let (some?, exp?):
            base = .subsuperscript(base: base, index: some, exponent: exp)
        case let (some?, nil):
            base = .subscript(base: base, index: some)
        case let (nil, exp?):
            base = .superscript(base: base, exponent: exp)
        case (nil, nil):
            break
        }
        return base
    }

    private mutating func parseAtom() -> MathNode? {
        guard let character = current else { return nil }

        switch character {
        case "\\":
            index += 1
            return parseCommand(readCommand())

        case "{":
            index += 1
            return parseSequence(until: "}")

        case "}":
            index += 1
            return nil

        case " ", "\t", "\n":
            index += 1
            return .plain(" ")

        case "-":
            index += 1
            return .plain("\u{2212}")            // real minus, not a hyphen

        case "(", ")", "[", "]", "=", "+", "<", ">", "|", "/", ",", ".", ";", ":":
            index += 1
            return .plain(String(character))

        default:
            if character.isNumber {
                var digits = ""
                while let next = current, next.isNumber || next == "." {
                    digits.append(next)
                    index += 1
                }
                // A unit right after a number: thin space between the two, and
                // the unit set upright — units are not variables, so `25K`
                // becomes an upright "25 K" rather than an italic run-together.
                if let next = current, Self.unitSymbols.contains(next) {
                    index += 1
                    return .row([.plain(digits), .plain("\u{2009}"), .plain(String(next))])
                }
                return .plain(digits)
            }
            if character.isLetter {
                index += 1
                return .variable(String(character))
            }
            index += 1
            return .plain(String(character))
        }
    }

    private mutating func parseCommand(_ name: String) -> MathNode? {
        switch name {
        case "frac":
            let numerator = parseAtom() ?? .plain("")
            let denominator = parseAtom() ?? .plain("")
            return .fraction(numerator: numerator, denominator: denominator)

        case "left":
            let open = advance().map(String.init) ?? "("
            let content = parseSequence(until: nil)
            // Consume the matching \right<delim>.
            var close = ")"
            if current == "\\" {
                index += 1
                _ = readCommand()                 // "right"
                close = advance().map(String.init) ?? ")"
            }
            return .delimited(open: open, content: content, close: close)

        case "text", "mathrm", "operatorname":
            // The braces hold literal words ("min"), not maths. They must be
            // taken verbatim and set upright — parsing them would both italicise
            // the letters and, before this existed, leave the command name behind
            // as text, printing "textmin" instead of "min".
            return .plain(readRawGroup())

        case "dot":
            // `\dot Q` has a space before the base; without skipping it the
            // accent would attach to the blank and float in front of the letter.
            skipSpaces()
            return .dotted(parseAtom() ?? .plain(""))

        case "ln", "log", "exp", "min", "max":
            return .function(name)

        // Spacing commands. `\,` is a thin space in LaTeX, which is exactly
        // what belongs between a number and its unit: 62 min.
        case ",":
            return .plain("\u{2009}")
        case ";", " ":
            return .plain(" ")
        case "!":
            return nil

        default:
            if let symbol = Self.symbols[name] {
                return symbol
            }
            // Unknown command: keep the name visible rather than dropping it.
            return .plain(name)
        }
    }

    /// Greek letters keep the maths convention: lower case italic, upper case
    /// upright.
    private static let symbols: [String: MathNode] = [
        "Delta": .plain("Δ"), "Theta": .plain("Θ"),
        "delta": .variable("δ"), "theta": .variable("θ"),
        "tau": .variable("τ"), "alpha": .variable("α"), "beta": .variable("β"),
        "lambda": .variable("λ"), "rho": .variable("ρ"), "pi": .variable("π"),
        "cdot": .plain("\u{00B7}"), "times": .plain("×"),
        "approx": .plain("≈"), "sim": .plain("∼"),
        "leq": .plain("≤"), "geq": .plain("≥"), "neq": .plain("≠"),
        "le": .plain("≤"), "ge": .plain("≥"), "ne": .plain("≠"),
        "lceil": .plain("⌈"), "rceil": .plain("⌉"),
        "lfloor": .plain("⌊"), "rfloor": .plain("⌋"),
        "infty": .plain("∞"),
    ]
}

extension MathNode {
    /// Every literal run concatenated, ignoring layout. Used by the tests to
    /// prove that no LaTeX command name leaks into the rendered output.
    var flattenedText: String {
        switch self {
        case let .variable(value), let .plain(value), let .function(value):
            return value
        case let .row(children):
            return children.map(\.flattenedText).joined()
        case let .superscript(base, exponent):
            return base.flattenedText + exponent.flattenedText
        case let .subscript(base, index):
            return base.flattenedText + index.flattenedText
        case let .subsuperscript(base, index, exponent):
            return base.flattenedText + index.flattenedText + exponent.flattenedText
        case let .fraction(numerator, denominator):
            return numerator.flattenedText + denominator.flattenedText
        case let .delimited(open, content, close):
            return open + content.flattenedText + close
        case let .dotted(base):
            return base.flattenedText
        }
    }
}

// MARK: - Display rendering

/// The maths axis — the height the fraction rule and the `=` sign share — sits a
/// little above the text baseline. Aligning on it is what makes a formula look
/// typeset rather than stacked.
private extension VerticalAlignment {
    struct MathAxisID: AlignmentID {
        static func defaultValue(in context: ViewDimensions) -> CGFloat {
            context[VerticalAlignment.center]
        }
    }
    static let mathAxis = VerticalAlignment(MathAxisID.self)
}

/// Renders a parsed formula as layout. Fractions become stacked views; anything
/// else collapses into a single `Text` so the runs share one baseline.
struct MathView: View {
    let node: MathNode
    var size: CGFloat

    var body: some View {
        HStack(alignment: .mathAxis, spacing: 0) {
            ForEach(Array(chunks.enumerated()), id: \.offset) { _, chunk in
                switch chunk {
                case let .text(text):
                    text
                        .alignmentGuide(.mathAxis) { dimension in
                            dimension[.firstTextBaseline] - size * 0.26
                        }
                case let .node(node):
                    MathView.stacked(node, size: size)
                }
            }
        }
    }

    // MARK: Chunking

    private enum Chunk {
        case text(Text)
        case node(MathNode)
    }

    /// Splits the row into runs that can live in one `Text` and the ones that
    /// need real layout (fractions, and any group containing one).
    private var chunks: [Chunk] {
        var result: [Chunk] = []
        var pending: [MathNode] = []

        func flush() {
            guard !pending.isEmpty else { return }
            result.append(.text(MathTextBuilder.text(for: .row(pending), size: size)))
            pending = []
        }

        for child in Self.flatten(node) {
            if Self.needsLayout(child) {
                flush()
                result.append(.node(child))
            } else {
                pending.append(child)
            }
        }
        flush()
        return result
    }

    private static func flatten(_ node: MathNode) -> [MathNode] {
        if case let .row(children) = node { return children }
        return [node]
    }

    /// True when the node cannot be expressed as inline text.
    private static func needsLayout(_ node: MathNode) -> Bool {
        switch node {
        case .fraction:
            return true
        case let .delimited(_, content, _):
            return needsLayout(content)
        case let .row(children):
            return children.contains(where: needsLayout)
        case let .superscript(base, exponent):
            return needsLayout(base) || needsLayout(exponent)
        case let .subscript(base, index):
            return needsLayout(base) || needsLayout(index)
        case .subsuperscript:
            // An index and an exponent on the same base have to be stacked
            // vertically; a single Text run can only place them side by side.
            return true
        case .variable, .plain, .function, .dotted:
            return false
        }
    }

    // MARK: Layout for the pieces that need it

    @ViewBuilder
    static func stacked(_ node: MathNode, size: CGFloat) -> some View {
        switch node {
        case let .fraction(numerator, denominator):
            VStack(spacing: size * 0.14) {
                MathView(node: numerator, size: size)
                Rectangle()
                    .frame(height: max(1, size * 0.055))
                    .frame(minWidth: size * 0.9)
                MathView(node: denominator, size: size)
            }
            .fixedSize()
            .alignmentGuide(.mathAxis) { $0[VerticalAlignment.center] }

        case let .delimited(open, content, close):
            HStack(alignment: .mathAxis, spacing: size * 0.04) {
                ScalingDelimiter(symbol: open, size: size)
                MathView(node: content, size: size)
                ScalingDelimiter(symbol: close, size: size)
            }

        case let .superscript(base, exponent):
            HStack(alignment: .top, spacing: 0) {
                MathView(node: base, size: size)
                MathView(node: exponent, size: size * 0.62)
                    .padding(.top, -size * 0.1)
            }
            .alignmentGuide(.mathAxis) { $0[VerticalAlignment.center] }

        case let .subscript(base, index):
            HStack(alignment: .bottom, spacing: 0) {
                MathView(node: base, size: size)
                MathView(node: index, size: size * 0.62)
                    .padding(.bottom, -size * 0.06)
            }
            .alignmentGuide(.mathAxis) { $0[VerticalAlignment.center] }

        case let .subsuperscript(base, index, exponent):
            HStack(alignment: .mathAxis, spacing: 0) {
                MathView(node: base, size: size)
                VStack(alignment: .leading, spacing: 0) {
                    MathView(node: exponent, size: size * 0.62)
                    MathView(node: index, size: size * 0.62)
                }
            }

        case let .row(children):
            HStack(alignment: .mathAxis, spacing: 0) {
                ForEach(Array(children.enumerated()), id: \.offset) { _, child in
                    MathView(node: child, size: size)
                }
            }

        default:
            MathView(node: node, size: size)
        }
    }
}

/// A bracket that grows to the height of what it wraps, the way `\left(` does.
private struct ScalingDelimiter: View {
    let symbol: String
    let size: CGFloat

    var body: some View {
        GeometryReader { geometry in
            Text(symbol)
                .font(.system(size: size, design: .serif))
                .scaleEffect(x: 1, y: max(1, geometry.size.height / (size * 1.1)),
                             anchor: .center)
                .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .frame(width: size * 0.34)
    }
}

// MARK: - Text rendering (inline and within display rows)

enum MathTextBuilder {

    /// Builds a single `Text` from a node that contains no fractions. Sub- and
    /// superscripts use a smaller font plus a baseline offset, which keeps them
    /// correct at every Dynamic Type size — including `T_D`, where Unicode has no
    /// subscript capital to fall back on.
    static func text(for node: MathNode, size: CGFloat) -> Text {
        switch node {
        case let .variable(value):
            return Text(value)
                .font(.system(size: size, design: .serif).italic())

        case let .plain(value):
            return Text(value)
                .font(.system(size: size, design: .serif))

        case let .function(value):
            return Text(value)
                .font(.system(size: size, design: .serif))

        case let .row(children):
            return children.reduce(Text("")) { partial, child in
                partial + text(for: child, size: size)
            }

        case let .superscript(base, exponent):
            return text(for: base, size: size)
                + text(for: exponent, size: size * 0.62)
                    .baselineOffset(size * 0.38)

        case let .subscript(base, index):
            return text(for: base, size: size)
                + text(for: index, size: size * 0.62)
                    .baselineOffset(-size * 0.16)

        case let .subsuperscript(base, index, exponent):
            return text(for: base, size: size)
                + text(for: exponent, size: size * 0.62).baselineOffset(size * 0.38)
                + text(for: index, size: size * 0.62).baselineOffset(-size * 0.16)

        case let .delimited(open, content, close):
            return Text(open).font(.system(size: size, design: .serif))
                + text(for: content, size: size)
                + Text(close).font(.system(size: size, design: .serif))

        case let .fraction(numerator, denominator):
            // Only reached for inline maths, where a stacked rule would break the
            // line box; a solidus is the conventional inline form.
            return Text("(").font(.system(size: size, design: .serif))
                + text(for: numerator, size: size)
                + Text(")/(").font(.system(size: size, design: .serif))
                + text(for: denominator, size: size)
                + Text(")").font(.system(size: size, design: .serif))

        case let .dotted(base):
            // The combining mark must be in the *same* run as the glyph it sits
            // on; in a run of its own it renders as a loose dot beside the letter.
            if case let .variable(value) = base {
                return Text(value + "\u{0307}")
                    .font(.system(size: size, design: .serif).italic())
            }
            if case let .plain(value) = base {
                return Text(value + "\u{0307}")
                    .font(.system(size: size, design: .serif))
            }
            return text(for: base, size: size)
        }
    }

    /// Inline maths for a run of prose.
    static func inlineText(_ latex: String, size: CGFloat) -> Text {
        text(for: MathParser.parse(latex), size: size)
    }
}
