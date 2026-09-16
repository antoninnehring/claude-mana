import AppKit
import SwiftUI

enum MedievalFont {
    static let family: String = {
        let available = Set(NSFontManager.shared.availableFontFamilies)
        for name in ["Luminari", "Trattatello", "Herculanum"] {
            if available.contains(name) { return name }
        }
        return "Georgia"
    }()
}

struct PopoverView: View {
    @ObservedObject var usageService: UsageService

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 18) {
                orbColumn(
                    level: usageService.sessionManaLevel,
                    tint: .blue,
                    title: "Session",
                    percent: usageService.sessionUtilization,
                    reset: usageService.sessionResetsAt,
                    accent: Color(red: 0.18, green: 0.38, blue: 0.82)
                )
                orbColumn(
                    level: usageService.weeklyManaLevel,
                    tint: .red,
                    title: "Weekly",
                    percent: usageService.weeklyUtilization,
                    reset: usageService.weeklyResetsAt,
                    accent: Color(red: 0.72, green: 0.18, blue: 0.14)
                )
            }

            if let err = usageService.error {
                Text(err)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color(red: 1.0, green: 0.62, blue: 0.38))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }

            ZStack {
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    Text(refreshText)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                HStack {
                    Spacer()
                    Button("Quit") { NSApp.terminate(nil) }
                        .buttonStyle(.plain)
                        .font(.custom(MedievalFont.family, size: 11))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 10)
        .frame(width: 268)
        .background(Color.clear)
    }

    private func orbColumn(
        level: Double,
        tint: OrbTint,
        title: String,
        percent: Double,
        reset: Date?,
        accent: Color
    ) -> some View {
        VStack(spacing: 4) {
            ManaOrbView(level: level, size: 100, tint: tint)
            Text(title)
                .font(.custom(MedievalFont.family, size: 17))
                .foregroundStyle(accent)
            Text("\(Int(percent))%")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary.opacity(0.9))
            if let reset {
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    Text(countdownText(to: reset))
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var refreshText: String {
        guard let next = usageService.nextRefresh else { return "" }
        let remaining = Int(next.timeIntervalSinceNow)
        if remaining <= 0 { return "Refreshing…" }
        return "Refresh in \(remaining)s"
    }

    private func countdownText(to date: Date) -> String {
        let secs = Int(date.timeIntervalSinceNow)
        if secs <= 0 { return "resetting" }
        let d = secs / 86_400
        let h = (secs % 86_400) / 3_600
        let m = (secs % 3_600) / 60
        if d > 0 { return "\(d)d \(h)h" }
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }
}
