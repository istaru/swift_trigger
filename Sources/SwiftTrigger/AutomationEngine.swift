import Foundation

private let stLogURL: URL = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("Library/Logs/SwiftTrigger.log")

private func stLog(_ msg: String) {
    let ts = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
    let line = "[\(ts)] \(msg)\n"
    print(line, terminator: "")
    guard let data = line.data(using: .utf8) else { return }
    if let fh = try? FileHandle(forWritingTo: stLogURL) {
        defer { try? fh.close() }
        try? fh.seekToEnd()
        try? fh.write(contentsOf: data)
    } else {
        try? data.write(to: stLogURL)
    }
}

class AutomationEngine {
    static let shared = AutomationEngine()

    private let store = AutomationStore.shared
    private let notif = NotificationManager.shared

    // Battery dedup
    private var batteryLowFired: Set<UUID> = []
    private var chargerConnectedFired: Set<UUID> = []
    private var lastIsCharging: Bool? = nil
    private var lastBatteryPct: Int? = nil

    // Time dedup — <id>: "YYYY-MM-DD HH:mm"
    private var timeFiredKeys: [UUID: String] = [:]

    func start() {
        setupBattery()
        setupTime()
        setupWiFi()
        setupApp()

        BatteryMonitor.shared.start()
        TimeMonitor.shared.start()
        WiFiMonitor.shared.start()
        AppMonitor.shared.start()
    }

    // MARK: - Battery

    private func setupBattery() {
        BatteryMonitor.shared.onBatteryChanged = { [weak self] pct, isCharging in
            guard let self else { return }

            // 首次事件只用于建立基线，不算状态切换，避免启动时误触发插拔类规则
            let isFirstEvent = (self.lastIsCharging == nil)
            let stateChanged = !isFirstEvent && (self.lastIsCharging != isCharging)
            self.lastIsCharging = isCharging

            stLog("电池事件: \(pct)% isCharging=\(isCharging) stateChanged=\(stateChanged) firstEvent=\(isFirstEvent) lastPct=\(self.lastBatteryPct.map{"\($0)%"} ?? "nil")")

            if stateChanged {
                if isCharging {
                    self.batteryLowFired.removeAll()
                    stLog("充电器插入 → 清空 batteryLowFired")
                } else {
                    self.chargerConnectedFired.removeAll()
                    stLog("充电器拔出 → 清空 chargerConnectedFired")
                }
            }

            for a in self.store.automations where a.isEnabled {
                guard case .battery(let t) = a.trigger else { continue }
                switch t.condition {
                case .below:
                    stLog("  [\(a.name)] 条件=低于\(t.percentage)% 当前=\(pct)% 充电=\(isCharging)")
                    if !isCharging, pct < t.percentage, self.batteryLowFired.insert(a.id).inserted {
                        self.fire(a)
                    }
                case .reaches:
                    if let prev = self.lastBatteryPct, prev < t.percentage, pct >= t.percentage {
                        stLog("  [\(a.name)] 条件=达到\(t.percentage)% 跨越触发! \(prev)% → \(pct)%")
                        self.fire(a)
                    } else {
                        stLog("  [\(a.name)] 条件=达到\(t.percentage)% 当前=\(pct)% 上次=\(self.lastBatteryPct.map{"\($0)%"} ?? "nil") 未跨越")
                    }
                case .chargerConnected:
                    if isCharging, stateChanged, self.chargerConnectedFired.insert(a.id).inserted {
                        self.fire(a)
                    }
                case .chargerDisconnected:
                    if !isCharging, stateChanged {
                        self.fire(a)
                    }
                }
            }

            self.lastBatteryPct = pct
        }
    }

    // MARK: - Time

    private func setupTime() {
        TimeMonitor.shared.onTimeReached = { [weak self] h, m in
            guard let self else { return }
            let today = Calendar.current.startOfDay(for: Date())
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let dayStr = formatter.string(from: today)

            for a in self.store.automations where a.isEnabled {
                guard case .time(let t) = a.trigger, t.hour == h, t.minute == m else { continue }
                let key = "\(dayStr) \(t.displayTime)"
                guard self.timeFiredKeys[a.id] != key else { continue }
                self.timeFiredKeys[a.id] = key
                self.fire(a)
            }
        }
    }

    // MARK: - WiFi

    private func setupWiFi() {
        WiFiMonitor.shared.onWiFiChanged = { [weak self] ssid in
            guard let self else { return }
            for a in self.store.automations where a.isEnabled {
                guard case .wifi(let t) = a.trigger else { continue }
                switch t.condition {
                case .connected:
                    if let ssid, ssid == t.networkName { self.fire(a) }
                case .disconnected:
                    if ssid == nil || ssid != t.networkName { self.fire(a) }
                }
            }
        }
    }

    // MARK: - App

    private func setupApp() {
        AppMonitor.shared.onAppOpened = { [weak self] bundleID, _ in
            guard let self else { return }
            for a in self.store.automations where a.isEnabled {
                guard case .app(let t) = a.trigger,
                      t.condition == .opened,
                      t.bundleIdentifier == bundleID
                else { continue }
                self.fire(a)
            }
        }

        AppMonitor.shared.onAppClosed = { [weak self] bundleID, _ in
            guard let self else { return }
            for a in self.store.automations where a.isEnabled {
                guard case .app(let t) = a.trigger,
                      t.condition == .closed,
                      t.bundleIdentifier == bundleID
                else { continue }
                self.fire(a)
            }
        }
    }

    // MARK: - Fire

    private func fire(_ automation: Automation) {
        stLog("🔥 触发: \(automation.name)")
        if let text = automation.speechText, !text.isEmpty {
            speak(text: text, voice: automation.speechVoice)
        } else {
            notif.send(title: automation.notificationTitle, body: automation.notificationBody)
        }
    }

    /// 用 say 播报。若系统音量过低或静音，先临时调到可听音量，播完后恢复原始音量与静音状态。
    /// text / voice 作为参数传给脚本（$2 / $1），避免引号等特殊字符导致的注入问题。
    private func speak(text: String, voice: String?) {
        let minVolume = 40   // 可听音量阈值（0–100）
        let script = """
        target=\(minVolume)
        orig=$(osascript -e 'output volume of (get volume settings)')
        muted=$(osascript -e 'output muted of (get volume settings)')
        changed=0
        if [ "${orig:-0}" -lt "$target" ] || [ "$muted" = "true" ]; then
          osascript -e "set volume output volume $target without output muted"
          changed=1
        fi
        if [ -n "$1" ]; then /usr/bin/say -v "$1" "$2"; else /usr/bin/say "$2"; fi
        if [ "$changed" = "1" ]; then
          if [ "$muted" = "true" ]; then osascript -e "set volume output volume $orig with output muted";
          else osascript -e "set volume output volume $orig"; fi
        fi
        """
        let task = Process()
        task.launchPath = "/bin/bash"
        task.arguments = ["-c", script, "swifttrigger", voice ?? "", text]
        stLog("   speak voice=\(voice ?? "默认") text=\(text)")
        do {
            try task.run()
            stLog("   Process 启动成功")
        } catch {
            stLog("   Process 启动失败: \(error)")
        }
    }
}
