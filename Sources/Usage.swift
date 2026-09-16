import Foundation
import Combine

class UsageService: ObservableObject {
    // Session (blue orb) — 5-hour window
    @Published var sessionUtilization: Double = 0  // 0-100
    @Published var sessionResetsAt: Date?

    // Weekly (red orb) — 7-day window
    @Published var weeklyUtilization: Double = 0   // 0-100
    @Published var weeklyResetsAt: Date?

    // Sonnet-specific weekly
    @Published var sonnetUtilization: Double?
    @Published var sonnetResetsAt: Date?

    @Published var lastUpdated: Date?
    @Published var nextRefresh: Date?
    @Published var error: String?

    var onResetBurst: ((OrbTint) -> Void)?

    private var timer: Timer?
    private var resetWatchTimer: Timer?
    private var lastSessionResetAt: Date?
    private var lastWeeklyResetAt: Date?
    private var lastBurstAt: Date?

    // Mana = remaining (inverted utilization)
    var sessionManaLevel: Double {
        max(0, min(1, 1.0 - sessionUtilization / 100.0))
    }

    var weeklyManaLevel: Double {
        max(0, min(1, 1.0 - weeklyUtilization / 100.0))
    }

    init() {}

    func startPolling() {
        fetchUsage()
        nextRefresh = Date().addingTimeInterval(60)

        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.fetchUsage()
            self?.nextRefresh = Date().addingTimeInterval(60)
        }
        if let timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    private func fireResetBurst(_ tint: OrbTint) {
        if let lastBurstAt, Date().timeIntervalSince(lastBurstAt) < 20 { return }
        lastBurstAt = Date()
        onResetBurst?(tint)
    }

    private func scheduleResetWatch() {
        resetWatchTimer?.invalidate()
        let upcoming = [sessionResetsAt, weeklyResetsAt]
            .compactMap { $0 }
            .filter { $0.timeIntervalSinceNow > 0.05 }
        guard let next = upcoming.min() else { return }
        let timer = Timer(timeInterval: next.timeIntervalSinceNow, repeats: false) { [weak self] _ in
            guard let self else { return }
            let weeklyDue = self.weeklyResetsAt.map { $0.timeIntervalSinceNow <= 1.5 } ?? false
            self.fireResetBurst(weeklyDue ? .red : .blue)
            self.scheduleResetWatch()
        }
        resetWatchTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func jumped(_ newDate: Date?, previous: Date?) -> Bool {
        guard let previous, let newDate else { return false }
        return newDate > previous.addingTimeInterval(30)
    }

    private func getOAuthToken() -> String? {
        // Read from macOS keychain (same token Claude Code uses)
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        proc.arguments = ["find-generic-password", "-s", "Claude Code-credentials", "-w"]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = Pipe()

        do {
            try proc.run()
            proc.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let jsonStr = String(data: data, encoding: .utf8),
                  let jsonData = jsonStr.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                  let oauth = json["claudeAiOauth"] as? [String: Any],
                  let token = oauth["accessToken"] as? String else {
                return nil
            }
            return token
        } catch {
            return nil
        }
    }

    private func fetchUsage() {
        guard let token = getOAuthToken() else {
            DispatchQueue.main.async {
                self.error = "Not signed in"
            }
            return
        }

        guard let url = URL(string: "https://api.anthropic.com/api/oauth/usage") else { return }

        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")

        URLSession.shared.dataTask(with: req) { [weak self] data, response, err in
            DispatchQueue.main.async {
                guard let self else { return }

                if let err {
                    self.error = Self.networkMessage(err)
                    return
                }

                let httpCode = (response as? HTTPURLResponse)?.statusCode ?? 0

                guard let data else {
                    self.error = "No response from Claude"
                    return
                }

                if httpCode != 200 {
                    self.error = Self.httpMessage(httpCode)
                    return
                }

                guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    self.error = "Couldn't read usage"
                    return
                }

                // Session (five_hour)
                if let session = json["five_hour"] as? [String: Any] {
                    self.sessionUtilization = session["utilization"] as? Double ?? 0
                    if let resetStr = session["resets_at"] as? String {
                        self.sessionResetsAt = Self.parseISO(resetStr)
                    }
                }

                // Weekly (seven_day)
                if let weekly = json["seven_day"] as? [String: Any] {
                    self.weeklyUtilization = weekly["utilization"] as? Double ?? 0
                    if let resetStr = weekly["resets_at"] as? String {
                        self.weeklyResetsAt = Self.parseISO(resetStr)
                    }
                }

                // Sonnet weekly
                if let sonnet = json["seven_day_sonnet"] as? [String: Any] {
                    self.sonnetUtilization = sonnet["utilization"] as? Double
                    if let resetStr = sonnet["resets_at"] as? String {
                        self.sonnetResetsAt = Self.parseISO(resetStr)
                    }
                }

                let sessionJumped = self.jumped(self.sessionResetsAt, previous: self.lastSessionResetAt)
                let weeklyJumped = self.jumped(self.weeklyResetsAt, previous: self.lastWeeklyResetAt)
                self.lastSessionResetAt = self.sessionResetsAt
                self.lastWeeklyResetAt = self.weeklyResetsAt
                if weeklyJumped {
                    self.fireResetBurst(.red)
                } else if sessionJumped {
                    self.fireResetBurst(.blue)
                }
                self.scheduleResetWatch()

                self.lastUpdated = Date()
                self.error = nil
            }
        }.resume()
    }

    private static func parseISO(_ string: String) -> Date? {
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = withFraction.date(from: string) { return date }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: string)
    }

    private static func httpMessage(_ code: Int) -> String {
        switch code {
        case 401, 403: return "Sign-in expired"
        case 404: return "Usage unavailable"
        case 429: return "Too many requests"
        case 500...599: return "Claude is unavailable"
        default: return "Couldn't load usage"
        }
    }

    private static func networkMessage(_ error: Error) -> String {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                return "No internet connection"
            case .timedOut:
                return "Request timed out"
            default:
                break
            }
        }
        return "Couldn't reach Claude"
    }
}
