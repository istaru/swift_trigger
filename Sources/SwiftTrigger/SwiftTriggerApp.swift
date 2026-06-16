import SwiftUI
import ServiceManagement

@main
struct SwiftTriggerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // 无主窗口 Scene：窗口完全由 AppDelegate 手动管理，App 常驻菜单栏。
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var statusItem: NSStatusItem?
    private var window: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 默认以「附属」身份运行：不在程序坞显示，只驻留菜单栏。
        NSApp.setActivationPolicy(.accessory)

        NotificationManager.shared.requestPermission()
        AutomationEngine.shared.start()
        try? SMAppService.mainApp.register()

        setupStatusItem()

        // 仅首次启动时自动弹出窗口；之后（含开机自启）静默驻留菜单栏。
        let key = "hasLaunchedBefore"
        if !UserDefaults.standard.bool(forKey: key) {
            UserDefaults.standard.set(true, forKey: key)
            showMainWindow()
        }
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let icon = NSImage(systemSymbolName: "square.on.square",
                           accessibilityDescription: "SwiftTrigger")
        icon?.isTemplate = true   // 单色模板：随菜单栏主题自动黑/白
        item.button?.image = icon

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "打开快捷触发器",
                                action: #selector(showMainWindow),
                                keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "退出",
                                action: #selector(quit),
                                keyEquivalent: "q"))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "卸载并清除所有数据…",
                                action: #selector(uninstall),
                                keyEquivalent: ""))
        item.menu = menu
        statusItem = item
    }

    @objc private func showMainWindow() {
        if window == nil {
            let hosting = NSHostingController(rootView: ContentView())
            let win = NSWindow(contentViewController: hosting)
            win.title = "SwiftTrigger"
            win.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            win.setContentSize(NSSize(width: 760, height: 520))
            win.center()
            win.isReleasedWhenClosed = false   // 关窗不销毁，便于再次打开
            win.delegate = self
            window = win
        }
        // 显示窗口时临时切回常规模式：出现在程序坞、获得焦点与菜单栏。
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    @objc private func uninstall() {
        let alert = NSAlert()
        alert.messageText = "卸载快捷触发器"
        alert.informativeText = "将清除所有规则、日志和偏好设置，并移除开机自启。\n\n清除后请手动将「快捷触发器.app」拖入废纸篓。"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "清除并退出")
        alert.addButton(withTitle: "取消")
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        try? SMAppService.mainApp.unregister()

        let fm = FileManager.default
        let support = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SwiftTrigger")
        try? fm.removeItem(at: support)

        let logs = fm.urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Logs/SwiftTrigger.log")
        try? fm.removeItem(at: logs)

        UserDefaults.standard.removePersistentDomain(forName: "com.swifttrigger.app")

        NSApp.terminate(nil)
    }

    // 窗口关闭后退回菜单栏驻留：移除程序坞图标，但 App 与监听继续运行。
    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
