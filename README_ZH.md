# SwiftTrigger 中文介绍

SwiftTrigger 是一款 macOS 自动化触发器应用，用来补全 macOS 快捷指令（Shortcuts）缺失的「自动化」功能。它对标 iOS 快捷指令里的自动化选项卡，让 Mac 也能响应系统事件、在条件满足时自动执行动作。纯 Swift + SwiftUI 实现，无 Electron、无 Flutter、无臃肿运行时。

> 英文完整文档请见 [README.md](README.md)

---

## 为什么做这个

macOS 的快捷指令不支持像 iOS 那样的「自动化」触发（电量变化、时间、网络、App 等）。SwiftTrigger 监听这些系统事件，当你配置的规则命中时，自动执行动作（系统通知或语音播报）。规则可在图形界面里自由配置成多条，并持久化保存。

---

## 功能一览

| 功能 | 说明 |
|------|------|
| 电池触发 | `低于` / `达到` 某电量百分比、`充电器已插入` / `充电器已拔出` |
| 时间触发 | 每天到达指定 `HH:mm` |
| Wi-Fi 触发 | `连接到` / `断开连接` 指定 SSID |
| App 触发 | 指定 App（按 bundle id）`打开时` / `关闭时` |
| 动作类型 | 填了语音文本走 `/usr/bin/say` 播报（可选发音人），否则发系统通知 |
| 多条规则 | 在界面里自由新建 / 启用停用 / 删除任意条规则 |
| 持久化 | 规则以 JSON 保存，重启后仍在 |
| 事件驱动 | IOKit / NSWorkspace / NWPathMonitor 回调，空闲时几乎零 CPU（仅时间触发用轮询） |
| 开机启动 | macOS 13+ 用 `SMAppService` 注册 |
| 后台常驻 | 关闭窗口不退出应用 |

---

## 系统要求

- macOS 13.0 Ventura 及以上
- Swift 5.9+（使用 `swift build` 编译）
- 支持 Apple Silicon 与 Intel

---

## 安装方式

```bash
git clone https://github.com/istaru/swift_trigger.git
cd swift_trigger
bash build_app.sh
cp -r build/SwiftTrigger.app /Applications/
open /Applications/SwiftTrigger.app
```

首次启动会申请通知权限，请允许，通知类动作才能正常触发。

---

## 技术实现简述

- **监听器（`Monitors/`）** 均为单例，通过闭包回调把事件上报给 `AutomationEngine`：
  - **BatteryMonitor**：IOKit `IOPSNotificationCreateRunLoopSource`，电源信息变化时系统主动回调
  - **AppMonitor**：`NSWorkspace` 的 App 启动/退出通知
  - **WiFiMonitor**：`NWPathMonitor` 监听网络变化，再用 CoreWLAN 读 SSID，SSID 真正变化才回调
  - **TimeMonitor**：`Timer` 每 30 秒轮询当前时分（唯一的轮询例外）
- **调度引擎 `AutomationEngine`**：单例，`start()` 装配四类回调，事件到来时遍历已启用且类型匹配的规则，做条件判断与去重，命中后 `fire`
- **去重**：电池「低于」按放电周期去重、「达到」按跨越阈值去重、插拔按电源状态切换去重；时间按「日期+时间」去重，每天一次
- **动作**：填了 `speechText` 走 `say` 播报，否则用 `UserNotifications` 发本地通知

---

## 数据位置

| 内容 | 路径 |
|------|------|
| 规则 | `~/Library/Application Support/SwiftTrigger/automations.json` |
| 日志 | `~/Library/Logs/SwiftTrigger.log` |

---

## 后续规划

- 实现「快捷指令」「快捷指令中心」另外两个标签页
- 更多触发器（屏幕锁定/解锁、蓝牙设备、外接显示器等）
- 更多动作类型（运行 Shortcut、执行脚本、HTTP 请求等）
- 复合条件（多触发器组合 / 条件判断）
