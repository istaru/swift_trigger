import Foundation

protocol ActionExecutor {
    func execute(_ automation: Automation)
}

final class DefaultActionExecutor: ActionExecutor {
    private let notif = NotificationManager.shared

    func execute(_ automation: Automation) {
        stLog("🔥 触发: \(automation.name)")
        if let text = automation.speechText, !text.isEmpty {
            speak(text: text, voice: automation.speechVoice)
        } else {
            notif.send(title: automation.notificationTitle, body: automation.notificationBody)
        }
    }

    /// 用 say 播报。若系统音量过低或静音，先临时调到可听音量，播完后恢复原始音量与静音状态。
    /// text / voice 作为参数传给脚本（$2 / $1），避免引号等特殊字符导致的注入问题。
    private func speak(text: String, voice: String?) {
        let minVolume = 40
        let script = """
        target=\(minVolume)
        orig=$(osascript -e 'output volume of (get volume settings)')
        muted=$(osascript -e 'output muted of (get volume settings)')
        changed=0
        if [ "${orig:-0}" -lt "$target" ] || [ "$muted" = "true" ]; then
          osascript -e "set volume output volume $target without output muted"
          changed=1
        fi
        if [ -n "$1" ]; then /usr/bin/say -v "$1" "$2"; else /usr/bin/say "$2"; fi
        if [ "$changed" = "1" ]; then
          if [ "$muted" = "true" ]; then osascript -e "set volume output volume $orig with output muted";
          else osascript -e "set volume output volume $orig"; fi
        fi
        """
        let task = Process()
        task.launchPath = "/bin/bash"
        task.arguments = ["-c", script, "swifttrigger", voice ?? "", text]
        stLog("   speak voice=\(voice ?? "默认") text=\(text)")
        do {
            try task.run()
            stLog("   Process 启动成功")
        } catch {
            stLog("   Process 启动失败: \(error)")
        }
    }
}
