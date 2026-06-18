import Foundation
import IOKit.ps

class BatteryMonitor {
    static let shared = BatteryMonitor()

    var onBatteryChanged: ((Int, Bool) -> Void)?

    /// 电源状态读取来源。默认读真实硬件，测试可注入桩。
    lazy var statusProvider: () -> (percentage: Int, isCharging: Bool)? = { [weak self] in
        self?.currentStatus()
    }

    /// 启动基线读数失败时的重试间隔与最大次数。
    /// 开机自启时 IOKit 电源信息可能尚未就绪，单次读取会拿到 nil，需重试兜底。
    var baselineRetryInterval: TimeInterval = 0.5
    var baselineMaxRetries: Int = 20

    private var runLoopSource: CFRunLoopSource?

    func start() {
        let ctx = UnsafeMutableRawPointer(Unmanaged.passRetained(self).toOpaque())
        runLoopSource = IOPSNotificationCreateRunLoopSource({ ctx in
            guard let ctx else { return }
            Unmanaged<BatteryMonitor>.fromOpaque(ctx).takeUnretainedValue().handleChange()
        }, ctx)?.takeRetainedValue()

        if let src = runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), src, .defaultMode)
        }

        // 启动时主动建立基线。若电源信息尚未就绪（读到 nil），定时重试，
        // 否则"开机即低于阈值且电量不再变化"的场景会因为没有后续事件而永不触发。
        readBaseline(attempt: 0)
    }

    /// 读取启动基线；读到 nil 时按 baselineRetryInterval 重试，最多 baselineMaxRetries 次。
    func readBaseline(attempt: Int) {
        if let (pct, charging) = statusProvider() {
            onBatteryChanged?(pct, charging)
            return
        }
        guard attempt < baselineMaxRetries else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + baselineRetryInterval) { [weak self] in
            self?.readBaseline(attempt: attempt + 1)
        }
    }

    func stop() {
        if let src = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), src, .defaultMode)
            runLoopSource = nil
        }
    }

    func currentStatus() -> (percentage: Int, isCharging: Bool)? {
        let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources  = IOPSCopyPowerSourcesList(snapshot).takeRetainedValue() as [CFTypeRef]

        for source in sources {
            guard let desc = IOPSGetPowerSourceDescription(snapshot, source)?
                    .takeUnretainedValue() as? [String: Any]
            else { continue }

            let capacity    = desc[kIOPSCurrentCapacityKey] as? Int ?? 0
            let maxCapacity = desc[kIOPSMaxCapacityKey] as? Int ?? 100
            let percentage  = maxCapacity > 0 ? capacity * 100 / maxCapacity : capacity
            let isCharging  = desc[kIOPSPowerSourceStateKey] as? String == kIOPSACPowerValue
            return (percentage, isCharging)
        }
        return nil
    }

    private func handleChange() {
        guard let (pct, charging) = statusProvider() else { return }
        onBatteryChanged?(pct, charging)
    }
}
