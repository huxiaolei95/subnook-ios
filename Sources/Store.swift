import Foundation

/// 数据存储：写在 App 的 Documents 目录，会自动进入 iCloud / iTunes 备份，
/// 换 iPhone 整机迁移时会一起带过去。
final class Store {
    static let shared = Store()

    private let fm = FileManager.default

    var dir: URL {
        fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    var file: URL {
        dir.appendingPathComponent("data.json")
    }

    /// 读原始 JSON 字符串
    func load() -> String? {
        guard let s = try? String(contentsOf: file, encoding: .utf8), !s.isEmpty else {
            return nil
        }
        return s
    }

    /// 原子写入：先写临时文件再替换，避免中途断电损坏
    @discardableResult
    func save(json: String) -> Bool {
        let tmp = dir.appendingPathComponent("data.json.tmp")
        do {
            try json.write(to: tmp, atomically: true, encoding: .utf8)
            if fm.fileExists(atPath: file.path) {
                try fm.removeItem(at: file)
            }
            try fm.moveItem(at: tmp, to: file)
            rollDailyBackup(json)
            return true
        } catch {
            return false
        }
    }

    /// 每天留一份快照，最多 14 份
    private func rollDailyBackup(_ json: String) {
        let bakDir = dir.appendingPathComponent("backup", isDirectory: true)
        try? fm.createDirectory(at: bakDir, withIntermediateDirectories: true)

        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let name = "data-\(df.string(from: Date())).json"
        let bak = bakDir.appendingPathComponent(name)

        if !fm.fileExists(atPath: bak.path) {
            try? json.write(to: bak, atomically: true, encoding: .utf8)
        }

        if let items = try? fm.contentsOfDirectory(at: bakDir, includingPropertiesForKeys: nil) {
            let sorted = items
                .filter { $0.lastPathComponent.hasPrefix("data-") && $0.pathExtension == "json" }
                .sorted { $0.lastPathComponent < $1.lastPathComponent }
            if sorted.count > 14 {
                for old in sorted.prefix(sorted.count - 14) {
                    try? fm.removeItem(at: old)
                }
            }
        }
    }
}
