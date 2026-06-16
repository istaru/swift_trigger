import Foundation

class TimeMonitor {
    static let shared = TimeMonitor()

    var onTimeReached: ((Int, Int) -> Void)?

    private var timer: Timer?
    private var lastFiredMinute = -1

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.check()
        }
        timer?.tolerance = 5
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func check() {
        let c = Calendar.current.dateComponents([.hour, .minute], from: Date())
        guard let h = c.hour, let m = c.minute else { return }
        let minuteOfDay = h * 60 + m
        guard minuteOfDay != lastFiredMinute else { return }
        lastFiredMinute = minuteOfDay
        onTimeReached?(h, m)
    }
}
