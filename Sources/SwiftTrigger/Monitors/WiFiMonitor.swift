import Foundation
import Network
import CoreWLAN

class WiFiMonitor {
    static let shared = WiFiMonitor()

    var onWiFiChanged: ((String?) -> Void)?

    private var monitor: NWPathMonitor?
    private var currentSSID: String?

    func start() {
        currentSSID = ssid()
        monitor = NWPathMonitor()
        monitor?.pathUpdateHandler = { [weak self] _ in
            let newSSID = self?.ssid()
            DispatchQueue.main.async {
                guard newSSID != self?.currentSSID else { return }
                self?.currentSSID = newSSID
                self?.onWiFiChanged?(newSSID)
            }
        }
        monitor?.start(queue: .global(qos: .background))
    }

    func stop() {
        monitor?.cancel()
        monitor = nil
    }

    private func ssid() -> String? {
        CWWiFiClient.shared().interface()?.ssid()
    }
}
