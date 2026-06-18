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
    @StateObject private var draft: AutomationDraft

    private let editing: Automation?

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

    init(editing: Automation? = nil) {
        self.editing = editing
        _draft = StateObject(wrappedValue: AutomationDraft(editing: editing))
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    nameSection
                    triggerSection
                    if draft.triggerType == .battery {
                        speechSection
                    } else {
                        notifSection
                    }
                }
                .padding(20)
            }
        }
        .frame(width: 500, height: 540)
        .onChange(of: draft.triggerType)      { _ in draft.suggestNotif() }
        .onChange(of: draft.batteryCondition) { _ in draft.suggestNotif() }
        .onChange(of: draft.batteryPct)       { _ in draft.suggestNotif() }
        .onChange(of: draft.speechVoice)      { _ in previewVoice() }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button("取消") { dismiss() }
            Spacer()
            Text(editing == nil ? "新建自动化" : "编辑自动化").font(.headline)
            Spacer()
            Button("完成") { save() }
                .disabled(!draft.isValid)
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    // MARK: - Sections

    private var nameSection: some View {
        sectionView(title: "名称") {
            TextField("自动化名称", text: $draft.name)
                .textFieldStyle(.roundedBorder)
        }
    }

    private var triggerSection: some View {
        sectionView(title: "触发条件") {
            Picker("", selection: $draft.triggerType) {
                ForEach(AutomationDraft.TriggerTypeOption.allCases, id: \.self) { opt in
                    Label(opt.rawValue, systemImage: opt.icon).tag(opt)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            Group {
                switch draft.triggerType {
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
            TextField("通知标题", text: $draft.notifTitle)
                .textFieldStyle(.roundedBorder)
            TextField("通知正文", text: $draft.notifBody)
                .textFieldStyle(.roundedBorder)
        }
    }

    private var speechSection: some View {
        sectionView(title: "语音内容") {
            TextField("触发时电脑朗读的内容", text: $draft.speechText)
                .textFieldStyle(.roundedBorder)
            HStack(spacing: 8) {
                Text("语音角色")
                    .foregroundColor(.secondary)
                Picker("", selection: $draft.speechVoice) {
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

    // MARK: - Trigger Config Views

    @ViewBuilder
    private var batteryConfig: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("条件", selection: $draft.batteryCondition) {
                ForEach(BatteryTrigger.Condition.allCases, id: \.self) { c in
                    Text(c.rawValue).tag(c)
                }
            }
            .pickerStyle(.radioGroup)

            if draft.batteryCondition == .below || draft.batteryCondition == .reaches {
                HStack {
                    Text("电量")
                    Slider(value: Binding(
                        get: { Double(draft.batteryPct) },
                        set: { draft.batteryPct = Int($0) }
                    ), in: 1...100, step: 1)
                    Text("\(draft.batteryPct)%")
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
            Picker("时", selection: $draft.timeHour) {
                ForEach(0..<24, id: \.self) { h in
                    Text(String(format: "%02d", h)).tag(h)
                }
            }
            .frame(width: 64)
            Text(":")
            Picker("分", selection: $draft.timeMinute) {
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
            Picker("条件", selection: $draft.wifiCondition) {
                ForEach(WiFiTrigger.Condition.allCases, id: \.self) { c in
                    Text(c.rawValue).tag(c)
                }
            }
            .pickerStyle(.radioGroup)
            TextField("Wi-Fi 名称（SSID）", text: $draft.wifiName)
                .textFieldStyle(.roundedBorder)
        }
    }

    @ViewBuilder
    private var appConfig: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("条件", selection: $draft.appCondition) {
                ForEach(AppTrigger.Condition.allCases, id: \.self) { c in
                    Text(c.rawValue).tag(c)
                }
            }
            .pickerStyle(.radioGroup)
            HStack {
                TextField("应用程序名称", text: $draft.appName)
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

    private func previewVoice() {
        let voice = Self.availableVoices.first { $0.name == draft.speechVoice }
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

    private func pickApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        if panel.runModal() == .OK, let url = panel.url {
            draft.appBundleID = Bundle(url: url)?.bundleIdentifier ?? ""
            draft.appName = url.deletingPathExtension().lastPathComponent
        }
    }

    private func save() {
        let automation = draft.build(
            editingID: editing?.id,
            editingIsEnabled: editing?.isEnabled ?? true
        )
        if editing == nil {
            store.add(automation)
        } else {
            store.update(automation)
        }
        dismiss()
    }
}
