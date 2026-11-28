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
}
@main struct TimelineApp: App {
    var body: some Scene {
        WindowGroup {
            #if DEBUG
            Home().frame(maxWidth:CommandLine.arguments.contains("--compact-preview") ? 375:nil).environment(\.locale, Locale(identifier: "zh_CN"))
            #else
            Home().environment(\.locale, Locale(identifier: "zh_CN"))
            #endif
        }.modelContainer(for: [Entry.self, SeedMarker.self], inMemory: CommandLine.arguments.contains("--ui-test"), isAutosaveEnabled: false)
    }
}
