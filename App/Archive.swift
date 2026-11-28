import Foundation
import CryptoKit

struct ImportBatch {
    let items: [Moment]
    let folder: URL
    func install(in media: URL) throws {
        for file in Set(items.flatMap { $0.media.map(\.file) }) {
            let dest=media.appending(path:file)
            if !files.fileExists(atPath:dest.path) { try files.copyItem(at:folder.appending(path:file),to:dest) }
            else if try digest(dest) != String(file.prefix(64)) { throw Problem("设备上的附件校验失败。") }
        }
    }
}
enum Archive {
    struct Asset: Codable { let name: String; let size: UInt64 }
    struct Header: Codable { let version: Int; let records: [Moment]; let assets: [Asset] }
    static let magic=Data("JINSE02\n".utf8)
    static func valid(_ name:String)->Bool { name.range(of:"^[0-9a-f]{64}\\.[a-z0-9]{1,8}$",options:.regularExpression) != nil }
    static func write(_ items:[Moment],media:URL,to url:URL) throws {
        let names=Set(items.flatMap { $0.media.map(\.file) }).sorted()
        let assets=try names.map { name -> Asset in
            guard valid(name) else { throw Problem("附件名无效。") }
            let size=try files.attributesOfItem(atPath:media.appending(path:name).path)[.size] as? NSNumber
            guard let size else { throw Problem("找不到附件。") }
            return Asset(name:name,size:size.uint64Value)
        }
        let metadata=try JSONEncoder().encode(Header(version:2,records:items,assets:assets))
        let tmp=url.deletingLastPathComponent().appending(path:UUID().uuidString)
        defer { try? files.removeItem(at:tmp) }
        try Data().write(to:tmp); let out=try FileHandle(forWritingTo:tmp); defer { try? out.close() }
        try out.write(contentsOf:magic)
        var length=UInt64(metadata.count).bigEndian
        try out.write(contentsOf:withUnsafeBytes(of:&length){Data($0)})
        try out.write(contentsOf:Data(SHA256.hash(data:metadata))); try out.write(contentsOf:metadata)
        for a in assets {
            let input=try FileHandle(forReadingFrom:media.appending(path:a.name)); defer { try? input.close() }
            while let part=try input.read(upToCount:1048576), !part.isEmpty { try out.write(contentsOf:part) }
        }
        try out.synchronize()
        if files.fileExists(atPath:url.path) { _=try files.replaceItemAt(url,withItemAt:tmp) }
        else { try files.moveItem(at:tmp,to:url) }
    }
    static func read(_ url:URL) throws -> ImportBatch {
        let input=try FileHandle(forReadingFrom:url); defer { try? input.close() }
        func take(_ count:Int)throws->Data {
            let data=try input.read(upToCount:count) ?? Data()
            guard data.count==count else { throw Problem("备份不完整，已停止导入。") }; return data
        }
        guard try take(8)==magic else { throw Problem("备份格式或版本不支持。") }
        let n=try take(8).reduce(UInt64(0)){($0<<8)|UInt64($1)}
        guard n<=128*1024*1024 else { throw Problem("备份索引过大。") }
        let expected=try take(32), data=try take(Int(n))
        guard Data(SHA256.hash(data:data))==expected else { throw Problem("记录索引损坏。") }
        let h=try JSONDecoder().decode(Header.self,from:data)
        let names=h.assets.map(\.name)
        guard h.version==2, Set(names).count==names.count, names.allSatisfy(valid),
              Set(names)==Set(h.records.flatMap { $0.media.map(\.file) }),
              Set(h.records.map(\.id)).count==h.records.count,
              h.records.allSatisfy({ !$0.ancestors.contains($0.id) && $0.media.allSatisfy { $0.ratio>0 && $0.duration>=0 } }) else { throw Problem("备份索引或附件清单无效。") }
        let folder=try tempFolder()
        do {
            for a in h.assets {
                let dest=folder.appending(path:a.name); try Data().write(to:dest)
                let out=try FileHandle(forWritingTo:dest); defer { try? out.close() }
                var remaining=a.size, hash=SHA256()
                while remaining>0 { let chunk=try take(Int(min(remaining,1048576))); hash.update(data:chunk); try out.write(contentsOf:chunk); remaining-=UInt64(chunk.count) }
                guard hash.finalize().map({String(format:"%02x",$0)}).joined()==String(a.name.prefix(64)) else { throw Problem("附件损坏，原记录已保留。") }
            }
            guard (try input.read(upToCount:1) ?? Data()).isEmpty else { throw Problem("备份含额外数据。") }
            return ImportBatch(items:h.records,folder:folder)
        } catch { try? files.removeItem(at:folder); throw error }
    }
}
