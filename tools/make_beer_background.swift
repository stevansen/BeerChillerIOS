//
//  make_beer_background.swift
//  BeerCHILLER — asset generation
//
//  Draws the two beer backgrounds procedurally instead of shipping a photograph.
//
//  The original Android app used a stock-looking photo of a beer glass whose
//  provenance is unknown; a photo with an unclear licence is not something to put
//  in an App Store binary. Everything here is generated from primitives — no
//  source imagery — so the result is an original work with no third-party rights
//  attached, and it can be regenerated or retuned at any time.
//
//  Two variants:
//    light — a pale lager: straw to deep gold, thick white head
//    dark  — a dunkel/stout: mahogany to near-black, tan head
//
//  Both are a glass of beer seen close up: the body of the beer with its vertical
//  gradient, a foam head at the top, carbonation rising through the liquid, and
//  condensation on the outside of the glass. The condensation is what sells
//  "cold", so it gets the most care: each drop is a lens, which means a darker
//  rim, a bright specular highlight offset towards the light, and a soft shadow
//  below it.
//
//  Usage:
//    swift tools/make_beer_background.swift <light|dark> <out.png> [width height]
//

import AppKit

// MARK: - Deterministic randomness
//
// A fixed sequence keeps the output reproducible: regenerating gives the exact
// same image, so the asset does not churn in git for no reason.
struct Random {
    private var state: UInt64
    init(seed: UInt64) { state = seed == 0 ? 0x9E3779B97F4A7C15 : seed }

    mutating func next() -> UInt64 {
        state ^= state >> 12
        state ^= state << 25
        state ^= state >> 27
        return state &* 2685821657736338717
    }
    mutating func unit() -> Double { Double(next() % 1_000_000) / 1_000_000.0 }
    mutating func range(_ lower: Double, _ upper: Double) -> Double {
        lower + unit() * (upper - lower)
    }
}

// MARK: - Palettes

struct Palette {
    let beerStops: [(Double, (Double, Double, Double))]
    let foamTop: (Double, Double, Double)
    let foamBottom: (Double, Double, Double)
    let foamHeight: Double          // fraction of the image
    let bubble: (Double, Double, Double)
    let dropTint: (Double, Double, Double)
    let dropHighlight: (Double, Double, Double)
    let dropOpacity: Double

    static let light = Palette(
        beerStops: [
            (0.00, (0.99, 0.86, 0.55)),   // straw, just under the head
            (0.28, (0.97, 0.74, 0.20)),
            (0.62, (0.91, 0.60, 0.07)),
            (1.00, (0.72, 0.42, 0.03)),   // deep gold at the base
        ],
        foamTop: (1.00, 0.99, 0.96),
        foamBottom: (0.96, 0.91, 0.79),
        foamHeight: 0.14,
        bubble: (1.00, 0.97, 0.86),
        dropTint: (0.35, 0.20, 0.01),
        dropHighlight: (1.00, 0.99, 0.94),
        dropOpacity: 0.62
    )

    static let dark = Palette(
        beerStops: [
            (0.00, (0.42, 0.20, 0.07)),   // mahogany under the head
            (0.30, (0.28, 0.12, 0.04)),
            (0.65, (0.16, 0.07, 0.02)),
            (1.00, (0.06, 0.03, 0.01)),   // near-black at the base
        ],
        foamTop: (0.87, 0.77, 0.60),      // tan head, not white
        foamBottom: (0.70, 0.57, 0.38),
        foamHeight: 0.12,
        bubble: (0.85, 0.72, 0.52),
        dropTint: (0.02, 0.01, 0.00),
        dropHighlight: (0.98, 0.93, 0.84),
        dropOpacity: 0.52
    )
}

// MARK: - Drawing helpers

/// `extend` continues the end colours past the start and end points. Without it
/// `drawLinearGradient` paints nothing beyond them, which left the foam band above
/// the beer gradient's end point as bare black canvas — visible as black wedges
/// wherever the wavy foam edge did not cover it.
func gradient(_ context: CGContext, stops: [(Double, (Double, Double, Double))],
              from start: CGPoint, to end: CGPoint, alpha: Double = 1,
              extend: Bool = true) {
    let space = CGColorSpaceCreateDeviceRGB()
    var components: [CGFloat] = []
    var locations: [CGFloat] = []
    for (location, colour) in stops {
        components += [CGFloat(colour.0), CGFloat(colour.1), CGFloat(colour.2), CGFloat(alpha)]
        locations.append(CGFloat(location))
    }
    guard let gradient = CGGradient(colorSpace: space, colorComponents: components,
                                    locations: locations, count: stops.count) else { return }
    let options: CGGradientDrawingOptions =
        extend ? [.drawsBeforeStartLocation, .drawsAfterEndLocation] : []
    context.drawLinearGradient(gradient, start: start, end: end, options: options)
}

