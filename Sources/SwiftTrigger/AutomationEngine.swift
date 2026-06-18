import Foundation

class AutomationEngine {
    static let shared = AutomationEngine()

    private let dedup = DeduplicationStore()
    private let executor: ActionExecutor
    private let automations: () -> [Automation]

    private var lastIsCharging: Bool? = nil
    private var lastBatteryPct: Int? = nil

    init(executor: ActionExecutor = DefaultActionExecutor(),
         automations: @escaping () -> [Automation] = { AutomationStore.shared.automations }) {
        self.executor = executor
        self.automations = automations
    }

    func start() {
        wireCallbacks()

        BatteryMonitor.shared.start()
        TimeMonitor.shared.start()
        WiFiMonitor.shared.start()
        AppMonitor.shared.start()
    }

    /// 仅装配各监听器回调，不启动真实监听器。供 start() 与测试复用。
    func wireCallbacks() {
        setupBattery()
        setupTime()
        setupWiFi()
        setupApp()
    }

    // MARK: - Battery

    private func setupBattery() {
        BatteryMonitor.shared.onBatteryChanged = { [weak self] pct, isCharging in
            guard let self else { return }

            let isFirstEvent = (self.lastIsCharging == nil)
            let stateChanged = !isFirstEvent && (self.lastIsCharging != isCharging)
            self.lastIsCharging = isCharging

            stLog("电池事件: \(pct)% isCharging=\(isCharging) stateChanged=\(stateChanged) firstEvent=\(isFirstEvent) lastPct=\(self.lastBatteryPct.map{"\($0)%"} ?? "nil")")

            if stateChanged {
                if isCharging {
                    // 插上充电器：重置"电量低"和"充电器已拔出"两类去重槽
                    self.dedup.clearAll(keyPrefix: "battery-low")
                    self.dedup.clearAll(keyPrefix: "charger-disconnected")
                    stLog("充电器插入 → 清空 battery-low / charger-disconnected 去重")
                } else {
                    // 拔出充电器：重置"充电器已插入"去重槽
                    self.dedup.clearAll(keyPrefix: "charger-connected")
                    stLog("充电器拔出 → 清空 charger-connected 去重")
                }
            }

            for a in self.automations() where a.isEnabled {
                guard case .battery(let t) = a.trigger else { continue }
                switch t.condition {
                case .below:
                    stLog("  [\(a.name)] 条件=低于\(t.percentage)% 当前=\(pct)% 充电=\(isCharging)")
                    if !isCharging, pct < t.percentage,
                       self.dedup.shouldFire(id: a.id, key: "battery-low") {
                        self.executor.execute(a)
                    }
                case .reaches:
                    if let prev = self.lastBatteryPct, prev < t.percentage, pct >= t.percentage {
                        stLog("  [\(a.name)] 条件=达到\(t.percentage)% 跨越触发! \(prev)% → \(pct)%")
                        self.executor.execute(a)
                    } else {
                        stLog("  [\(a.name)] 条件=达到\(t.percentage)% 当前=\(pct)% 上次=\(self.lastBatteryPct.map{"\($0)%"} ?? "nil") 未跨越")
                    }
                case .chargerConnected:
                    if isCharging, stateChanged,
                       self.dedup.shouldFire(id: a.id, key: "charger-connected") {
                        self.executor.execute(a)
                    }
                case .chargerDisconnected:
                    // 修复：原代码此处缺少去重，导致充电器拔出可能重复触发
                    if !isCharging, stateChanged,
                       self.dedup.shouldFire(id: a.id, key: "charger-disconnected") {
                        self.executor.execute(a)
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
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let dayStr = formatter.string(from: Calendar.current.startOfDay(for: Date()))

            for a in self.automations() where a.isEnabled {
                guard case .time(let t) = a.trigger, t.hour == h, t.minute == m else { continue }
                if self.dedup.shouldFire(id: a.id, key: "time:\(dayStr):\(t.displayTime)") {
                    self.executor.execute(a)
                }
            }
        }
    }

    // MARK: - WiFi

    private func setupWiFi() {
        WiFiMonitor.shared.onWiFiChanged = { [weak self] ssid in
            guard let self else { return }
            for a in self.automations() where a.isEnabled {
                guard case .wifi(let t) = a.trigger else { continue }
                switch t.condition {
                case .connected:
                    if let ssid, ssid == t.networkName { self.executor.execute(a) }
                case .disconnected:
                    if ssid == nil || ssid != t.networkName { self.executor.execute(a) }
                }
            }
        }
    }

    // MARK: - App

    private func setupApp() {
        AppMonitor.shared.onAppOpened = { [weak self] bundleID, _ in
            guard let self else { return }
            // App 打开时，重置该 bundleID 的"关闭"去重槽，使下次关闭能再次触发
            self.dedup.clearAll(keyPrefix: "app-close:\(bundleID)")
            for a in self.automations() where a.isEnabled {
                guard case .app(let t) = a.trigger,
                      t.condition == .opened,
                      t.bundleIdentifier == bundleID
                else { continue }
                // 修复：原代码此处无去重；现在保证同一 App 同一运行周期只触发一次
                if self.dedup.shouldFire(id: a.id, key: "app-open:\(bundleID)") {
                    self.executor.execute(a)
                }
            }
        }

        AppMonitor.shared.onAppClosed = { [weak self] bundleID, _ in
            guard let self else { return }
            // App 关闭时，重置"打开"去重槽，使下次打开能再次触发
            self.dedup.clearAll(keyPrefix: "app-open:\(bundleID)")
            for a in self.automations() where a.isEnabled {
                guard case .app(let t) = a.trigger,
                      t.condition == .closed,
                      t.bundleIdentifier == bundleID
                else { continue }
                if self.dedup.shouldFire(id: a.id, key: "app-close:\(bundleID)") {
                    self.executor.execute(a)
                }
            }
        }
    }
}
