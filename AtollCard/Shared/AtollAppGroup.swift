import Foundation

enum AtollAppGroup {
    static let suiteName = "group.com.weckherlin.atollcard"
    private static let key = "activeCard"

    static func save(_ snapshot: SharedCardSnapshot?, suiteName: String = suiteName) {
        let defaults = UserDefaults(suiteName: suiteName)
        guard let snapshot else { defaults?.removeObject(forKey: key); return }
        if let data = try? JSONEncoder().encode(snapshot) { defaults?.set(data, forKey: key) }
    }

    static func load(suiteName: String = suiteName) -> SharedCardSnapshot? {
        guard let data = UserDefaults(suiteName: suiteName)?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(SharedCardSnapshot.self, from: data)
    }
}