/// One condensation drop, drawn as a lens sitting on the outside of the glass.
///
/// The first attempt filled each drop with a beige tint, which made it
/// indistinguishable from the carbonation bubbles inside the beer — the whole
/// image read as one field of circles. A drop is almost colourless; what makes it
/// visible is how it bends light:
///
///   * a thin dark rim, where the surface curves away steepest
///   * a small hard specular dot where the light source reflects, top-left
///   * a bright caustic on the opposite side, where the lens focuses light
///   * a soft shadow cast down-right onto the glass
///
/// Keeping the body nearly transparent is what separates the drops from the
/// bubbles: the beer's own gradient shows through them.
func drawDrop(_ context: CGContext, at centre: CGPoint, radius: Double,
              palette: Palette) {
    let rect = CGRect(x: centre.x - radius, y: centre.y - radius,
                      width: radius * 2, height: radius * 2)
    let space = CGColorSpaceCreateDeviceRGB()

    // Shadow: puts the drop on top of the glass rather than in the liquid.
    context.saveGState()
    context.setShadow(offset: CGSize(width: radius * 0.18, height: -radius * 0.28),
                      blur: CGFloat(radius * 0.9),
                      color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.30))
    context.setFillColor(red: 1, green: 1, blue: 1, alpha: 0.02)
    context.fillEllipse(in: rect)
    context.restoreGState()

    context.saveGState()
    context.addEllipse(in: rect)
    context.clip()

    // Body: barely there, slightly lighter towards the caustic side.
    if let body = CGGradient(colorSpace: space, colorComponents: [
        CGFloat(palette.dropHighlight.0), CGFloat(palette.dropHighlight.1),
        CGFloat(palette.dropHighlight.2), CGFloat(palette.dropOpacity * 0.30),
        CGFloat(palette.dropHighlight.0), CGFloat(palette.dropHighlight.1),
        CGFloat(palette.dropHighlight.2), CGFloat(palette.dropOpacity * 0.06),
    ], locations: [0.0, 1.0], count: 2) {
        context.drawRadialGradient(
            body,
            startCenter: CGPoint(x: centre.x + radius * 0.30, y: centre.y - radius * 0.30),
            startRadius: 0,
            endCenter: centre, endRadius: CGFloat(radius * 1.1),
            options: [])
    }

    // Caustic: the lens concentrates light on the side away from the source.
    if let caustic = CGGradient(colorSpace: space, colorComponents: [
        CGFloat(palette.dropHighlight.0), CGFloat(palette.dropHighlight.1),
        CGFloat(palette.dropHighlight.2), CGFloat(min(1, palette.dropOpacity * 1.1)),
        CGFloat(palette.dropHighlight.0), CGFloat(palette.dropHighlight.1),
        CGFloat(palette.dropHighlight.2), 0,
    ], locations: [0.0, 1.0], count: 2) {
        context.drawRadialGradient(
            caustic,
            startCenter: CGPoint(x: centre.x + radius * 0.34, y: centre.y - radius * 0.34),
            startRadius: 0,
            endCenter: CGPoint(x: centre.x + radius * 0.34, y: centre.y - radius * 0.34),
            endRadius: CGFloat(radius * 0.62),
            options: [])
    }
    context.restoreGState()

    // Rim: thin, darker at the top-left where the surface turns away.
    context.saveGState()
    context.setLineWidth(CGFloat(max(0.6, radius * 0.10)))
    context.setStrokeColor(red: CGFloat(palette.dropTint.0), green: CGFloat(palette.dropTint.1),
                           blue: CGFloat(palette.dropTint.2),
                           alpha: CGFloat(palette.dropOpacity * 0.55))
    context.strokeEllipse(in: rect.insetBy(dx: CGFloat(radius * 0.05),
                                           dy: CGFloat(radius * 0.05)))
    context.restoreGState()

    // Specular dot: small and hard, this is what makes it look wet.
    let specular = radius * 0.22
    context.setFillColor(red: 1, green: 1, blue: 1,
                         alpha: CGFloat(min(1, palette.dropOpacity * 1.7)))
    context.fillEllipse(in: CGRect(x: centre.x - radius * 0.36 - specular,
                                   y: centre.y + radius * 0.36 - specular,
                                   width: specular * 2, height: specular * 2))
}

