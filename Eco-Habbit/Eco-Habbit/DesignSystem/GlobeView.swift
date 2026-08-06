import SwiftUI
import Combine

/// The Earth. A direct port of the design project's `Globe` component: land blobs
/// scroll across a seamless strip inside a clipped circle, the ocean/land colors
/// lerp along a 3-stop ramp driven by `health`, and clouds appear above 70%.
///
/// `interactive` enables drag-to-spin; otherwise it just drifts on its own.
struct GlobeView: View {
    /// 0...100
    var health: Double
    var size: CGFloat = 210
    var interactive: Bool = true

    @State private var offset: CGFloat = 0
    @State private var dragging = false
    @State private var dragStartOffset: CGFloat = 0

    private let tick = Timer.publish(every: 0.04, on: .main, in: .common).autoconnect()

    private var stripWidth: CGFloat { size * 1.6 }

    /// Land shapes as fractions of the strip / globe, exactly as authored in the design.
    private static let baseBlobs: [(x: CGFloat, y: CGFloat, rx: CGFloat, ry: CGFloat)] = [
        (0.04, 0.26, 0.16, 0.11),
        (0.16, 0.58, 0.11, 0.085),
        (0.30, 0.12, 0.10, 0.15),
        (0.30, 0.62, 0.20, 0.11),
        (0.50, 0.30, 0.13, 0.17),
        (0.62, 0.60, 0.12, 0.10),
        (0.70, 0.18, 0.15, 0.12),
    ]

    private static let oceanStops: [Color] = [
        Color(hex: 0xC9A468), Color(hex: 0x6F9A7C), Color(hex: 0x3A8FAE),
    ]
    private static let landStops: [Color] = [
        Color(hex: 0x8A5A34), Color(hex: 0x7A8A5E), Color(hex: 0x4F7A45),
    ]

    private var ramp: (ocean: Color, oceanShade: Color, land: Color, landShade: Color) {
        let h = max(0, min(100, health))
        let t: Double, a: Int, b: Int
        if h <= 50 { t = h / 50; a = 0; b = 1 } else { t = (h - 50) / 50; a = 1; b = 2 }
        let ocean = Color.lerp(Self.oceanStops[a], Self.oceanStops[b], t)
        let land = Color.lerp(Self.landStops[a], Self.landStops[b], t)
        return (ocean, ocean.darkened(0.35), land, land.darkened(0.28))
    }

    private var normalizedOffset: CGFloat {
        var o = offset.truncatingRemainder(dividingBy: stripWidth)
        if o < 0 { o += stripWidth }
        return o
    }

    var body: some View {
        let colors = ramp

        ZStack(alignment: .topLeading) {
            // Ocean
            RadialGradient(
                colors: [colors.ocean, colors.oceanShade],
                center: UnitPoint(x: 0.35, y: 0.30),
                startRadius: 0,
                endRadius: size * 0.85
            )
            .frame(width: size, height: size)

            // Land — each blob drawn twice, one strip-width apart, so it wraps seamlessly.
            ForEach(Array(Self.baseBlobs.enumerated()), id: \.offset) { index, blob in
                ForEach([CGFloat(0), stripWidth], id: \.self) { dup in
                    Ellipse()
                        .fill(index.isMultiple(of: 2) ? colors.land : colors.landShade)
                        .opacity(0.92)
                        .frame(width: blob.rx * size * 2, height: blob.ry * size * 2)
                        .offset(
                            x: blob.x * stripWidth + dup - normalizedOffset,
                            y: blob.y * size
                        )
                }
            }

            // Clouds — only on a globe that is actually doing well.
            if health > 70 {
                Capsule()
                    .fill(.white.opacity(0.5))
                    .frame(width: size * 0.38, height: size * 0.13)
                    .blur(radius: 4)
                    .offset(x: size * 0.08, y: size * 0.14)
                Capsule()
                    .fill(.white.opacity(0.4))
                    .frame(width: size * 0.32, height: size * 0.11)
                    .blur(radius: 4)
                    .offset(x: size * 0.48, y: size * 0.58)
            }

            // Specular highlight + the inset terminator shadow.
            RadialGradient(
                colors: [.white.opacity(0.4), .clear],
                center: UnitPoint(x: 0.32, y: 0.28),
                startRadius: 0,
                endRadius: size * 0.42
            )
            .frame(width: size, height: size)

            RadialGradient(
                colors: [.clear, .black.opacity(0.45)],
                center: UnitPoint(x: 0.34, y: 0.32),
                startRadius: size * 0.30,
                endRadius: size * 0.68
            )
            .frame(width: size, height: size)
            .allowsHitTesting(false)
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .shadow(color: .black.opacity(0.28), radius: 15, x: 0, y: 18)
        .contentShape(Circle())
        .gesture(interactive ? dragGesture : nil)
        .onReceive(tick) { _ in
            guard !dragging else { return }
            offset += 0.35
        }
        .animation(.easeInOut(duration: 0.4), value: health)
        .accessibilityLabel("Earth globe, health \(Int(health)) percent")
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if !dragging {
                    dragging = true
                    dragStartOffset = offset
                }
                offset = dragStartOffset - value.translation.width
            }
            .onEnded { _ in dragging = false }
    }
}

// MARK: - Color math

extension Color {
    private var rgbComponents: (Double, Double, Double) {
        let ui = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Double(r), Double(g), Double(b))
    }

    static func lerp(_ a: Color, _ b: Color, _ t: Double) -> Color {
        let ca = a.rgbComponents, cb = b.rgbComponents
        let k = max(0, min(1, t))
        return Color(
            .sRGB,
            red: ca.0 + (cb.0 - ca.0) * k,
            green: ca.1 + (cb.1 - ca.1) * k,
            blue: ca.2 + (cb.2 - ca.2) * k,
            opacity: 1
        )
    }

    func darkened(_ amount: Double) -> Color {
        let c = rgbComponents
        let f = 1 - amount
        return Color(.sRGB, red: c.0 * f, green: c.1 * f, blue: c.2 * f, opacity: 1)
    }
}

#Preview {
    VStack(spacing: 24) {
        GlobeView(health: 12, size: 140, interactive: false)
        GlobeView(health: 55, size: 160)
        GlobeView(health: 92, size: 140, interactive: false)
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Theme.C.bg)
}
