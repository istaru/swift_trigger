import Foundation
import Combine

class AutomationStore: ObservableObject {
    static let shared = AutomationStore()

    @Published var automations: [Automation] = [] {
        didSet { save() }
    }

    private let saveURL: URL = {
        let dir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SwiftTrigger")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("automations.json")
    }()

    init() { load() }

    func add(_ automation: Automation) {
        automations.append(automation)
    }

    func update(_ automation: Automation) {
        guard let i = automations.firstIndex(where: { $0.id == automation.id }) else { return }
        automations[i] = automation
    }

    func remove(at offsets: IndexSet) {
        automations.remove(atOffsets: offsets)
    }

    func toggle(_ id: UUID) {
        guard let i = automations.firstIndex(where: { $0.id == id }) else { return }
        automations[i].isEnabled.toggle()
    }

    private func save() {
        try? JSONEncoder().encode(automations).write(to: saveURL)
    }

    private func load() {
        guard let data = try? Data(contentsOf: saveURL),
              let decoded = try? JSONDecoder().decode([Automation].self, from: data)
        else { return }
        automations = decoded
    }
}