// MARK: - Main

let arguments = CommandLine.arguments
guard arguments.count >= 3 else {
    FileHandle.standardError.write(
        "usage: make_beer_background <light|dark> <out.png> [width height]\n".data(using: .utf8)!)
    exit(2)
}
let variant = arguments[1]
let outputPath = arguments[2]
let width = arguments.count >= 5 ? Int(arguments[3])! : 1290
let height = arguments.count >= 5 ? Int(arguments[4])! : 2796

let palette = variant == "dark" ? Palette.dark : Palette.light
// Separate seeds so the two variants do not share an identical drop pattern.
var random = Random(seed: variant == "dark" ? 0xB33FC0FFEE : 0xC0FFEEBEEF)

let space = CGColorSpaceCreateDeviceRGB()
guard let context = CGContext(data: nil, width: width, height: height,
                              bitsPerComponent: 8, bytesPerRow: 0, space: space,
                              bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
    fatalError("could not create a bitmap context")
}

let w = Double(width), h = Double(height)
let foamHeight = h * palette.foamHeight

// ---- the beer itself -------------------------------------------------------
// Painted over the *full* height, not clipped to just below the head. Clipping
// it left the area behind the wavy foam edge unpainted, which showed up as black
// wedges wherever the wobble dipped below the clip line.
gradient(context, stops: palette.beerStops.map { (1 - $0.0, $0.1) },
         from: CGPoint(x: 0, y: 0), to: CGPoint(x: 0, y: h - foamHeight))

// A soft vertical sheen down the middle: the glass is round, so the centre
// catches more light than the edges.
context.saveGState()
context.setBlendMode(.softLight)
if let sheen = CGGradient(colorSpace: space, colorComponents: [
    1, 1, 1, 0.0,  1, 1, 1, 0.30,  1, 1, 1, 0.0,
], locations: [0.0, 0.42, 1.0], count: 3) {
    context.drawLinearGradient(sheen, start: CGPoint(x: 0, y: 0),
                               end: CGPoint(x: w, y: 0), options: [])
}
context.restoreGState()

// ---- carbonation ----------------------------------------------------------
// Bubbles get smaller and sparser towards the base, where the pressure is
// higher and they have had less time to grow.
let bubbleCount = 150
for _ in 0..<bubbleCount {
    let y = random.range(0, h - foamHeight)
    let depth = y / (h - foamHeight)          // 0 at base, 1 just under the foam
    let radius = random.range(1.2, 2.0 + 5.0 * depth)
    let x = random.range(0, w)
    let alpha = random.range(0.05, 0.16) * (0.35 + 0.65 * depth)
    context.setFillColor(red: CGFloat(palette.bubble.0), green: CGFloat(palette.bubble.1),
                         blue: CGFloat(palette.bubble.2), alpha: CGFloat(alpha))
    context.fillEllipse(in: CGRect(x: x - radius, y: y - radius,
                                   width: radius * 2, height: radius * 2))
}

// ---- foam head ------------------------------------------------------------
// The underside of the head is clipped to a wavy path. Clipping to a rectangle
// left a ruled line across the image, which no glass of beer has.
func foamPath(width: Double, baseline: Double, top: Double) -> CGPath {
    let path = CGMutablePath()
    path.move(to: CGPoint(x: 0, y: top))
    path.addLine(to: CGPoint(x: width, y: top))
    path.addLine(to: CGPoint(x: width, y: baseline))
    var x = width
    while x >= 0 {
        let t = x / width
        let wobble = sin(t * 7.3) * 0.34 + sin(t * 17.1 + 1.2) * 0.18
                   + sin(t * 31.7 + 2.9) * 0.09
        path.addLine(to: CGPoint(x: x, y: baseline + wobble * (top - baseline) * 0.30))
        x -= width / 160
    }
    path.closeSubpath()
    return path
}

