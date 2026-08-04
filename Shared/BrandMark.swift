//
//  BrandMark.swift
//  BeerCHILLER
//
//  The app's word-mark glyph: half beer bottle, half frost crystal, split on a
//  shared vertical axis. Derived from the app icon (bottle + snowflake + amber).
//
//  Drawn as vector geometry rather than shipped as a bitmap so it stays crisp at
//  every size, scales with Dynamic Type, and takes its two colours from the
//  active palette (so it works in Classic and Beer, light and dark).
//
//  Proportions — variant "P2", bottle-led:
//    * the bottle is cut just past its centre line (x = 49 in design space)
//    * the crystal sits 3.5 units to the right of that cut, so the two halves
//      read as a pair instead of a collision
//    * the crystal is rotated 30° so no arm lies *on* the split axis — an arm on
//      the axis gets sliced lengthwise and looks like a rendering error
//    * crystal radius 33 against a bottle height of 82: the bottle leads, the
//      frost is the qualifier
//

import SwiftUI

// MARK: - Geometry

/// All coordinates live in a fixed design box, then get mapped onto whatever
/// rect the view is given. Keeping the numbers in one place makes the mark
/// reproducible and the proportions reviewable.
enum BrandMarkGeometry {

    /// Tight bounding box of the finished mark, in design units.
    static let designOrigin = CGPoint(x: 26.3, y: 9)
    static let designSize = CGSize(width: 47.4, height: 82)

    /// Stroke weight of the crystal, in design units.
    static let frostLineWidth: CGFloat = 6.2

    static var aspectRatio: CGFloat { designSize.width / designSize.height }

    /// Crystal centre, 3.5 units of air to the right of the bottle's cut edge.
    /// The whole composition is shifted 7.7 units left of the design centre so
    /// the combined mark is optically centred (a narrow bottle plus a round
    /// crystal is not balanced by splitting the box down the middle).
    private static let flakeCenter = CGPoint(x: 44.8, y: 50)

    // Crystal radius 28.9 (= 34 × 0.85) against a bottle height of 82: the
    // bottle clearly leads and the frost stays a qualifier.
    private static let crystalScale: CGFloat = 0.85
    private static let armLength: CGFloat = 34 * crystalScale
    private static let branchBase: CGFloat = 21 * crystalScale
    private static let branchSpread: CGFloat = 9.5 * crystalScale
    private static let branchTip: CGFloat = 30 * crystalScale

    /// Only the arms that fall in the right-hand half: 30°, 90°, 150° measured
    /// clockwise from straight up.
    private static let armAngles: [CGFloat] = [30, 90, 150]

    /// Left half of a beer bottle: crown cap, neck, shouldered body, radiused
    /// base. Cut at x = 50.5, just past the bottle's own centre line (x = 50),
    /// so the silhouette still reads as a bottle rather than a strip.
    static func bottlePath() -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 41.3, y: 9))
        path.addLine(to: CGPoint(x: 33.3, y: 9))        // cap, top edge
        path.addLine(to: CGPoint(x: 33.3, y: 17.5))     // cap, left edge
        path.addLine(to: CGPoint(x: 36.3, y: 17.5))     // cap → neck step
        path.addLine(to: CGPoint(x: 36.3, y: 36))       // neck
        path.addCurve(to: CGPoint(x: 26.3, y: 57.5),    // shoulder
                      control1: CGPoint(x: 36.3, y: 41.5),
                      control2: CGPoint(x: 26.3, y: 46.5))
        path.addLine(to: CGPoint(x: 26.3, y: 84))       // body, left edge
        path.addCurve(to: CGPoint(x: 33.3, y: 91),      // base radius (r = 7)
                      control1: CGPoint(x: 26.3, y: 87.866),
                      control2: CGPoint(x: 29.434, y: 91))
        path.addLine(to: CGPoint(x: 41.3, y: 91))       // base, along the cut
        path.closeSubpath()
        return path
    }

    /// Right half of a six-armed crystal: three arms, each with two branches.
    static func frostPath() -> Path {
        var path = Path()
        for angle in armAngles {
            let radians = angle * .pi / 180
            // y-down rotation: positive angles turn clockwise on screen, so 90°
            // maps "up" onto "right".
            func place(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
                CGPoint(x: flakeCenter.x + x * cos(radians) - y * sin(radians),
                        y: flakeCenter.y + x * sin(radians) + y * cos(radians))
            }
            path.move(to: place(0, 0))
            path.addLine(to: place(0, -armLength))
            path.move(to: place(0, -branchBase))
            path.addLine(to: place(-branchSpread, -branchTip))
            path.move(to: place(0, -branchBase))
            path.addLine(to: place(branchSpread, -branchTip))
        }
        return path
    }

    /// Everything from the split axis rightwards — the region the crystal is
    /// allowed to paint into.
    static func frostClipRect(in rect: CGRect) -> CGRect {
        let (mapping, _) = transform(for: rect)
        let axis = CGPoint(x: flakeCenter.x, y: 0).applying(mapping).x
        return CGRect(x: axis, y: rect.minY,
                      width: rect.maxX - axis, height: rect.height)
    }

    /// Maps design space onto `rect`, preserving the aspect ratio.
    static func transform(for rect: CGRect) -> (CGAffineTransform, CGFloat) {
        let scale = min(rect.width / designSize.width, rect.height / designSize.height)
        let drawnWidth = designSize.width * scale
        let drawnHeight = designSize.height * scale
        let offsetX = rect.minX + (rect.width - drawnWidth) / 2
        let offsetY = rect.minY + (rect.height - drawnHeight) / 2
        let transform = CGAffineTransform(translationX: offsetX, y: offsetY)
            .scaledBy(x: scale, y: scale)
            .translatedBy(x: -designOrigin.x, y: -designOrigin.y)
        return (transform, scale)
    }
}

// MARK: - View

/// The word-mark glyph. Give it a height; the width follows the aspect ratio.
struct BrandMark: View {
    var bottleColor: Color
    var frostColor: Color

    var body: some View {
        Canvas(opaque: false, rendersAsynchronously: false) { context, size in
            let rect = CGRect(origin: .zero, size: size)
            let (transform, scale) = BrandMarkGeometry.transform(for: rect)

            context.fill(BrandMarkGeometry.bottlePath().applying(transform),
                         with: .color(bottleColor))

            // The crystal is clipped at the split axis. Without the clip, each
            // arm's round line cap bulges half a stroke width (3.3 design units)
            // back past the centre point, which swallows the 3.5 units of air
            // meant to sit between the two halves — the mark then reads as one
            // crowded snowflake instead of two halves. Clipping also gives the
            // crystal the flat left edge the split needs.
            context.drawLayer { layer in
                layer.clip(to: Path(BrandMarkGeometry.frostClipRect(in: rect)))
                layer.stroke(BrandMarkGeometry.frostPath().applying(transform),
                             with: .color(frostColor),
                             style: StrokeStyle(
                                 lineWidth: BrandMarkGeometry.frostLineWidth * scale,
                                 lineCap: .round))
            }
        }
        .aspectRatio(BrandMarkGeometry.aspectRatio, contentMode: .fit)
        // The wordmark beside it carries the accessible name.
        .accessibilityHidden(true)
    }
}
