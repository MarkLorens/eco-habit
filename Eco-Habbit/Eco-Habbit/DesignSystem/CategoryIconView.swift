import SwiftUI

/// The icon set from the design project's `CategoryIcon` component, drawn as
/// SwiftUI paths in the same 24x24 viewBox the SVGs use.
enum IconGlyph: String, Codable, CaseIterable {
    case leaf, bag, bolt, droplet, bike, people
}

struct CategoryIconView: View {
    let glyph: IconGlyph
    var size: CGFloat = 24
    var color: Color = Theme.C.accent2

    var body: some View {
        Canvas { context, canvasSize in
            let s = min(canvasSize.width, canvasSize.height) / 24
            let t = CGAffineTransform(scaleX: s, y: s)
            let stroke = StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)

            switch glyph {
            case .leaf:
                context.fill(Self.leaf.applying(t), with: .color(color))

            case .bag:
                context.stroke(Self.bagHandle.applying(t), with: .color(color), style: stroke)
                context.fill(
                    Path(roundedRect: CGRect(x: 5, y: 8, width: 14, height: 12), cornerRadius: 2)
                        .applying(t),
                    with: .color(color)
                )

            case .bolt:
                context.fill(Self.bolt.applying(t), with: .color(color))

            case .droplet:
                context.fill(Self.droplet.applying(t), with: .color(color))

            case .bike:
                for center in [CGPoint(x: 6, y: 17), CGPoint(x: 18, y: 17)] {
                    let circle = Path(ellipseIn: CGRect(
                        x: center.x - 3.4, y: center.y - 3.4, width: 6.8, height: 6.8
                    ))
                    context.stroke(circle.applying(t), with: .color(color), style: stroke)
                }
                context.stroke(Self.bikeFrame.applying(t), with: .color(color), style: stroke)

            case .people:
                context.fill(
                    Path(ellipseIn: CGRect(x: 6.4, y: 5.4, width: 5.2, height: 5.2)).applying(t),
                    with: .color(color)
                )
                context.fill(Self.personBodyFront.applying(t), with: .color(color))
                context.fill(
                    Path(ellipseIn: CGRect(x: 14.3, y: 7.3, width: 4.4, height: 4.4)).applying(t),
                    with: .color(color.opacity(0.75))
                )
                context.fill(Self.personBodyBack.applying(t), with: .color(color.opacity(0.75)))
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    // MARK: - Path data (transcribed from the SVGs)

    private static let leaf: Path = {
        var p = Path()
        p.move(to: CGPoint(x: 20, y: 4))
        p.addCurve(to: CGPoint(x: 4, y: 20),
                   control1: CGPoint(x: 10, y: 4), control2: CGPoint(x: 4, y: 10))
        p.addCurve(to: CGPoint(x: 20, y: 4),
                   control1: CGPoint(x: 14, y: 20), control2: CGPoint(x: 20, y: 14))
        p.closeSubpath()
        return p
    }()

    private static let bagHandle: Path = {
        var p = Path()
        p.addArc(center: CGPoint(x: 12, y: 8), radius: 3,
                 startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
        return p
    }()

    private static let bolt: Path = {
        var p = Path()
        p.addLines([
            CGPoint(x: 13, y: 2), CGPoint(x: 4, y: 14), CGPoint(x: 10, y: 14),
            CGPoint(x: 9, y: 22), CGPoint(x: 18, y: 10), CGPoint(x: 12, y: 10),
        ])
        p.closeSubpath()
        return p
    }()

    private static let droplet: Path = {
        var p = Path()
        p.move(to: CGPoint(x: 12, y: 3))
        p.addCurve(to: CGPoint(x: 18, y: 13.5),
                   control1: CGPoint(x: 16, y: 8), control2: CGPoint(x: 18, y: 10.5))
        p.addArc(center: CGPoint(x: 12, y: 13.5), radius: 6,
                 startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
        p.addCurve(to: CGPoint(x: 12, y: 3),
                   control1: CGPoint(x: 6, y: 10.5), control2: CGPoint(x: 8, y: 8))
        p.closeSubpath()
        return p
    }()

    private static let bikeFrame: Path = {
        var p = Path()
        p.move(to: CGPoint(x: 6, y: 17))
        p.addLine(to: CGPoint(x: 10, y: 9))
        p.addLine(to: CGPoint(x: 14, y: 9))
        p.addLine(to: CGPoint(x: 17, y: 14))
        p.move(to: CGPoint(x: 10, y: 9))
        p.addLine(to: CGPoint(x: 13, y: 6))
        p.addLine(to: CGPoint(x: 16, y: 6))
        return p
    }()

    private static let personBodyFront: Path = {
        var p = Path()
        p.move(to: CGPoint(x: 3, y: 20))
        p.addCurve(to: CGPoint(x: 9, y: 14),
                   control1: CGPoint(x: 3, y: 16.4), control2: CGPoint(x: 5.7, y: 14))
        p.addCurve(to: CGPoint(x: 15, y: 20),
                   control1: CGPoint(x: 12.3, y: 14), control2: CGPoint(x: 15, y: 16.4))
        p.closeSubpath()
        return p
    }()

    private static let personBodyBack: Path = {
        var p = Path()
        p.move(to: CGPoint(x: 13.2, y: 20))
        p.addCurve(to: CGPoint(x: 18, y: 15),
                   control1: CGPoint(x: 13.4, y: 17.1), control2: CGPoint(x: 15.4, y: 15))
        p.addCurve(to: CGPoint(x: 23, y: 20),
                   control1: CGPoint(x: 20.6, y: 15), control2: CGPoint(x: 22.6, y: 17.1))
        p.closeSubpath()
        return p
    }()
}

#Preview {
    HStack(spacing: 16) {
        ForEach(IconGlyph.allCases, id: \.self) { g in
            CategoryIconView(glyph: g, size: 32, color: Theme.C.accent600)
        }
    }
    .padding()
    .background(Theme.C.bg)
}