context.saveGState()
context.addPath(foamPath(width: w, baseline: h - foamHeight, top: h))
context.clip()
gradient(context, stops: [(0.0, palette.foamBottom), (1.0, palette.foamTop)],
         from: CGPoint(x: 0, y: h - foamHeight), to: CGPoint(x: 0, y: h))
// Foam is a mass of bubbles, not a flat block.
for _ in 0..<900 {
    let x = random.range(0, w)
    let y = random.range(h - foamHeight * 1.05, h)
    let radius = random.range(2, 13)
    let bright = random.range(0.80, 1.0)
    context.setFillColor(red: CGFloat(palette.foamTop.0 * bright),
                         green: CGFloat(palette.foamTop.1 * bright),
                         blue: CGFloat(palette.foamTop.2 * bright),
                         alpha: CGFloat(random.range(0.20, 0.60)))
    context.fillEllipse(in: CGRect(x: x - radius, y: y - radius,
                                   width: radius * 2, height: radius * 2))
}
context.restoreGState()

// An irregular boundary where the foam meets the beer, so the head does not end
// on a ruled line.
for _ in 0..<260 {
    let x = random.range(0, w)
    let y = h - foamHeight + random.range(-h * 0.035, h * 0.012)
    let radius = random.range(3, 16)
    context.setFillColor(red: CGFloat(palette.foamBottom.0),
                         green: CGFloat(palette.foamBottom.1),
                         blue: CGFloat(palette.foamBottom.2),
                         alpha: CGFloat(random.range(0.15, 0.55)))
    context.fillEllipse(in: CGRect(x: x - radius, y: y - radius,
                                   width: radius * 2, height: radius * 2))
}

// ---- condensation on the outside of the glass ------------------------------
// Three passes, large to small, so the drops read as a real distribution rather
// than one uniform size.
let passes: [(count: Int, minRadius: Double, maxRadius: Double)] = [
    (26, w * 0.026, w * 0.055),
    (78, w * 0.013, w * 0.026),
    (190, w * 0.006, w * 0.013),
]
for pass in passes {
    for _ in 0..<pass.count {
        let radius = random.range(pass.minRadius, pass.maxRadius)
        let centre = CGPoint(x: random.range(radius, w - radius),
                            y: random.range(radius, h - radius))
        drawDrop(context, at: centre, radius: radius, palette: palette)
    }
}

// A few drops that have run: a short tail above the drop.
for _ in 0..<26 {
    let radius = random.range(w * 0.008, w * 0.018)
    let x = random.range(radius, w - radius)
    let y = random.range(h * 0.12, h * 0.92)
    let tail = random.range(radius * 3, radius * 9)
    context.saveGState()
    context.setFillColor(red: CGFloat(palette.dropHighlight.0),
                         green: CGFloat(palette.dropHighlight.1),
                         blue: CGFloat(palette.dropHighlight.2),
                         alpha: CGFloat(palette.dropOpacity * 0.22))
    context.fill(CGRect(x: x - radius * 0.28, y: y, width: radius * 0.56, height: tail))
    context.restoreGState()
    drawDrop(context, at: CGPoint(x: x, y: y), radius: radius, palette: palette)
}

// ---- vignette -------------------------------------------------------------
// Darkens the edges so UI text laid over the image keeps its contrast.
if let vignette = CGGradient(colorSpace: space, colorComponents: [
    0, 0, 0, 0.0,  0, 0, 0, 0.10,  0, 0, 0, 0.42,
], locations: [0.0, 0.62, 1.0], count: 3) {
    context.drawRadialGradient(
        vignette,
        startCenter: CGPoint(x: w / 2, y: h * 0.58), startRadius: 0,
        endCenter: CGPoint(x: w / 2, y: h * 0.58), endRadius: CGFloat(max(w, h) * 0.72),
        options: [.drawsAfterEndLocation])
}

guard let image = context.makeImage(),
      let destination = CGImageDestinationCreateWithURL(
        URL(fileURLWithPath: outputPath) as CFURL, "public.png" as CFString, 1, nil) else {
    fatalError("could not write \(outputPath)")
}
CGImageDestinationAddImage(destination, image, nil)
guard CGImageDestinationFinalize(destination) else { fatalError("finalize failed") }
print("wrote \(outputPath)  \(width)x\(height)  variant=\(variant)")
