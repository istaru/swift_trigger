import SwiftUI

extension TriggerConfig {
    var iconName: String {
        switch self {
        case .battery: return "battery.50"
        case .time:    return "clock.fill"
        case .wifi:    return "wifi"
        case .app:     return "app.badge.fill"
        }
    }

    var iconColor: Color {
        switch self {
        case .battery: return .green
        case .time:    return .blue
        case .wifi:    return .indigo
        case .app:     return .orange
        }
    }

    var summary: String {
        switch self {
        case .battery(let t):
            switch t.condition {
            case .below:               return "电量低于 \(t.percentage)%"
            case .reaches:             return "电量达到 \(t.percentage)%"
            case .chargerConnected:    return "充电器已插入"
            case .chargerDisconnected: return "充电器已拔出"
            }
        case .time(let t):
            return "每天 \(t.displayTime)"
        case .wifi(let t):
            return t.condition == .connected ? "连接到「\(t.networkName)」" : "断开「\(t.networkName)」"
        case .app(let t):
            return "\(t.appName) \(t.condition.rawValue)"
        }
    }
}
