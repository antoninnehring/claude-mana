import AppKit
import SwiftUI

/// Borderless glass panel that hugs the menu-bar icon (no NSPopover arrow gap).
final class StatusPanelController {
    private let usageService: UsageService
    private var panel: NSPanel?
    private var hosting: NSHostingController<AnyView>?
    private var localMonitor: Any?
    private var globalMonitor: Any?
    private weak var statusButton: NSStatusBarButton?

    init(usageService: UsageService) {
        self.usageService = usageService
    }

    var isShown: Bool { panel?.isVisible == true }

    func toggle(from button: NSStatusBarButton) {
        if isShown {
            close()
        } else {
            show(from: button)
        }
    }

    func show(from button: NSStatusBarButton) {
        close()
        statusButton = button

        let root = AnyView(
            PopoverView(usageService: usageService)
                .preferredColorScheme(.dark)
        )
        let hosting = NSHostingController(rootView: root)
        hosting.sizingOptions = [.preferredContentSize, .intrinsicContentSize]
        hosting.view.wantsLayer = true
        hosting.view.layer?.backgroundColor = NSColor.clear.cgColor
        self.hosting = hosting

        var size = hosting.sizeThatFits(in: NSSize(width: 280, height: 600))
        if size.width < 80 || size.height < 80 {
            size = NSSize(width: 268, height: 210)
        }

        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        panel.isMovable = false
        panel.hidesOnDeactivate = false
        panel.animationBehavior = .utilityWindow
        panel.becomesKeyOnlyIfNeeded = true

        panel.contentView = Self.makeGlass(wrapping: hosting.view, size: size)
        self.panel = panel

        position(panel, under: button, size: size)
        button.highlight(true)
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        panel.invalidateShadow()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.12
            panel.animator().alphaValue = 1
        }
        NSApp.activate(ignoringOtherApps: true)
        installMonitors()
    }

    func close() {
        statusButton?.highlight(false)
        removeMonitors()
        panel?.orderOut(nil)
        panel = nil
        hosting = nil
    }

    private static func makeGlass(wrapping view: NSView, size: NSSize) -> NSView {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.clear.cgColor

        if #available(macOS 26.0, *) {
            view.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                view.widthAnchor.constraint(equalToConstant: size.width),
                view.heightAnchor.constraint(equalToConstant: size.height),
            ])
            let glass = NSGlassEffectView(frame: NSRect(origin: .zero, size: size))
            glass.cornerRadius = 16
            glass.style = .regular
            glass.tintColor = NSColor(calibratedRed: 0.10, green: 0.08, blue: 0.22, alpha: 0.28)
            glass.contentView = view
            return glass
        }

        let effect = NSVisualEffectView(frame: NSRect(origin: .zero, size: size))
        effect.material = .hudWindow
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.wantsLayer = true
        effect.layer?.cornerRadius = 16
        effect.layer?.masksToBounds = true
        view.frame = effect.bounds
        view.autoresizingMask = [.width, .height]
        effect.addSubview(view)
        return effect
    }

    private func position(_ panel: NSPanel, under button: NSStatusBarButton, size: NSSize) {
        guard let buttonWindow = button.window else { return }
        let buttonRect = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        let gap: CGFloat = 2
        var x = buttonRect.midX - size.width / 2
        var y = buttonRect.minY - size.height - gap
        if let screen = buttonWindow.screen ?? NSScreen.main {
            let vis = screen.visibleFrame
            x = max(vis.minX + 8, min(x, vis.maxX - size.width - 8))
            if y < vis.minY { y = vis.minY + 8 }
        }
        panel.setFrame(NSRect(x: x, y: y, width: size.width, height: size.height), display: true)
    }

    private func installMonitors() {
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self else { return event }
            if event.type == .keyDown && event.keyCode == 53 {
                self.close()
                return nil
            }
            if event.type == .leftMouseDown || event.type == .rightMouseDown {
                if self.clickIsOnStatusButton(event) { return event }
                if event.window !== self.panel {
                    self.close()
                }
            }
            return event
        }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self else { return }
            if self.clickIsOnStatusButton(event) { return }
            self.close()
        }
    }

    private func removeMonitors() {
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }
    }

    private func clickIsOnStatusButton(_ event: NSEvent) -> Bool {
        guard let button = statusButton, let win = button.window else { return false }
        let buttonScreen = win.convertToScreen(button.convert(button.bounds, to: nil))
        let point: NSPoint
        if event.window == nil {
            point = event.locationInWindow
        } else if let ew = event.window {
            point = ew.convertToScreen(NSRect(origin: event.locationInWindow, size: .zero)).origin
        } else {
            return false
        }
        return buttonScreen.insetBy(dx: -2, dy: -2).contains(point)
    }
}
