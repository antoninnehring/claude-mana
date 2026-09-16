import SwiftUI

enum OrbTint { case blue, red }

struct ManaOrbView: View {
    let level: Double
    var size: CGFloat = 160
    var tint: OrbTint = .blue

    // Color helpers based on tint
    private var liquidTop: Color {
        tint == .blue
            ? Color(red: 0.18, green: 0.50, blue: 1.0, opacity: 0.95)
            : Color(red: 1.0, green: 0.35, blue: 0.18, opacity: 0.95)
    }
    private var liquidMid: Color {
        tint == .blue
            ? Color(red: 0.10, green: 0.35, blue: 0.88, opacity: 0.97)
            : Color(red: 0.85, green: 0.18, blue: 0.10, opacity: 0.97)
    }
    private var liquidBot: Color {
        tint == .blue
            ? Color(red: 0.04, green: 0.15, blue: 0.55)
            : Color(red: 0.45, green: 0.06, blue: 0.04)
    }
    private var shimmerColor: Color {
        tint == .blue
            ? Color(red: 0.45, green: 0.70, blue: 1.0, opacity: 0.5)
            : Color(red: 1.0, green: 0.55, blue: 0.40, opacity: 0.5)
    }
    private var glowBandColor: Color {
        tint == .blue
            ? Color(red: 0.2, green: 0.50, blue: 1.0, opacity: 0.3)
            : Color(red: 1.0, green: 0.30, blue: 0.15, opacity: 0.3)
    }
    private var bubbleColor: Color {
        tint == .blue
            ? Color(red: 0.45, green: 0.70, blue: 1.0)
            : Color(red: 1.0, green: 0.55, blue: 0.40)
    }
    private var bgInner: Color {
        tint == .blue
            ? Color(red: 0.04, green: 0.02, blue: 0.14)
            : Color(red: 0.14, green: 0.02, blue: 0.02)
    }
    private var bgOuter: Color {
        tint == .blue
            ? Color(red: 0.01, green: 0.005, blue: 0.05)
            : Color(red: 0.05, green: 0.005, blue: 0.005)
    }

    var body: some View {
        let lv = max(0, min(1, level))
        let lcTop = liquidTop, lcMid = liquidMid, lcBot = liquidBot
        let scColor = shimmerColor
        let gbColor = glowBandColor, bbColor = bubbleColor
        let bgI = bgInner, bgO = bgOuter
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { ctx, sz in
                let cx = sz.width / 2
                let cy = sz.height / 2
                let center = CGPoint(x: cx, y: cy)
                let r = min(sz.width, sz.height) / 2 - 4
                let innerRect = CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)

                // ── INTERIOR (clipped to the glass sphere) ──
                ctx.drawLayer { gc in
                    gc.clip(to: Circle().path(in: innerRect))

                    // dark background
                    gc.fill(
                        Path(ellipseIn: innerRect),
                        with: .radialGradient(
                            Gradient(colors: [bgI, bgO]),
                            center: center,
                            startRadius: 0,
                            endRadius: r
                        )
                    )

                    guard lv > 0 else { return }

                    let liquidTopBase = innerRect.maxY - innerRect.height * lv

                    // ── LIQUID — gentle, long wavelength ──
                    let a1: CGFloat = 0.9
                    let a2: CGFloat = 0.4
                    let f1: CGFloat = .pi * 1.1
                    let f2: CGFloat = .pi * 1.8
                    let s1 = t * 0.7
                    let s2 = t * 1.05
                    let steps = 80

                    func waveY(at frac: CGFloat) -> CGFloat {
                        liquidTopBase
                            + a1 * sin(frac * f1 + s1)
                            + a2 * sin(frac * f2 + s2)
                    }

                    var liquidPath = Path()
                    liquidPath.move(to: CGPoint(x: innerRect.minX, y: innerRect.maxY + 2))
                    for i in 0...steps {
                        let frac = CGFloat(i) / CGFloat(steps)
                        let x = innerRect.minX + frac * innerRect.width
                        liquidPath.addLine(to: CGPoint(x: x, y: waveY(at: frac)))
                    }
                    liquidPath.addLine(to: CGPoint(x: innerRect.maxX, y: innerRect.maxY + 2))
                    liquidPath.closeSubpath()

                    gc.fill(
                        liquidPath,
                        with: .linearGradient(
                            Gradient(stops: [
                                .init(color: lcTop, location: 0),
                                .init(color: lcMid, location: 0.4),
                                .init(color: lcBot, location: 1),
                            ]),
                            startPoint: CGPoint(x: cx, y: liquidTopBase),
                            endPoint: CGPoint(x: cx, y: innerRect.maxY)
                        )
                    )

                    // surface shimmer
                    var shimmer = Path()
                    for i in 0...steps {
                        let frac = CGFloat(i) / CGFloat(steps)
                        let x = innerRect.minX + frac * innerRect.width
                        let pt = CGPoint(x: x, y: waveY(at: frac))
                        if i == 0 { shimmer.move(to: pt) }
                        else { shimmer.addLine(to: pt) }
                    }
                    gc.stroke(
                        shimmer,
                        with: .color(scColor),
                        lineWidth: 1.5
                    )

                    // liquid internal glow
                    gc.drawLayer { gc2 in
                        gc2.addFilter(.blur(radius: 14))
                        var band = Path()
                        band.addRect(CGRect(
                            x: innerRect.minX,
                            y: liquidTopBase - 8,
                            width: innerRect.width,
                            height: 16
                        ))
                        gc2.fill(band, with: .color(gbColor))
                    }

                    // ── BUBBLES ──
                    let liquidH = Double(innerRect.height) * lv
                    for i in 0..<6 {
                        let seed = Double(i) * 137.508
                        let bx = innerRect.minX + innerRect.width * CGFloat(
                            0.15 + 0.7 * ((sin(seed) + 1) / 2)
                        )
                        let speed = 6.0 + seed.truncatingRemainder(dividingBy: 6)
                        let cycle = (t * speed + seed * 7)
                            .truncatingRemainder(dividingBy: max(1, liquidH))
                        let by = innerRect.maxY - CGFloat(cycle)
                        let bSz: CGFloat = CGFloat(1.2 + Double(i % 3) * 1.0)

                        if by > liquidTopBase + 6 && by < innerRect.maxY - 3 {
                            let br = CGRect(x: bx - bSz / 2, y: by - bSz / 2,
                                            width: bSz, height: bSz)
                            gc.fill(
                                Circle().path(in: br),
                                with: .color(bbColor.opacity(0.2 + 0.15 * sin(t * 2 + seed)))
                            )
                        }
                    }

                    // ── GLASS HIGHLIGHT ──
                    var hlArc = Path()
                    hlArc.addArc(
                        center: center,
                        radius: r * 0.8,
                        startAngle: .degrees(210),
                        endAngle: .degrees(310),
                        clockwise: false
                    )
                    gc.stroke(
                        hlArc,
                        with: .color(.white.opacity(0.1)),
                        lineWidth: 2.5
                    )

                    let spotX = cx - r * 0.33
                    let spotY = cy - r * 0.4
                    gc.fill(
                        Circle().path(in: CGRect(x: spotX - 3.5, y: spotY - 3.5,
                                                 width: 7, height: 7)),
                        with: .color(.white.opacity(0.13))
                    )
                }

                // Faint glass rim — light, not a dark contour
                ctx.stroke(
                    Circle().path(in: innerRect.insetBy(dx: 0.4, dy: 0.4)),
                    with: .color(.white.opacity(0.16)),
                    lineWidth: 0.7
                )
            }
        }
        .frame(width: size, height: size)
    }
}
