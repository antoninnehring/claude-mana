import AppKit

struct ExplosionPalette {
    let flash: NSColor
    let wave: NSColor
    let bloomInner: NSColor
    let bloomMid: NSColor
    let bloomOuter: NSColor
    let coreHot: NSColor
    let coreMid: NSColor
    let coreOuter: NSColor
    let sparkHot: NSColor
    let spark: NSColor
    let columnTop: NSColor
    let columnBot: NSColor

    static let blue = ExplosionPalette(
        flash: NSColor(red: 0.35, green: 0.7, blue: 1.0, alpha: 1),
        wave: NSColor(red: 0.45, green: 0.8, blue: 1.0, alpha: 1),
        bloomInner: NSColor(red: 0.7, green: 0.9, blue: 1.0, alpha: 1),
        bloomMid: NSColor(red: 0.15, green: 0.4, blue: 1.0, alpha: 1),
        bloomOuter: NSColor(red: 0.05, green: 0.15, blue: 0.8, alpha: 1),
        coreHot: NSColor(red: 0.4, green: 0.75, blue: 1.0, alpha: 1),
        coreMid: NSColor(red: 0.05, green: 0.2, blue: 0.9, alpha: 1),
        coreOuter: NSColor(red: 0, green: 0, blue: 0.5, alpha: 1),
        sparkHot: NSColor(red: 0.85, green: 0.95, blue: 1.0, alpha: 1),
        spark: NSColor(red: 0.2, green: 0.55, blue: 1.0, alpha: 1),
        columnTop: NSColor(red: 0.6, green: 0.85, blue: 1.0, alpha: 1),
        columnBot: NSColor(red: 0.2, green: 0.45, blue: 1.0, alpha: 1)
    )

    static let red = ExplosionPalette(
        flash: NSColor(red: 1.0, green: 0.28, blue: 0.14, alpha: 1),
        wave: NSColor(red: 1.0, green: 0.45, blue: 0.28, alpha: 1),
        bloomInner: NSColor(red: 1.0, green: 0.72, blue: 0.45, alpha: 1),
        bloomMid: NSColor(red: 1.0, green: 0.22, blue: 0.10, alpha: 1),
        bloomOuter: NSColor(red: 0.7, green: 0.05, blue: 0.02, alpha: 1),
        coreHot: NSColor(red: 1.0, green: 0.48, blue: 0.22, alpha: 1),
        coreMid: NSColor(red: 0.85, green: 0.10, blue: 0.06, alpha: 1),
        coreOuter: NSColor(red: 0.45, green: 0.02, blue: 0.01, alpha: 1),
        sparkHot: NSColor(red: 1.0, green: 0.85, blue: 0.65, alpha: 1),
        spark: NSColor(red: 1.0, green: 0.28, blue: 0.12, alpha: 1),
        columnTop: NSColor(red: 1.0, green: 0.50, blue: 0.32, alpha: 1),
        columnBot: NSColor(red: 0.75, green: 0.12, blue: 0.06, alpha: 1)
    )

    static func forTint(_ tint: OrbTint) -> ExplosionPalette {
        tint == .red ? .red : .blue
    }
}

/// Full-screen mana detonation centered on the menu-bar MiniOrb.
final class StatusExplosion {
    static let shared = StatusExplosion()

    private var overlayWindows: [NSWindow] = []
    private var cleanupWork: DispatchWorkItem?

    func play(from button: NSStatusBarButton, tint: OrbTint = .blue) {
        cleanupWork?.cancel()
        tearDown()

        guard let buttonWindow = button.window else { return }
        let iconRect = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        let origin = CGPoint(x: iconRect.midX, y: iconRect.midY)
        let screen = NSScreen.screens.first { $0.frame.contains(origin) }
            ?? buttonWindow.screen
            ?? NSScreen.main
            ?? NSScreen.screens.first
        guard let screen else { return }

        let local = CGPoint(
            x: origin.x - screen.frame.minX,
            y: origin.y - screen.frame.minY
        )
        let startedAt = Date()
        let content = ExplosionCanvas(
            origin: local,
            startedAt: startedAt,
            palette: ExplosionPalette.forTint(tint),
            frame: NSRect(origin: .zero, size: screen.frame.size)
        )

        let win = NSPanel(
            contentRect: NSRect(origin: .zero, size: screen.frame.size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        win.isReleasedWhenClosed = false
        win.isOpaque = false
        win.backgroundColor = .clear
        win.hasShadow = false
        win.ignoresMouseEvents = true
        win.hidesOnDeactivate = false
        win.isFloatingPanel = true
        win.worksWhenModal = true
        win.level = .popUpMenu
        win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle, .stationary]
        win.animationBehavior = .none
        win.contentView = content
        win.setFrame(screen.frame, display: true)
        win.orderFrontRegardless()
        overlayWindows.append(win)

        let work = DispatchWorkItem { [weak self] in
            self?.tearDown()
        }
        cleanupWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5, execute: work)
    }

    private func tearDown() {
        overlayWindows.forEach { $0.orderOut(nil) }
        overlayWindows.removeAll()
    }
}

final class ExplosionCanvas: NSView {
    private let origin: CGPoint
    private let startedAt: Date
    private let palette: ExplosionPalette
    private var timer: Timer?

    init(origin: CGPoint, startedAt: Date, palette: ExplosionPalette, frame: NSRect) {
        self.origin = origin
        self.startedAt = startedAt
        self.palette = palette
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.needsDisplay = true
        }
        if let timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    deinit { timer?.invalidate() }

