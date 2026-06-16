import SwiftUI

struct AutomationListView: View {
    @ObservedObject private var store = AutomationStore.shared
    @State private var showAdd = false
    @State private var editing: Automation?

    var body: some View {
        Group {
            if store.automations.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(store.automations) { automation in
                        AutomationRow(automation: automation) { editing = automation }
                    }
                    .onDelete { store.remove(at: $0) }
                }
            }
        }
        .navigationTitle("自动化")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showAdd = true } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAdd) {
            AddAutomationView()
        }
        .sheet(item: $editing) { automation in
            AddAutomationView(editing: automation)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "bolt.slash")
                .font(.system(size: 52))
                .foregroundColor(.secondary)
            Text("暂无自动化规则")
                .font(.title2)
                .foregroundColor(.secondary)
            Text("点击右上角「+」添加你的第一条自动化")
                .foregroundColor(.secondary)
            Button("添加自动化") { showAdd = true }
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Row

struct AutomationRow: View {
    let automation: Automation
    var onSelect: () -> Void = {}
    @ObservedObject private var store = AutomationStore.shared

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: iconName)
                    .foregroundColor(iconColor)
                    .frame(width: 32, height: 32)
                    .background(iconColor.opacity(0.15))
                    .cornerRadius(8)

                VStack(alignment: .leading, spacing: 2) {
                    Text(automation.name)
                        .fontWeight(.medium)
                    Text(triggerSummary)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .contentShape(Rectangle())
            .onTapGesture { onSelect() }

            Toggle("", isOn: Binding(
                get: { automation.isEnabled },
                set: { _ in store.toggle(automation.id) }
            ))
            .labelsHidden()
        }
        .padding(.vertical, 4)
    }

    private var iconName: String {
        switch automation.trigger {
        case .battery: return "battery.50"
        case .time:    return "clock.fill"
        case .wifi:    return "wifi"
        case .app:     return "app.badge.fill"
        }
    }

    private var iconColor: Color {
        switch automation.trigger {
        case .battery: return .green
        case .time:    return .blue
        case .wifi:    return .indigo
        case .app:     return .orange
        }
    }

    private var triggerSummary: String {
        switch automation.trigger {
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
