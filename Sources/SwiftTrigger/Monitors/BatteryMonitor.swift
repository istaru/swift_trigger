import Foundation
import IOKit.ps

class BatteryMonitor {
    static let shared = BatteryMonitor()

    var onBatteryChanged: ((Int, Bool) -> Void)?

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

        // 启动时主动读一次，建立基线（引擎据此把首次事件视为基线、不触发插拔类规则）
        handleChange()
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
        guard let (pct, charging) = currentStatus() else { return }
        onBatteryChanged?(pct, charging)
    }
}