    override var isOpaque: Bool { false }
    override var wantsDefaultClipping: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        let t = Date().timeIntervalSince(startedAt)
        guard t < 2.6, let ctx = NSGraphicsContext.current?.cgContext else { return }
        let fade: CGFloat = t > 1.6 ? max(0, CGFloat(1 - (t - 1.6) / 0.9)) : 1
        guard fade > 0.01 else { return }

        ctx.setShouldAntialias(true)

        if t < 0.28 {
            let a = (1 - t / 0.28) * 0.55
            ctx.setFillColor(palette.flash.withAlphaComponent(a * Double(fade)).cgColor)
            ctx.fill(bounds)
        }

        let waves: [(Double, CGFloat, CGFloat)] = [
            (0.0, 1400, 26),
            (0.08, 1080, 18),
            (0.16, 820, 11),
        ]
        for (i, wave) in waves.enumerated() {
            let local = t - wave.0
            guard local > 0 else { continue }
            let r = CGFloat(local) * wave.1
            let a = max(0, 1 - CGFloat(local) / 0.85) * fade * (i == 0 ? 0.95 : 0.55)
            guard a > 0.02, r > 4 else { continue }
            ctx.setStrokeColor(palette.wave.withAlphaComponent(Double(a)).cgColor)
            ctx.setLineWidth(wave.2 * a + 2)
            ctx.strokeEllipse(in: CGRect(x: origin.x - r, y: origin.y - r, width: r * 2, height: r * 2))
        }

        let bloomR = CGFloat(120 + min(t, 0.4) * 1400)
        let bloomA = max(0, 1 - CGFloat(t) / 1.2) * 0.8 * fade
        if bloomA > 0.02 {
            let colors = [
                palette.bloomInner.withAlphaComponent(Double(bloomA)).cgColor,
                palette.bloomMid.withAlphaComponent(Double(bloomA * 0.45)).cgColor,
                palette.bloomOuter.withAlphaComponent(0).cgColor,
            ] as CFArray
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 0.4, 1]) {
                ctx.drawRadialGradient(
                    gradient,
                    startCenter: origin, startRadius: 0,
                    endCenter: origin, endRadius: bloomR,
                    options: [.drawsAfterEndLocation]
                )
            }
        }

        let coreGrow = t < 0.32 ? t / 0.32 : max(0, 1 - (t - 0.32) / 0.95)
        let coreR = CGFloat(36 + coreGrow * 380)
        if coreR > 4 {
            let colors = [
                NSColor(white: 1, alpha: 0.95 * Double(fade)).cgColor,
                palette.coreHot.withAlphaComponent(0.9 * Double(fade)).cgColor,
                palette.coreMid.withAlphaComponent(0.3 * Double(fade)).cgColor,
                palette.coreOuter.withAlphaComponent(0).cgColor,
            ] as CFArray
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 0.25, 0.65, 1]) {
                ctx.drawRadialGradient(
                    gradient,
                    startCenter: origin, startRadius: 0,
                    endCenter: origin, endRadius: coreR,
                    options: []
                )
            }
        }

        // Sparks fly outward and down from the menu-bar icon (AppKit y grows up).
        for i in 0..<180 {
            let seed = Double(i)
            let delay = (seed.truncatingRemainder(dividingBy: 11)) * 0.012
            let local = t - delay
            guard local > 0 else { continue }
            let longevity = 0.65 + (seed.truncatingRemainder(dividingBy: 5)) * 0.18
            let life = local / longevity
            guard life < 1 else { continue }

            let angle = seed * 2.399963 + 0.4
            let dirX = cos(angle)
            let dirY = -abs(sin(angle)) * 0.75 - 0.35
            let speed = 360 + (seed.truncatingRemainder(dividingBy: 1.7)) * 820
            let dist = speed * local
            let gravity = 210 * local * local
            let x = origin.x + CGFloat(dirX * dist)
            let y = origin.y + CGFloat(dirY * dist - gravity)
            let alpha = (1 - life) * Double(fade)
            let sz = CGFloat(2.0 + Double(i % 8) * 1.1) * CGFloat(1 - life * 0.4)
            let hot = i % 4 == 0
            let color = hot
                ? palette.sparkHot.withAlphaComponent(alpha)
                : palette.spark.withAlphaComponent(alpha * 0.9)
            color.setFill()
            NSBezierPath(ovalIn: CGRect(x: x - sz / 2, y: y - sz / 2, width: sz, height: sz * (1.6 + CGFloat(life)))).fill()
        }

        if t < 1.1 {
            let colA = (1 - t / 1.1) * 0.6 * Double(fade)
            let colH = CGFloat(t * 1200)
            let colW = CGFloat(44 + t * 56)
            let colors = [
                palette.columnTop.withAlphaComponent(colA).cgColor,
                palette.columnBot.withAlphaComponent(colA * 0.1).cgColor,
            ] as CFArray
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
                ctx.saveGState()
                let rect = CGRect(x: origin.x - colW / 2, y: origin.y - colH, width: colW, height: colH)
                ctx.addPath(CGPath(roundedRect: rect, cornerWidth: colW / 2, cornerHeight: colW / 2, transform: nil))
                ctx.clip()
                ctx.drawLinearGradient(
                    gradient,
                    start: origin,
                    end: CGPoint(x: origin.x, y: origin.y - colH),
                    options: []
                )
                ctx.restoreGState()
            }
        }
    }
}
