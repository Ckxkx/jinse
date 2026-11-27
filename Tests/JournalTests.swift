import XCTest
import SwiftData
@testable import Timeline

final class JournalTests: XCTestCase {
    @MainActor func testHistorySurvivesReopening() throws {
        let url = FileManager.default.temporaryDirectory.appending(path:UUID().uuidString)
        defer { for suffix in ["","-shm","-wal"] { try? FileManager.default.removeItem(atPath:url.path+suffix) } }
        func open() throws -> ModelContainer {
            try ModelContainer(for:Entry.self,SeedMarker.self,configurations:ModelConfiguration(url:url))
        }
        let sorted = FetchDescriptor<Entry>(sortBy:[SortDescriptor(\Entry.date,order:.reverse)])
        do {
            let c = try open()
            let db = c.mainContext
            try Journal.seed(db)
            let old = Entry("补记",date:Journal.october(2))
            db.insert(old)
            try db.save()
            XCTAssertEqual(try db.fetch(sorted).map(\.title),["沿着海岸散步","周末的咖啡馆","补记"])
            old.title = "修改"
            try db.save()
        }
        do {
            let c = try open()
            let rows = try c.mainContext.fetch(sorted)
            XCTAssertEqual(rows.last?.title,"修改")
            for row in rows { c.mainContext.delete(row) }
            try c.mainContext.save()
        }
        let c = try open()
        try Journal.seed(c.mainContext)
        XCTAssertEqual(try c.mainContext.fetchCount(sorted),0)
    }
}
