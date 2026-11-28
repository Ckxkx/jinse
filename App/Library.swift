import SwiftUI
import SwiftData
import CryptoKit

struct Problem: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}
enum StateTag: String, Codable, CaseIterable {
    case open = "未完成", done = "已完成", paused = "暂时挂起"
    var icon: String { switch self { case .open: "circle"; case .done: "checkmark.circle"; case .paused: "pause.circle" } }
}
struct Attachment: Codable, Equatable, Hashable, Identifiable {
    var id = UUID()
    var file: String
    var video: Bool
    var duration: Double
    var ratio: Double
}
struct Moment: Identifiable, Codable, Equatable {
    var id = UUID() // revision, also the identity of a conflict alternative
    var topic:String?
    var topicName:String { let value=topic?.trimmingCharacters(in:.whitespacesAndNewlines) ?? "";return value.isEmpty ? "生活手记":value }
    var record = UUID()
    var ancestors: Set<UUID> = []
    var title = "", body = "", place = "", legacyTag = ""
    var status: StateTag = .open
    var date = Date(), created = Date(), modified = Date()
    var media: [Attachment] = []
    var deleted = false
    var heading: String { title.isEmpty ? String(body.prefix(42)) : title }
    func revised() -> Moment {
        var next = self
        next.ancestors.insert(id); next.id = UUID(); next.modified = Date()
        return next
    }
}
enum History {
    static func merge(_ left: [Moment], _ right: [Moment]) throws -> [Moment] {
        var versions: [UUID:Moment] = [:]
        for item in left + right {
            if let old = versions[item.id], old != item { throw Problem("同一版本的数据不一致，已停止合并。") }
            versions[item.id] = item
        }
        var superseded: [UUID:Set<UUID>] = [:]
        for item in versions.values { superseded[item.record,default:[]].formUnion(item.ancestors) }
        return versions.values.filter { !(superseded[$0.record]?.contains($0.id) ?? false) }.sorted {
            $0.date == $1.date ? $0.id.uuidString < $1.id.uuidString : $0.date > $1.date
        }
    }
}
let files = FileManager.default
func tempFolder() throws -> URL {
    let url = URL.temporaryDirectory.appending(path:UUID().uuidString)
    try files.createDirectory(at:url,withIntermediateDirectories:true)
    return url
}
func digest(_ url: URL) throws -> String {
    let source = try FileHandle(forReadingFrom:url); defer { try? source.close() }
    var hash = SHA256()
    while let data = try source.read(upToCount:1048576), !data.isEmpty { hash.update(data:data) }
    return hash.finalize().map { String(format:"%02x",$0) }.joined()
}
@MainActor final class Library: ObservableObject {
    let root: URL
    var media: URL { root.appending(path:"Media") }
    var index: URL { root.appending(path:"events.json") }
    var snapshot: URL { root.appending(path:"恢复快照.jinse") }
    @Published private(set) var items: [Moment] = []
    @Published var error = ""
    @Published var ready = false
    init(root: URL = URL.applicationSupportDirectory.appending(path:"JournalV2")) { self.root = root }
    func start(_ context: ModelContext) async {
        guard !ready else { return }
        do {
            try files.createDirectory(at:media,withIntermediateDirectories:true)
            if files.fileExists(atPath:index.path) {
                items = try JSONDecoder().decode([Moment].self,from:Data(contentsOf:index))
            } else {
                let legacy = try context.fetch(FetchDescriptor<Entry>())
                var converted: [Moment] = []
                for e in legacy {
                    var item = Moment()
                    item.title=e.title; item.body=e.bodyText; item.place=e.place; item.legacyTag=e.tag
                    item.date=e.date; item.created=e.date; item.modified=e.date
                    for name in e.photos {
                        let url: URL
                        if name.hasPrefix("sample-") {
                            guard let bytes=UIImage(named:name)?.pngData() else { throw Problem("旧版配图无法读取。") }
                            url=URL.temporaryDirectory.appending(path:UUID().uuidString+".png")
                            try bytes.write(to:url)
                        } else { url=Journal.folder.appending(path:name) }
                        defer { if name.hasPrefix("sample-") { try? files.removeItem(at:url) } }
                        let asset=try await MediaIO.ingest(url,video:false,into:media)
                        item.media.append(asset)
                    }
                    converted.append(item)
                }
                if !legacy.isEmpty {
                    let directory=media, destination=snapshot
                    let restored = try await Task.detached { [converted] in
                        try Archive.write(converted,media:directory,to:destination)
                        let check=try Archive.read(destination); defer { try? files.removeItem(at:check.folder) }
                        return check.items
                    }.value
                    guard restored == converted else { throw Problem("迁移备份校验失败。") }
                }
                try replace(converted)
            }
            if root == URL.applicationSupportDirectory.appending(path:"JournalV2") {
                let marker=root.appending(path:"topics-introduced")
                if !files.fileExists(atPath:marker.path){
                    let examples=TopicDesign.examples.filter { sample in !items.contains{$0.record==sample.record} }
                    try replace(items+examples)
                    try Data().write(to:marker,options:.atomic)
                }
            }
            ready=true
        } catch { self.error=error.localizedDescription }
    }
    func replace(_ records: [Moment]) throws {
        let sorted=try History.merge([],records)
        try JSONEncoder().encode(sorted).write(to:index,options:.atomic)
        items=sorted
    }
    func save(_ item: Moment) throws { try replace(History.merge(items,[item])) }
    func change(_ item: Moment, _ edit: (inout Moment)->Void) {
        do { var next=item.revised(); edit(&next); try save(next) } catch { self.error=error.localizedDescription }
    }
    func resolve(_ winner: Moment) {
        change(winner) { next in
            for version in items where version.record == winner.record {
                next.ancestors.insert(version.id); next.ancestors.formUnion(version.ancestors)
            }
        }
    }
}
