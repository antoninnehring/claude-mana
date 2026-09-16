import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var dropdown: StatusPanelController!
    private let usageService = UsageService()
    private var iconTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: 26)
        if let button = statusItem.button {
            button.action = #selector(togglePopover)
            button.target = self
        }

        dropdown = StatusPanelController(usageService: usageService)
        usageService.onResetBurst = { [weak self] in
            guard let button = self?.statusItem.button else { return }
            StatusExplosion.shared.play(from: button)
        }

        updateIcon()
        iconTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 12.0, repeats: true) { [weak self] _ in
            self?.updateIcon()
        }

        usageService.startPolling()

        if CommandLine.arguments.contains("--explode") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
                guard let button = self?.statusItem.button else { return }
                StatusExplosion.shared.play(from: button)
            }
        }
    }

    private func updateIcon() {
        let t = Date().timeIntervalSinceReferenceDate
        statusItem.button?.image = MiniOrb.render(
            level: usageService.sessionManaLevel, size: 18, time: t
        )
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        dropdown.toggle(from: button)
    }
}

// ── Tiny animated orb for the menu bar ──
enum MiniOrb {
    static func render(level: Double, size: CGFloat, time: Double = 0) -> NSImage {
        let lv = max(0, min(1, level))
        let pad: CGFloat = 3
        let totalSize = size + pad * 2
        let img = NSImage(size: NSSize(width: totalSize, height: totalSize))
        img.lockFocus()

        let rect = NSRect(x: pad + 1, y: pad + 1,
                          width: size - 2, height: size - 2)
        let clipOval = NSBezierPath(ovalIn: rect)

        // Everything clipped to the circle — no strokes, no borders
        NSGraphicsContext.current?.saveGraphicsState()
        clipOval.addClip()

        // Dark interior — strong contrast
        NSColor(red: 0.01, green: 0.005, blue: 0.06, alpha: 0.92).setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: NSSize(width: totalSize, height: totalSize))).fill()

        // Liquid with gradient (brighter at top, darker at bottom)
        if lv > 0 {
            let baseFillH = rect.height * CGFloat(lv)
            let steps = 20
            let wavePath = NSBezierPath()
            wavePath.move(to: NSPoint(x: rect.minX, y: rect.minY))

            for i in 0...steps {
                let frac = CGFloat(i) / CGFloat(steps)
                let x = rect.minX + frac * rect.width
                let wave = 0.8 * sin(frac * .pi * 1.2 + time * 0.8)
                         + 0.4 * sin(frac * .pi * 2.0 + time * 1.2)
                let y = rect.minY + baseFillH + wave
                wavePath.line(to: NSPoint(x: x, y: y))
            }
            wavePath.line(to: NSPoint(x: rect.maxX, y: rect.minY))
            wavePath.close()

            // Gradient fill: bright blue at surface → deep dark blue at bottom
            let liquidGrad = NSGradient(
                colorsAndLocations:
                    (NSColor(red: 0.18, green: 0.52, blue: 1.0, alpha: 0.95), 0.0),
                    (NSColor(red: 0.08, green: 0.30, blue: 0.85, alpha: 0.95), 0.4),
                    (NSColor(red: 0.03, green: 0.10, blue: 0.45, alpha: 0.95), 1.0)
            )
            liquidGrad?.draw(in: wavePath, angle: 90)

            // shimmer
            let shimmerPath = NSBezierPath()
            for i in 0...steps {
                let frac = CGFloat(i) / CGFloat(steps)
                let x = rect.minX + frac * rect.width
                let wave = 0.8 * sin(frac * .pi * 1.2 + time * 0.8)
                         + 0.4 * sin(frac * .pi * 2.0 + time * 1.2)
                let y = rect.minY + baseFillH + wave
                if i == 0 { shimmerPath.move(to: NSPoint(x: x, y: y)) }
                else { shimmerPath.line(to: NSPoint(x: x, y: y)) }
            }
            NSColor(red: 0.4, green: 0.7, blue: 1.0, alpha: 0.55).setStroke()
            shimmerPath.lineWidth = 0.8
            shimmerPath.stroke()
        }

        // 3D glass ball reflection
        // Large soft highlight on upper-left (main specular)
        let r = rect.width / 2
        let highlightCenter = NSPoint(x: rect.midX - r * 0.25, y: rect.midY + r * 0.3)
        let highlightGrad = NSGradient(
            colorsAndLocations:
                (NSColor(white: 1.0, alpha: 0.35), 0.0),
                (NSColor(white: 1.0, alpha: 0.10), 0.5),
                (NSColor(white: 1.0, alpha: 0.0), 1.0)
        )
        let highlightRect = NSRect(
            x: highlightCenter.x - r * 0.7,
            y: highlightCenter.y - r * 0.5,
            width: r * 1.4,
            height: r * 1.0
        )
        highlightGrad?.draw(in: NSBezierPath(ovalIn: highlightRect), relativeCenterPosition: NSPoint(x: 0, y: 0.2))

        // Small bright specular dot
        let dotCenter = NSPoint(x: rect.midX - r * 0.3, y: rect.midY + r * 0.35)
        let dotSize: CGFloat = r * 0.3
        let dotRect = NSRect(x: dotCenter.x - dotSize/2, y: dotCenter.y - dotSize/2,
                             width: dotSize, height: dotSize)
        let dotGrad = NSGradient(
            colorsAndLocations:
                (NSColor(white: 1.0, alpha: 0.5), 0.0),
                (NSColor(white: 1.0, alpha: 0.0), 1.0)
        )
        dotGrad?.draw(in: NSBezierPath(ovalIn: dotRect), relativeCenterPosition: .zero)

        // Bottom rim light (subtle reflection from below)
        let rimArc = NSBezierPath()
        rimArc.appendArc(
            withCenter: NSPoint(x: rect.midX, y: rect.midY),
            radius: r - 1.0,
            startAngle: 220, endAngle: 320
        )
        NSColor(white: 1.0, alpha: 0.06).setStroke()
        rimArc.lineWidth = 0.5
        rimArc.stroke()

        NSGraphicsContext.current?.restoreGraphicsState()

        img.unlockFocus()
        img.isTemplate = false
        return img
    }
}

// ── Entry Point ──
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
