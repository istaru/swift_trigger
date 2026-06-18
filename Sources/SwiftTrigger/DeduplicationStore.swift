import Foundation

final class DeduplicationStore {

    private var fired: Set<String> = []

    /// 若 (id, key) 组合尚未触发，记录并返回 true；重复则返回 false。
    func shouldFire(id: UUID, key: String) -> Bool {
        fired.insert("\(id.uuidString):\(key)").inserted
    }

    /// 清除所有 key 以给定前缀开头的记录（跨所有 automation）。
    /// 用于状态反转时重置相关去重槽，例如插上充电器后重置"电量低"去重。
    func clearAll(keyPrefix: String) {
        fired = fired.filter { entry in
            guard let colon = entry.firstIndex(of: ":") else { return true }
            return !entry[entry.index(after: colon)...].hasPrefix(keyPrefix)
        }
    }
}
