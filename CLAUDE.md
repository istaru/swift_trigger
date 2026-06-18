# SwiftTrigger

macOS 自动化触发器应用，补全 macOS 快捷指令（Shortcuts）缺失的"自动化"功能。
对标 iOS 快捷指令里的自动化选项卡，让 Mac 也能响应系统事件自动执行动作。

---

## 项目定位

macOS 的快捷指令不支持像 iOS 那样的"自动化"触发（电量变化、时间、网络、App 等）。
本项目监听系统事件，条件满足时自动执行动作（系统通知 / 语音播报）。
触发器与动作均可由用户在图形界面中**自由配置成多条规则**，并持久化保存。

---

## 应用形态

- SwiftUI 桌面应用，常驻运行（关闭窗口不退出，`applicationShouldTerminateAfterLastWindowClosed = false`）。
- 当前主界面为 `NavigationSplitView`：左侧栏 +「自动化」详情页（规则列表）。
- 目标界面仿照 iPhone 快捷指令，规划三个标签页：快捷指令 / 自动化 / 快捷指令中心。
  目前**仅实现「自动化」页**，另外两个标签页待实现。

---

## 核心概念：Automation 规则

每条规则（`Automation`，见 `Models/Automation.swift`）包含：

- `name`：规则名称
- `isEnabled`：是否启用
- `trigger`：触发条件（四选一，见下）
- `notificationTitle` / `notificationBody`：通知文案
- `speechText` / `speechVoice`：语音播报文本与发音人（可选）

**动作选择逻辑**（`AutomationEngine.fire`）：若填了 `speechText` 则调用 `/usr/bin/say` 语音播报（可指定 `-v` 发音人），否则发送系统通知。

规则以 JSON 持久化到 `~/Library/Application Support/SwiftTrigger/automations.json`（`AutomationStore`）。

---

## 触发器类型（4 种）

### 1. 电池 `BatteryTrigger`
条件：`低于` / `达到` 某电量百分比、`充电器已插入` / `充电器已拔出`。
- `低于`：放电状态且电量低于阈值，按放电周期去重（插上充电器后重置）。
- `达到`：电量从低于阈值「跨越」到达到阈值时触发一次。
- `充电器已插入/拔出`：电源状态切换时触发，对应去重集合在反向切换时清空。

### 2. 时间 `TimeTrigger`
条件：每天到达指定 `HH:mm`。按「日期 + 时间」key 去重，每天只触发一次。

### 3. Wi-Fi `WiFiTrigger`
条件：`连接到` / `断开连接` 指定网络（按 SSID 匹配）。

### 4. App `AppTrigger`
条件：指定 App（按 `bundleIdentifier`）`打开时` / `关闭时`。

---

## 技术方案

### 事件监听（`Monitors/`）
各监听器为单例，通过闭包回调向 `AutomationEngine` 上报事件：

- **BatteryMonitor** — IOKit `IOPSNotificationCreateRunLoopSource`，事件驱动，电源信息变化时系统主动回调，CPU 占用几乎为零。
- **AppMonitor** — `NSWorkspace` 的 `didLaunchApplicationNotification` / `didTerminateApplicationNotification`，事件驱动。
- **WiFiMonitor** — `NWPathMonitor` 监听网络路径变化，变化时用 `CoreWLAN` 的 `CWWiFiClient` 读取当前 SSID，SSID 真正变化才回调。
- **TimeMonitor** — `Timer` 每 30 秒轮询当前时分（时间触发的唯一例外：使用轮询）。

### 调度引擎（`AutomationEngine`）
单例，`start()` 时装配四类监听器回调，事件到来时遍历 `AutomationStore.automations` 中已启用且类型匹配的规则，做条件判断与去重，命中后 `fire`。
运行日志写入 `~/Library/Logs/SwiftTrigger.log`。

### 系统通知
`UserNotifications` 框架，启动时 `requestPermission()` 申请权限，触发时发本地通知（`NotificationManager`）。

### 语音播报
通过 `Process` 调用 `/usr/bin/say`，可选 `-v <发音人>`。

### 开机启动
`SMAppService.mainApp.register()`（macOS 13+），在 `applicationDidFinishLaunching` 中注册。

---

## 文件结构

```
Package.swift                         # SPM 可执行目标，链接 IOKit/CoreWLAN/SystemConfiguration/ServiceManagement
Info.plist
build_app.sh                          # swift build -c release → 打包 .app
Sources/SwiftTrigger/
├── SwiftTriggerApp.swift             # @main 入口、AppDelegate（权限/引擎启动/开机自启）
├── ContentView.swift                 # 主界面骨架（NavigationSplitView）
├── AutomationListView.swift          # 规则列表页
├── AddAutomationView.swift           # 新建规则页
├── AutomationStore.swift             # 规则持久化（JSON，ObservableObject）
├── AutomationEngine.swift            # 中央调度：监听回调 → 条件匹配/去重 → 触发动作
├── NotificationManager.swift         # 通知权限与发送
├── Models/
│   └── Automation.swift              # Automation 模型 + 四类 TriggerConfig（Codable）
└── Monitors/
    ├── BatteryMonitor.swift          # IOKit 电源事件
    ├── TimeMonitor.swift             # Timer 定时轮询
    ├── WiFiMonitor.swift             # NWPathMonitor + CoreWLAN
    └── AppMonitor.swift              # NSWorkspace App 启动/退出
```

> 注：项目为 **Swift Package（SPM）**，非 Xcode 工程。最低系统 macOS 13。

---

## 构建

```bash
bash build_app.sh                 # → build/SwiftTrigger.app
cp -r build/SwiftTrigger.app /Applications/
open /Applications/SwiftTrigger.app
```

开发阶段直接用 `swift run` 运行/热验证，无需每次完整打包。

---

## 验收清单

- [ ] 启动后申请通知权限
- [ ] 可在「自动化」页新建/启用/删除规则，重启后规则仍在（持久化）
- [ ] 电池：低于阈值放电时触发；达到阈值跨越时触发；插拔充电器触发；同周期不重复
- [ ] 时间：每天到点触发一次，当天不重复
- [ ] Wi-Fi：连接/断开指定 SSID 触发
- [ ] App：指定 App 打开/关闭触发
- [ ] 规则填了语音文本走 `say` 播报，否则发系统通知
- [ ] 开机自动启动
- [ ] 运行日志写入 `~/Library/Logs/SwiftTrigger.log`

---

## 后续扩展方向（待规划）

- 实现「快捷指令」「快捷指令中心」两个标签页
- 更多触发器（屏幕锁定/解锁、蓝牙设备连接、外接显示器等）
- 更多动作类型（运行 Shortcut、执行脚本、HTTP 请求等）
- 复合条件（多触发器组合 / 条件判断）

---

## Agent skills

### Issue tracker

Issues live in GitHub Issues (`github.com/istaru/swift_trigger`). See `docs/agents/issue-tracker.md`.

### Triage labels

Default five-label vocabulary (needs-triage / needs-info / ready-for-agent / ready-for-human / wontfix). See `docs/agents/triage-labels.md`.

### Domain docs

Single-context repo: one `CONTEXT.md` + `docs/adr/` at the repo root. See `docs/agents/domain.md`.
