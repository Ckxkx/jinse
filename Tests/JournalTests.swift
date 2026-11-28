import XCTest
import CryptoKit
import SwiftData
@testable import Timeline

final class JournalTests:XCTestCase {
    func testBackdatedHistoryAndRoundtrip() throws {
        let dir=try tempFolder();defer{try? files.removeItem(at:dir)}
        var item=Moment();item.date=Date().addingTimeInterval(-86400);item.body="昨天沿着海岸走了一小时。";item.status = .paused
        for ext in ["jpg","mov"] {
            let bytes=Data(("fixture-"+ext).utf8)
            let file=SHA256.hash(data:bytes).map{String(format:"%02x",$0)}.joined()+"."+ext
            try bytes.write(to:dir.appending(path:file))
            item.media.append(Attachment(file:file,video:ext=="mov",duration:ext=="mov" ? 2:0,ratio:1.5))
        }
        let archive=dir.appending(path:"backup")
        try Archive.write([item],media:dir,to:archive)
        let restored=try Archive.read(archive);defer{try? files.removeItem(at:restored.folder)}
        XCTAssertEqual(restored.items,[item])
        for a in item.media { XCTAssertEqual(try Data(contentsOf:restored.folder.appending(path:a.file)),try Data(contentsOf:dir.appending(path:a.file))) }
        XCTAssertEqual(try History.merge(restored.items,restored.items),[item])
        var next=item.revised();next.status = .done;XCTAssertEqual(next.date,item.date);next.date=Date()
        XCTAssertEqual(try History.merge(restored.items,[next]),[next])
        let handle=try FileHandle(forWritingTo:archive);try handle.truncate(atOffset:14);try handle.close()
        XCTAssertThrowsError(try Archive.read(archive))
    }
    func testBranchesAndEncryption() throws {
        let item=Moment();var a=item.revised(),b=item.revised();a.deleted=true;b.body="离线修改"
        let merged=try History.merge([a],[b]);XCTAssertEqual(Set(merged.map(\.id)),[a.id,b.id])
        let salt=Data(repeating:0x76,count:16)
        let master=try Vault.key("独立口令",salt:salt)
        let blob=try Vault.seal(JSONEncoder().encode(merged),key:master,name:"fixture")
        let other=try Vault.key("独立口令",salt:salt)
        XCTAssertEqual(try JSONDecoder().decode([Moment].self,from:Vault.open(blob,key:other,name:"fixture")),merged)
        XCTAssertThrowsError(try Vault.open(blob,key:Vault.key("错误",salt:salt),name:"fixture"))
        XCTAssertThrowsError(try Vault.open(Data(blob.dropLast()),key:other,name:"fixture"))
    }
}

extension JournalTests {
    @MainActor func testRealMixedMediaRestartAndLegacyRecovery() async throws {
        let root=try tempFolder();defer{try? files.removeItem(at:root)}
        let container=try ModelContainer(for:Entry.self,SeedMarker.self,configurations:ModelConfiguration(isStoredInMemoryOnly:true))
        let old=Entry("旧手记",date:Journal.october(12),place:"厦门",photos:["sample-sea"])
        old.bodyText="海边的栈道";container.mainContext.insert(old);try container.mainContext.save()
        let book=Library(root:root);await book.start(container.mainContext)
        XCTAssertTrue(book.ready,book.error)
        XCTAssertEqual(book.items.first?.body,old.bodyText)
        let snapshot=try Archive.read(book.snapshot);defer{try? files.removeItem(at:snapshot.folder)}
        XCTAssertEqual(snapshot.items,book.items)
        var sample=try await Samples.make(in:book.media)[0]
        sample.date=Calendar.current.date(byAdding:.day,value:-1,to:Date())!
        sample.status = .paused
        try book.save(sample)
        let again=Library(root:root);await again.start(container.mainContext)
        let saved=try XCTUnwrap(again.items.first{$0.id==sample.id})
        XCTAssertEqual(saved,sample)
        for asset in saved.media {
            let original=again.media.appending(path:asset.file)
            let frame=try await MediaIO.thumbnail(original,video:asset.video)
            XCTAssertGreaterThan(frame.size.width,0)
            if asset.video{XCTAssertGreaterThan(asset.duration,0)}
        }
        var edit=saved.revised();edit.status = .done;edit.date=Date();try again.save(edit)
        XCTAssertEqual(again.items.first,edit)
        let exported=root.appending(path:"空白还原.jinse");try Archive.write(again.items,media:again.media,to:exported)
        let destination=try tempFolder();defer{try? files.removeItem(at:destination)}
        let empty=Library(root:destination);try files.createDirectory(at:empty.media,withIntermediateDirectories:true)
        let batch=try Archive.read(exported);defer{try? files.removeItem(at:batch.folder)}
        try batch.install(in:empty.media)
        for _ in 0..<2{try empty.replace(History.merge(empty.items,batch.items))}
        XCTAssertEqual(empty.items,again.items)
        XCTAssertEqual(try digest(empty.media.appending(path:edit.media.last!.file)),String(edit.media.last!.file.prefix(64)))
    }
}
