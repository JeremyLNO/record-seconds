import SwiftUI

/// The Crazy Bee Labs honeycomb pattern used as the default look for a project's intro
/// and end cards: a cream field, a white hexagon lattice, scattered honey/amber tiles,
/// loose white swirls and a dusting of specks.
///
/// The layout is driven by a seeded generator, so the same seed always draws the exact
/// same pattern — a card rendered for the in-app preview and the one burned into the
/// exported movie must match, and `Math.random`-style jitter would break that.
struct HoneycombBackground: View {
    /// Same seed → same pattern. Intro and end cards use different seeds so they don't
    /// look like the identical image.
    let seed: UInt64

    // Palette sampled from the Crazy Bee Labs honeycomb artwork.
    private static let cream = Color(red: 0.988, green: 0.937, blue: 0.757)
    private static let tiles: [Color] = [
        Color(red: 0.969, green: 0.808, blue: 0.357),
        Color(red: 0.949, green: 0.757, blue: 0.247),
        Color(red: 0.929, green: 0.682, blue: 0.224),
        Color(red: 1.000, green: 0.984, blue: 0.910),
        Color(red: 0.976, green: 0.855, blue: 0.478),
    ]

    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Self.cream))

            var rng = SeededGenerator(seed: seed)
            // Hex radius scales with the card so the lattice reads the same at any export size.
            let radius = size.width / 9
            drawTiles(in: &context, size: size, radius: radius, rng: &rng)
            drawLattice(in: &context, size: size, radius: radius)
            drawSwirls(in: &context, size: size, rng: &rng)
            drawSpecks(in: &context, size: size, rng: &rng)
        }
        .background(Self.cream)
    }

    // MARK: - Lattice

    /// White outlines over the whole card, drawn on top of the tiles so every cell keeps
    /// a crisp border like the reference artwork.
    private func drawLattice(in context: inout GraphicsContext, size: CGSize, radius: CGFloat) {
        var path = Path()
        forEachCell(size: size, radius: radius) { center in
            path.addPath(Self.hexagon(center: center, radius: radius))
        }
        context.stroke(path, with: .color(.white), lineWidth: max(2, radius * 0.075))
    }

    // MARK: - Filled tiles

    private func drawTiles(in context: inout GraphicsContext, size: CGSize, radius: CGFloat, rng: inout SeededGenerator) {
        forEachCell(size: size, radius: radius) { center in
            // Roughly a third of the cells get a tint, the rest stay cream.
            guard rng.nextUnit() < 0.34 else { return }
            let color = Self.tiles[rng.nextInt(upperBound: Self.tiles.count)]
            let inset = radius * (0.90 + 0.08 * rng.nextUnit())
            context.fill(
                Self.hexagon(center: center, radius: inset),
                with: .color(color.opacity(0.55 + 0.45 * rng.nextUnit()))
            )
        }
        // A few small stray hexagons sitting between cells, as in the artwork.
        for _ in 0..<Int(size.width / 45) {
            let center = CGPoint(x: rng.nextUnit() * size.width, y: rng.nextUnit() * size.height)
            let r = radius * (0.12 + 0.18 * rng.nextUnit())
            let color = Self.tiles[rng.nextInt(upperBound: Self.tiles.count)]
            context.fill(Self.hexagon(center: center, radius: r), with: .color(color.opacity(0.7)))
            context.stroke(Self.hexagon(center: center, radius: r), with: .color(.white), lineWidth: max(1.5, r * 0.16))
        }
    }

    // MARK: - Swirls

    /// Loose looping ribbons. Each swirl is a chain of cubic segments whose control
    /// points wander, which gives the hand-drawn curl of the reference pattern.
    private func drawSwirls(in context: inout GraphicsContext, size: CGSize, rng: inout SeededGenerator) {
        let count = max(4, Int(size.width / 150))
        for _ in 0..<count {
            var path = Path()
            var point = CGPoint(x: rng.nextUnit() * size.width, y: rng.nextUnit() * size.height)
            path.move(to: point)
            let segments = 3 + rng.nextInt(upperBound: 3)
            let span = size.width * 0.22
            for _ in 0..<segments {
                let next = CGPoint(
                    x: point.x + (rng.nextUnit() - 0.5) * span * 2,
                    y: point.y + (rng.nextUnit() - 0.5) * span * 2
                )
                // Control points pushed well past the end point make the curve loop back
                // on itself instead of bowing gently.
                let c1 = CGPoint(x: point.x + (rng.nextUnit() - 0.5) * span * 3, y: point.y + (rng.nextUnit() - 0.5) * span * 3)
                let c2 = CGPoint(x: next.x + (rng.nextUnit() - 0.5) * span * 3, y: next.y + (rng.nextUnit() - 0.5) * span * 3)
                path.addCurve(to: next, control1: c1, control2: c2)
                point = next
            }
            context.stroke(
                path,
                with: .color(.white.opacity(0.85)),
                style: StrokeStyle(lineWidth: max(1.5, size.width / 340), lineCap: .round)
            )
        }
    }

    // MARK: - Specks

    private func drawSpecks(in context: inout GraphicsContext, size: CGSize, rng: inout SeededGenerator) {
        for _ in 0..<Int(size.width / 8) {
            let r = size.width / 400 * (0.5 + rng.nextUnit() * 1.6)
            let rect = CGRect(x: rng.nextUnit() * size.width, y: rng.nextUnit() * size.height, width: r * 2, height: r * 2)
            let amber = rng.nextUnit() < 0.25
            let color: Color = amber
                ? Color(red: 0.898, green: 0.643, blue: 0.106).opacity(0.8)
                : .white.opacity(0.9)
            context.fill(Path(ellipseIn: rect), with: .color(color))
        }
    }

    // MARK: - Geometry

    /// Visits the centre of every cell of a pointy-top hexagonal lattice covering `size`
    /// (plus one ring of overflow so the pattern bleeds off every edge).
    private func forEachCell(size: CGSize, radius: CGFloat, body: (CGPoint) -> Void) {
        let horizontal = radius * sqrt(3)
        let vertical = radius * 1.5
        let columns = Int(size.width / horizontal) + 2
        let rows = Int(size.height / vertical) + 2
        for row in -1..<rows {
            for column in -1..<columns {
                // Odd rows shift half a cell right — that offset is what interlocks the combs.
                let x = CGFloat(column) * horizontal + (row % 2 == 0 ? 0 : horizontal / 2)
                let y = CGFloat(row) * vertical
                body(CGPoint(x: x, y: y))
            }
        }
    }

    private static func hexagon(center: CGPoint, radius: CGFloat) -> Path {
        var path = Path()
        for corner in 0..<6 {
            // -90° start puts a vertex at the top (pointy-top orientation).
            let angle = CGFloat(corner) * .pi / 3 - .pi / 2
            let point = CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
            corner == 0 ? path.move(to: point) : path.addLine(to: point)
        }
        path.closeSubpath()
        return path
    }
}

/// Deterministic PRNG (SplitMix64) — the pattern must be reproducible across renders,
/// so `SystemRandomNumberGenerator` is not an option here.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        // Any non-zero state works; mixing in a constant avoids a degenerate seed of 0.
        state = seed &+ 0x9E3779B97F4A7C15
    }

    mutating func next() -> UInt64 {
        state = state &+ 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    /// Uniform value in 0..<1.
    mutating func nextUnit() -> CGFloat {
        CGFloat(next() >> 11) / CGFloat(UInt64(1) << 53)
    }

    mutating func nextInt(upperBound: Int) -> Int {
        Int(next() % UInt64(upperBound))
    }
}
