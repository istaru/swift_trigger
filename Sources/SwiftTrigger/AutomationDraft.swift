import Combine
import Foundation

/// 编辑中的自动化规则草稿。持有所有字段状态，集中验证与构建逻辑。
/// AddAutomationView 通过 @StateObject 持有此对象，仅负责渲染。
final class AutomationDraft: ObservableObject {

    // 通用
    @Published var name: String
    @Published var triggerType: TriggerTypeOption

    // 电池
    @Published var batteryCondition: BatteryTrigger.Condition
    @Published var batteryPct: Int

    // 时间
    @Published var timeHour: Int
    @Published var timeMinute: Int

    // Wi-Fi
    @Published var wifiCondition: WiFiTrigger.Condition
    @Published var wifiName: String

    // 应用程序
    @Published var appCondition: AppTrigger.Condition
    @Published var appBundleID: String
    @Published var appName: String

    // 通知
    @Published var notifTitle: String
    @Published var notifBody: String

    // 语音（电池触发器专用）
    @Published var speechText: String
    @Published var speechVoice: String

    // MARK: - TriggerTypeOption

    enum TriggerTypeOption: String, CaseIterable {
        case battery = "电源"
        case time    = "时间"
        case wifi    = "Wi-Fi"
        case app     = "应用程序"

        var icon: String {
            switch self {
            case .battery: return "battery.50"
            case .time:    return "clock"
            case .wifi:    return "wifi"
            case .app:     return "app.badge"
            }
        }
    }

    // MARK: - Init

    init(editing: Automation? = nil) {
        // 初始化所有字段的默认值
        name          = editing?.name ?? ""
        notifTitle    = editing?.notificationTitle ?? ""
        notifBody     = editing?.notificationBody ?? ""
        speechText    = editing?.speechText ?? ""
        speechVoice   = editing?.speechVoice ?? ""

        batteryCondition = .below;     batteryPct = 20
        timeHour = 9;                  timeMinute = 0
        wifiCondition = .connected;    wifiName = ""
        appCondition = .opened;        appBundleID = ""; appName = ""
        triggerType = .battery

        guard let a = editing else { return }
        switch a.trigger {
        case .battery(let t):
            triggerType = .battery
            batteryCondition = t.condition
            batteryPct = t.percentage
        case .time(let t):
            triggerType = .time
            timeHour = t.hour
            timeMinute = t.minute
        case .wifi(let t):
            triggerType = .wifi
            wifiCondition = t.condition
            wifiName = t.networkName
        case .app(let t):
            triggerType = .app
            appCondition = t.condition
            appBundleID = t.bundleIdentifier
            appName = t.appName
        }
    }

    // MARK: - 验证（集中在此处，不散落在 UI 控件参数里）

    var isValid: Bool {
        guard !name.isEmpty, triggerIsValid else { return false }
        return triggerType == .battery ? !speechText.isEmpty : !notifTitle.isEmpty
    }

    var triggerIsValid: Bool {
        switch triggerType {
        case .battery, .time: return true
        case .wifi:           return !wifiName.isEmpty
        case .app:            return !appBundleID.isEmpty
        }
    }

    // MARK: - 辅助

    /// 仅在通知字段为空时自动填充建议文案，不覆盖已有内容。
    func suggestNotif() {
        guard notifTitle.isEmpty, notifBody.isEmpty, triggerType == .battery else { return }
        switch batteryCondition {
        case .below:
            notifTitle = "电量过低"; notifBody = "当前电量 \(batteryPct)%，请尽快充电"
        case .reaches:
            notifTitle = "充电完成"; notifBody = "电量已达到 \(batteryPct)%"
        case .chargerConnected:
            notifTitle = "充电器已插入"; notifBody = "开始充电"
        case .chargerDisconnected:
            notifTitle = "充电器已拔出"; notifBody = "已断开充电"
        }
    }

    // MARK: - 构建

    func build(editingID: UUID? = nil, editingIsEnabled: Bool = true) -> Automation {
        let trigger: TriggerConfig
        switch triggerType {
        case .battery:
            trigger = .battery(BatteryTrigger(condition: batteryCondition, percentage: batteryPct))
        case .time:
            trigger = .time(TimeTrigger(hour: timeHour, minute: timeMinute))
        case .wifi:
            trigger = .wifi(WiFiTrigger(condition: wifiCondition, networkName: wifiName))
        case .app:
            trigger = .app(AppTrigger(condition: appCondition, bundleIdentifier: appBundleID, appName: appName))
        }
        return Automation(
            id: editingID ?? UUID(),
            name: name,
            isEnabled: editingIsEnabled,
            trigger: trigger,
            notificationTitle: notifTitle,
            notificationBody: notifBody,
            speechText: triggerType == .battery && !speechText.isEmpty ? speechText : nil,
            speechVoice: triggerType == .battery && !speechVoice.isEmpty ? speechVoice : nil
        )
    }
}
