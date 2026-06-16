import SwiftUI
import AppKit

private struct VoiceOption: Identifiable {
    let id: String      // NSSpeechSynthesizer VoiceName rawValue
    let name: String    // human-readable, used by `say -v`
    let locale: String

    var displayLabel: String {
        locale.isEmpty ? name : "\(name)  ·  \(locale)"
    }
}

struct AddAutomationView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = AutomationStore.shared

    // 正在编辑的规则；为 nil 表示新建
    private let editing: Automation?

    // Common
    @State private var name = ""
    @State private var triggerType: TriggerTypeOption = .battery

    // Battery
    @State private var batteryCondition: BatteryTrigger.Condition = .below
    @State private var batteryPct = 20

    // Time
    @State private var timeHour = 9
    @State private var timeMinute = 0

    // WiFi
    @State private var wifiCondition: WiFiTrigger.Condition = .connected
    @State private var wifiName = ""

    // App
    @State private var appCondition: AppTrigger.Condition = .opened
    @State private var appBundleID = ""
    @State private var appName = ""

    // Notification
    @State private var notifTitle = ""
    @State private var notifBody = ""

    // Speech (battery only)
    @State private var speechText = ""
    @State private var speechVoice = ""

    private static let availableVoices: [VoiceOption] = {
        NSSpeechSynthesizer.availableVoices
            .filter { !$0.rawValue.contains(".compact.") }
            .compactMap { voiceId in
                let attrs = NSSpeechSynthesizer.attributes(forVoice: voiceId)
                guard let name = attrs[NSSpeechSynthesizer.VoiceAttributeKey.name] as? String else { return nil }
                let locale = (attrs[NSSpeechSynthesizer.VoiceAttributeKey.localeIdentifier] as? String) ?? ""
                return VoiceOption(id: voiceId.rawValue, name: name, locale: locale)
            }.sorted { $0.name.lowercased() < $1.name.lowercased() }
    }()

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

    init(editing: Automation? = nil) {
        self.editing = editing
        guard let a = editing else { return }
        _name = State(initialValue: a.name)
        _notifTitle = State(initialValue: a.notificationTitle)
        _notifBody = State(initialValue: a.notificationBody)
        _speechText = State(initialValue: a.speechText ?? "")
        _speechVoice = State(initialValue: a.speechVoice ?? "")
        switch a.trigger {
        case .battery(let t):
            _triggerType = State(initialValue: .battery)
            _batteryCondition = State(initialValue: t.condition)
            _batteryPct = State(initialValue: t.percentage)
        case .time(let t):
            _triggerType = State(initialValue: .time)
            _timeHour = State(initialValue: t.hour)
            _timeMinute = State(initialValue: t.minute)
        case .wifi(let t):
            _triggerType = State(initialValue: .wifi)
            _wifiCondition = State(initialValue: t.condition)
            _wifiName = State(initialValue: t.networkName)
        case .app(let t):
            _triggerType = State(initialValue: .app)
            _appCondition = State(initialValue: t.condition)
            _appBundleID = State(initialValue: t.bundleIdentifier)
            _appName = State(initialValue: t.appName)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    nameSection
                    triggerSection
                    if triggerType == .battery {
                        speechSection
                    } else {
                        notifSection
                    }
                }
                .padding(20)
            }
        }
        .frame(width: 500, height: 540)
        .onChange(of: triggerType)      { _ in suggestNotif() }
        .onChange(of: batteryCondition) { _ in suggestNotif() }
        .onChange(of: batteryPct)       { _ in suggestNotif() }
        .onChange(of: speechVoice)      { _ in previewVoice() }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button("取消") { dismiss() }
            Spacer()
            Text(editing == nil ? "新建自动化" : "编辑自动化").font(.headline)
            Spacer()
            Button("完成") { save() }
                .disabled(!isValid)
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    // MARK: - Sections

    private var nameSection: some View {
        sectionView(title: "名称") {
            TextField("自动化名称", text: $name)
                .textFieldStyle(.roundedBorder)
        }
    }

    private var triggerSection: some View {
        sectionView(title: "触发条件") {
            Picker("", selection: $triggerType) {
                ForEach(TriggerTypeOption.allCases, id: \.self) { opt in
                    Label(opt.rawValue, systemImage: opt.icon).tag(opt)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            Group {
                switch triggerType {
                case .battery: batteryConfig
                case .time:    timeConfig
                case .wifi:    wifiConfig
                case .app:     appConfig
                }
            }
            .padding(12)
            .background(Color(.controlBackgroundColor))
            .cornerRadius(8)
        }
    }

    private var notifSection: some View {
        sectionView(title: "通知内容") {
            TextField("通知标题", text: $notifTitle)
                .textFieldStyle(.roundedBorder)
            TextField("通知正文", text: $notifBody)
                .textFieldStyle(.roundedBorder)
        }
    }

    private var speechSection: some View {
        sectionView(title: "语音内容") {
            TextField("触发时电脑朗读的内容", text: $speechText)
                .textFieldStyle(.roundedBorder)
            HStack(spacing: 8) {
                Text("语音角色")
                    .foregroundColor(.secondary)
                Picker("", selection: $speechVoice) {
                    Text("系统默认").tag("")
                    Divider()
                    ForEach(Self.availableVoices) { voice in
                        Text(voice.displayLabel).tag(voice.name)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: .infinity, alignment: .leading)
                Button {
                    previewVoice()
                } label: {
                    Label("试听", systemImage: "speaker.wave.2")
                }
            }
        }
    }

    private func previewVoice() {
        let voice = Self.availableVoices.first { $0.name == speechVoice }
        let intro = voice.map { introText(name: $0.name, locale: $0.locale) }
            ?? "Hello, I am the default voice on your Mac."
        let task = Process()
        task.launchPath = "/usr/bin/say"
        var args: [String] = []
        if let v = voice { args += ["-v", v.name] }
        args.append(intro)
        task.arguments = args
        try? task.run()
    }

    private func introText(name: String, locale: String) -> String {
        switch String(locale.prefix(2)) {
        case "zh":
            if locale.contains("TW") { return "你好，我是\(name)。" }
            if locale.contains("HK") { return "你好，我係\(name)。" }
            return "你好，我是\(name)。"
        case "ja": return "こんにちは、私は\(name)です。"
        case "ko": return "안녕하세요, 저는 \(name)입니다."
        case "fr": return "Bonjour, je suis \(name)."
        case "de": return "Hallo, ich bin \(name)."
        case "es": return "Hola, soy \(name)."
        case "it": return "Ciao, sono \(name)."
        case "pt": return "Olá, eu sou \(name)."
        case "ru": return "Привет, я \(name)."
        case "nl": return "Hallo, ik ben \(name)."
        case "sv": return "Hej, jag är \(name)."
        case "no": return "Hei, jeg er \(name)."
        case "da": return "Hej, jeg er \(name)."
        case "fi": return "Hei, olen \(name)."
        case "pl": return "Cześć, jestem \(name)."
        case "tr": return "Merhaba, ben \(name)."
        case "ar": return "مرحبا، أنا \(name)."
        case "hi": return "नमस्ते, मैं \(name) हूँ।"
        case "th": return "สวัสดีครับ ผมชื่อ\(name)ครับ"
        default:   return "Hi, I'm \(name)."
        }
    }

    // MARK: - Trigger Config Views

    @ViewBuilder
    private var batteryConfig: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("条件", selection: $batteryCondition) {
                ForEach(BatteryTrigger.Condition.allCases, id: \.self) { c in
                    Text(c.rawValue).tag(c)
                }
            }
            .pickerStyle(.radioGroup)

            if batteryCondition == .below || batteryCondition == .reaches {
                HStack {
                    Text("电量")
                    Slider(value: Binding(
                        get: { Double(batteryPct) },
                        set: { batteryPct = Int($0) }
                    ), in: 1...100, step: 1)
                    Text("\(batteryPct)%")
                        .monospacedDigit()
                        .frame(width: 38)
                }
            }
        }
    }

    @ViewBuilder
    private var timeConfig: some View {
        HStack(spacing: 8) {
            Text("每天")
            Picker("时", selection: $timeHour) {
                ForEach(0..<24, id: \.self) { h in
                    Text(String(format: "%02d", h)).tag(h)
                }
            }
            .frame(width: 64)
            Text(":")
            Picker("分", selection: $timeMinute) {
                ForEach(stride(from: 0, through: 55, by: 5).map { $0 }, id: \.self) { m in
                    Text(String(format: "%02d", m)).tag(m)
                }
            }
            .frame(width: 64)
            Spacer()
        }
    }

    @ViewBuilder
    private var wifiConfig: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("条件", selection: $wifiCondition) {
                ForEach(WiFiTrigger.Condition.allCases, id: \.self) { c in
                    Text(c.rawValue).tag(c)
                }
            }
            .pickerStyle(.radioGroup)
            TextField("Wi-Fi 名称（SSID）", text: $wifiName)
                .textFieldStyle(.roundedBorder)
        }
    }

    @ViewBuilder
    private var appConfig: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("条件", selection: $appCondition) {
                ForEach(AppTrigger.Condition.allCases, id: \.self) { c in
                    Text(c.rawValue).tag(c)
                }
            }
            .pickerStyle(.radioGroup)
            HStack {
                TextField("应用程序名称", text: $appName)
                    .textFieldStyle(.roundedBorder)
                    .disabled(true)
                Button("选择应用…") { pickApp() }
            }
        }
    }

    // MARK: - Helpers

    private func sectionView<C: View>(title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            content()
        }
    }

    private var isValid: Bool {
        guard !name.isEmpty && triggerIsValid else { return false }
        return triggerType == .battery ? !speechText.isEmpty : !notifTitle.isEmpty
    }

    private var triggerIsValid: Bool {
        switch triggerType {
        case .battery, .time: return true
        case .wifi:           return !wifiName.isEmpty
        case .app:            return !appBundleID.isEmpty
        }
    }

    private func suggestNotif() {
        guard notifTitle.isEmpty, notifBody.isEmpty else { return }
        switch triggerType {
        case .battery:
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
        default: break
        }
    }

    private func pickApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        if panel.runModal() == .OK, let url = panel.url {
            appBundleID = Bundle(url: url)?.bundleIdentifier ?? ""
            appName = url.deletingPathExtension().lastPathComponent
        }
    }

    private func save() {
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

        let automation = Automation(
            id: editing?.id ?? UUID(),
            name: name,
            isEnabled: editing?.isEnabled ?? true,
            trigger: trigger,
            notificationTitle: notifTitle,
            notificationBody: notifBody,
            speechText: triggerType == .battery ? speechText : nil,
            speechVoice: triggerType == .battery && !speechVoice.isEmpty ? speechVoice : nil
        )
        if editing == nil {
            store.add(automation)
        } else {
            store.update(automation)
        }
        dismiss()
    }
}
