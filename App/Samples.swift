#if DEBUG
import SwiftUI
import SwiftData

@MainActor enum Samples {
    static func make(in media:URL) async throws -> [Moment] {
        let tmp=try tempFolder();defer{try? files.removeItem(at:tmp)}
        var assets:[Attachment]=[]
        for name in ["sample-sea","sample-cafe"] {
            let url=tmp.appending(path:name+".png")
            guard let image=UIImage(named:name),let data=image.pngData() else{throw Problem("缺少预览插画。")}
            try data.write(to:url);assets.append(try await MediaIO.ingest(url,video:false,into:media))
        }
        let video=tmp.appending(path:"preview.mp4")
        try Data(base64Encoded:"AAAAIGZ0eXBpc29tAAACAGlzb21pc28yYXZjMW1wNDEAAANhbW9vdgAAAGxtdmhkAAAAAAAAAAAAAAAAAAAD6AAAA+gAAQAAAQAAAAAAAAAAAAAAAAEAAAAAAAAAAAAAAAAAAAABAAAAAAAAAAAAAAAAAABAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAgAAAox0cmFrAAAAXHRraGQAAAADAAAAAAAAAAAAAAABAAAAAAAAA+gAAAAAAAAAAAAAAAAAAAAAAAEAAAAAAAAAAAAAAAAAAAABAAAAAAAAAAAAAAAAAABAAAAAAGAAAABAAAAAAAAkZWR0cwAAABxlbHN0AAAAAAAAAAEAAAPoAAAgAAABAAAAAAIEbWRpYQAAACBtZGhkAAAAAAAAAAAAAAAAAABAAAAAQABVxAAAAAAALWhkbHIAAAAAAAAAAHZpZGUAAAAAAAAAAAAAAABWaWRlb0hhbmRsZXIAAAABr21pbmYAAAAUdm1oZAAAAAEAAAAAAAAAAAAAACRkaW5mAAAAHGRyZWYAAAAAAAAAAQAAAAx1cmwgAAAAAQAAAW9zdGJsAAAAv3N0c2QAAAAAAAAAAQAAAK9hdmMxAAAAAAAAAAEAAAAAAAAAAAAAAAAAAAAAAGAAQABIAAAASAAAAAAAAAABFUxhdmM2MS4xOS4xMDEgbGlieDI2NAAAAAAAAAAAAAAAGP//AAAANWF2Y0MBZAAK/+EAGGdkAAqs2UYmwEQAAAMABAAAAwAgPEiWWAEABmjr48siwP34+AAAAAAQcGFzcAAAAAEAAAABAAAAFGJ0cnQAAAAAAAAYQAAAAAAAAAAYc3R0cwAAAAAAAAABAAAABAAAEAAAAAAUc3RzcwAAAAAAAAABAAAAAQAAAChjdHRzAAAAAAAAAAMAAAABAAAgAAAAAAEAAEAAAAAAAgAAEAAAAAAcc3RzYwAAAAAAAAABAAAAAQAAAAQAAAABAAAAJHN0c3oAAAAAAAAAAAAAAAQAAALfAAAADwAAAA0AAAANAAAAFHN0Y28AAAAAAAAAAQAAA5EAAABhdWR0YQAAAFltZXRhAAAAAAAAACFoZGxyAAAAAAAAAABtZGlyYXBwbAAAAAAAAAAAAAAAACxpbHN0AAAAJKl0b28AAAAcZGF0YQAAAAEAAAAATGF2ZjYxLjcuMTAzAAAACGZyZWUAAAMQbWRhdAAAAq0GBf//qdxF6b3m2Ui3lizYINkj7u94MjY0IC0gY29yZSAxNjQgcjMxMDggMzFlMTlmOSAtIEguMjY0L01QRUctNCBBVkMgY29kZWMgLSBDb3B5bGVmdCAyMDAzLTIwMjMgLSBodHRwOi8vd3d3LnZpZGVvbGFuLm9yZy94MjY0Lmh0bWwgLSBvcHRpb25zOiBjYWJhYz0xIHJlZj0zIGRlYmxvY2s9MTowOjAgYW5hbHlzZT0weDM6MHgxMTMgbWU9aGV4IHN1Ym1lPTcgcHN5PTEgcHN5X3JkPTEuMDA6MC4wMCBtaXhlZF9yZWY9MSBtZV9yYW5nZT0xNiBjaHJvbWFfbWU9MSB0cmVsbGlzPTEgOHg4ZGN0PTEgY3FtPTAgZGVhZHpvbmU9MjEsMTEgZmFzdF9wc2tpcD0xIGNocm9tYV9xcF9vZmZzZXQ9LTIgdGhyZWFkcz0yIGxvb2thaGVhZF90aHJlYWRzPTEgc2xpY2VkX3RocmVhZHM9MCBucj0wIGRlY2ltYXRlPTEgaW50ZXJsYWNlZD0wIGJsdXJheV9jb21wYXQ9MCBjb25zdHJhaW5lZF9pbnRyYT0wIGJmcmFtZXM9MyBiX3B5cmFtaWQ9MiBiX2FkYXB0PTEgYl9iaWFzPTAgZGlyZWN0PTEgd2VpZ2h0Yj0xIG9wZW5fZ29wPTAgd2VpZ2h0cD0yIGtleWludD0yNTAga2V5aW50X21pbj00IHNjZW5lY3V0PTQwIGludHJhX3JlZnJlc2g9MCByY19sb29rYWhlYWQ9NDAgcmM9Y3JmIG1idHJlZT0xIGNyZj0yMy4wIHFjb21wPTAuNjAgcXBtaW49MCBxcG1heD02OSBxcHN0ZXA9NCBpcF9yYXRpbz0xLjQwIGFxPTE6MS4wMACAAAAAKmWIhAAS//7oyfzLJSOPdhCRvnS/Uq9HTDq9PBYc3/Xg7N4DYZmPl7dMkQAAAAtBmiNsQQ/+qlUeUAAAAAlBnkF4gj8AiIEAAAAJAZ5iakEPAOSA")!.write(to:video)
        assets.append(try await MediaIO.ingest(video,video:true,into:media))
        let calendar=Calendar.current
        let morning=calendar.date(bySettingHour:9,minute:30,second:0,of:Date())!
        var first=Moment();first.title="趁潮水退去之前，把环岛路最后一段也走完"
        first.date=morning;first.body="从码头出发，绕到海湾背面。\n风变小的时候，录下了一段安静的海面。";first.status = .done
        first.media=assets
        var second=Moment();second.title="整理沿途的照片";second.date=morning.addingTimeInterval(-3600)
        var third=Moment();third.title="等天气放晴，再回到山顶看看晚霞";third.date=calendar.date(byAdding:.day,value:-1,to:morning)!;third.status = .paused
        third.media=[assets[0]]
        return [first,second,third]
    }
}
struct JournalPreview:View {
    @StateObject private var book=Library(root:URL.temporaryDirectory.appending(path:UUID().uuidString))
    var body:some View {
        Home(book:book).modelContainer(for:[Entry.self,SeedMarker.self],inMemory:true)
            .task{do{try files.createDirectory(at:book.media,withIntermediateDirectories:true);try book.replace(await Samples.make(in:book.media));book.ready=true}catch{book.error=error.localizedDescription}}
    }
}
#Preview("同日、跨日与混合媒体"){JournalPreview()}
#endif
