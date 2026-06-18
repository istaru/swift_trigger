import Foundation

let stLogURL: URL = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("Library/Logs/SwiftTrigger.log")

func stLog(_ msg: String) {
    let ts = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
    let line = "[\(ts)] \(msg)\n"
    print(line, terminator: "")
    guard let data = line.data(using: .utf8) else { return }
    if let fh = try? FileHandle(forWritingTo: stLogURL) {
        defer { try? fh.close() }
        try? fh.seekToEnd()
        try? fh.write(contentsOf: data)
    } else {
        try? data.write(to: stLogURL)
    }
}
