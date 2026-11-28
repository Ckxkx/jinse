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
