import Foundation

struct Automation: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String
    var isEnabled: Bool = true
    var trigger: TriggerConfig
    var notificationTitle: String
    var notificationBody: String
    var speechText: String?
    var speechVoice: String?
}

// MARK: - Trigger Config

enum TriggerConfig {
    case battery(BatteryTrigger)
    case time(TimeTrigger)
    case wifi(WiFiTrigger)
    case app(AppTrigger)
}

extension TriggerConfig: Codable {
    private enum CodingKeys: CodingKey { case type, payload }
    private enum TypeName: String, Codable { case battery, time, wifi, app }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .battery(let v): try c.encode(TypeName.battery, forKey: .type); try c.encode(v, forKey: .payload)
        case .time(let v):    try c.encode(TypeName.time,    forKey: .type); try c.encode(v, forKey: .payload)
        case .wifi(let v):    try c.encode(TypeName.wifi,    forKey: .type); try c.encode(v, forKey: .payload)
        case .app(let v):     try c.encode(TypeName.app,     forKey: .type); try c.encode(v, forKey: .payload)
        }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        switch try c.decode(TypeName.self, forKey: .type) {
        case .battery: self = .battery(try c.decode(BatteryTrigger.self, forKey: .payload))
        case .time:    self = .time(try c.decode(TimeTrigger.self, forKey: .payload))
        case .wifi:    self = .wifi(try c.decode(WiFiTrigger.self, forKey: .payload))
        case .app:     self = .app(try c.decode(AppTrigger.self, forKey: .payload))
        }
    }
}

// MARK: - Trigger Types

struct BatteryTrigger: Codable {
    enum Condition: String, Codable, CaseIterable {
        case below              = "低于"
        case reaches            = "达到"
        case chargerConnected   = "充电器已插入"
        case chargerDisconnected = "充电器已拔出"
    }
    var condition: Condition
    var percentage: Int
}

struct TimeTrigger: Codable {
    var hour: Int
    var minute: Int

    var displayTime: String { String(format: "%02d:%02d", hour, minute) }
}

struct WiFiTrigger: Codable {
    enum Condition: String, Codable, CaseIterable {
        case connected    = "连接到"
        case disconnected = "断开连接"
    }
    var condition: Condition
    var networkName: String
}

struct AppTrigger: Codable {
    enum Condition: String, Codable, CaseIterable {
        case opened = "打开时"
        case closed = "关闭时"
    }
    var condition: Condition
    var bundleIdentifier: String
    var appName: String
}
