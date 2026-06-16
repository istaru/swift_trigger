import Foundation
import AppKit

class AppMonitor {
    static let shared = AppMonitor()

    var onAppOpened: ((String, String) -> Void)?
    var onAppClosed: ((String, String) -> Void)?

    private var observers: [NSObjectProtocol] = []

    func start() {
        let nc = NSWorkspace.shared.notificationCenter

        observers.append(nc.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil, queue: .main
        ) { [weak self] n in
            guard let app = n.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            else { return }
            self?.onAppOpened?(app.bundleIdentifier ?? "", app.localizedName ?? "")
        })

        observers.append(nc.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil, queue: .main
        ) { [weak self] n in
            guard let app = n.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            else { return }
            self?.onAppClosed?(app.bundleIdentifier ?? "", app.localizedName ?? "")
        })
    }

    func stop() {
        observers.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
        observers = []
    }
}
