import SwiftData
import SwiftUI

@Model final class Entry {
    var title: String
    var bodyText: String
    var date: Date
    var place: String
    var tag: String
    var photos: [String]
    init(_ title: String, date: Date, place: String = "", tag: String = "日常", photos: [String] = []) {
        self.title = title
        self.date = date
        self.place = place
        self.tag = tag
        self.photos = photos
        bodyText = ""
    }
}
@Model final class SeedMarker { var done = true; init() {} }

enum Journal {
    static let cal = Calendar(identifier: .gregorian)
    static func october(_ day: Int) -> Date {
        cal.date(from: DateComponents(year: 2026, month: 10, day: day))!
    }
    static let folder = URL.applicationSupportDirectory.appending(path: "Photos")
    static func image(_ name: String) -> UIImage? {
        if name.hasPrefix("sample-") { return UIImage(named: name) }
        return UIImage(contentsOfFile: folder.appending(path: name).path)
    }
    static func seed(_ context: ModelContext) throws {
        guard try context.fetchCount(FetchDescriptor<SeedMarker>()) == 0 else { return }
        context.insert(Entry("沿着海岸散步", date: october(18), place: "厦门 · 环岛路", tag: "旅行", photos: ["sample-sea"]))
        context.insert(Entry("周末的咖啡馆", date: october(12), place: "杭州 · 天目里", photos: ["sample-cafe"]))
        context.insert(SeedMarker())
        do { try context.save() } catch { context.rollback(); throw error }
    }
    static func clean(_ names: [String], in context: ModelContext) {
        guard let entries = try? context.fetch(FetchDescriptor<Entry>()) else { return }
        let used = Set(entries.flatMap(\.photos))
        for name in Set(names).subtracting(used) where !name.hasPrefix("sample-") {
            try? FileManager.default.removeItem(at: folder.appending(path: name))
        }
    }
}
@main struct TimelineApp: App {
    var body: some Scene {
        WindowGroup {
            Home().environment(\.locale, Locale(identifier: "zh_CN"))
        }.modelContainer(for: [Entry.self, SeedMarker.self], inMemory: CommandLine.arguments.contains("--ui-test"), isAutosaveEnabled: false)
    }
}
