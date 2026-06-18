import XCTest
@testable import SwiftTrigger

/// 捕获被触发的规则，替代真正发通知/语音。
final class SpyExecutor: ActionExecutor {
    private(set) var fired: [Automation] = []
    func execute(_ automation: Automation) { fired.append(automation) }
}

final class BatteryStartupTests: XCTestCase {

    /// 构造一条「低于 20% → 发通知」的规则。
    private func belowRule() -> Automation {
        Automation(
            name: "低电量提醒",
            isEnabled: true,
            trigger: .battery(BatteryTrigger(condition: .below, percentage: 20)),
            notificationTitle: "电量低",
            notificationBody: "请充电",
            speechText: nil,
            speechVoice: nil
        )
    }

    /// 复现用户场景：开机时电量已是 15%、且在放电（未插电源），
    /// 这是引擎收到的「第一个」电池事件。期望「低于 20%」规则触发一次。
    func test_below_rule_fires_on_first_event_when_already_low_at_startup() {
        let spy = SpyExecutor()
        let rule = belowRule()
        let engine = AutomationEngine(executor: spy, automations: { [rule] })

        // 只装配回调，不启动真实监听器（避免真实硬件读数污染去重状态）。
        engine.wireCallbacks()

        // 模拟开机基线读数：引擎收到的第一个电池事件就是 15%、放电。
        BatteryMonitor.shared.onBatteryChanged?(15, false)

        XCTAssertEqual(spy.fired.count, 1,
                       "开机时电量已低于阈值且放电，应触发一次「低于」规则")
        XCTAssertEqual(spy.fired.first?.name, "低电量提醒")
    }

    /// 复现用户实测场景：电量 12% 但【充电器插着】(isCharging=true)。
    /// 「低于」语义是放电状态才触发，插电应被抑制、不触发；拔掉电源(放电)才触发。
    func test_below_rule_suppressed_while_charging_fires_when_discharging() {
        let spy = SpyExecutor()
        let rule = belowRule()
        let engine = AutomationEngine(executor: spy, automations: { [rule] })
        engine.wireCallbacks()

        // 充电中、12% < 20%：应被抑制（这就是用户日志里 充电=true 的情形）
        BatteryMonitor.shared.onBatteryChanged?(12, true)
        XCTAssertEqual(spy.fired.count, 0, "充电中不应触发「低于」规则")

        // 拔掉充电器（放电）、仍 12%：应触发一次
        BatteryMonitor.shared.onBatteryChanged?(12, false)
        XCTAssertEqual(spy.fired.count, 1, "放电且低于阈值应触发一次")
    }

    /// 复现「早启动读数竞争」：开机自启时 IOKit 电源信息尚未就绪，
    /// 首次读取返回 nil。若不重试，电量稳定不变 → 永不触发。
    /// 期望：重试拿到有效读数后，「低于」规则仍能触发一次。
    func test_below_rule_fires_after_baseline_read_retries_past_initial_nil() {
        let spy = SpyExecutor()
        let rule = belowRule()
        let engine = AutomationEngine(executor: spy, automations: { [rule] })
        engine.wireCallbacks()

        // 头两次读电源信息失败（开机早期），第三次才拿到 15%、放电。
        var reads = 0
        let monitor = BatteryMonitor.shared
        monitor.baselineRetryInterval = 0.01
        monitor.statusProvider = {
            reads += 1
            return reads < 3 ? nil : (percentage: 15, isCharging: false)
        }

        monitor.readBaseline(attempt: 0)

        let exp = expectation(description: "重试后触发")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { exp.fulfill() }
        wait(for: [exp], timeout: 1.0)

        XCTAssertEqual(spy.fired.count, 1,
                       "启动读数重试拿到有效值后，应触发一次「低于」规则")
    }
}
