import SwiftUI
import AVKit
import PhotosUI
import ImageIO
import UniformTypeIdentifiers

struct PickedFile: Transferable {
    let url: URL
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType:.data) { received in
            let copy=URL.temporaryDirectory.appending(path:UUID().uuidString+"."+received.file.pathExtension)
            try files.copyItem(at:received.file,to:copy)
            return Self(url:copy)
        }
    }
}
enum MediaIO {
    static func thumbnail(_ file:URL,video:Bool) async throws -> UIImage {
        if video {
            let generator=AVAssetImageGenerator(asset:AVURLAsset(url:file))
            generator.appliesPreferredTrackTransform=true; generator.maximumSize=CGSize(width:900,height:900)
            let (frame,_)=try await generator.image(at:.zero)
            return UIImage(cgImage:frame)
        }
        guard let source=CGImageSourceCreateWithURL(file as CFURL,nil),
              let frame=CGImageSourceCreateThumbnailAtIndex(source,0,[
                kCGImageSourceCreateThumbnailFromImageAlways:true,kCGImageSourceThumbnailMaxPixelSize:900,kCGImageSourceCreateThumbnailWithTransform:true
              ] as CFDictionary) else { throw Problem("无法读取图片。") }
        return UIImage(cgImage:frame)
    }
    static func ingest(_ url:URL,video:Bool,into dir:URL) async throws -> Attachment {
        let ext=url.pathExtension.lowercased()
        let suffix=ext.range(of:"^[a-z0-9]{1,8}$",options:.regularExpression) != nil ? ext : (video ? "mov":"img")
        let file=try digest(url)+"."+suffix
        let image=try await thumbnail(url,video:video)
        let duration=video ? try await AVURLAsset(url:url).load(.duration).seconds : 0
        guard duration.isFinite else { throw Problem("无法读取视频时长。") }
        let dest=dir.appending(path:file)
        if !files.fileExists(atPath:dest.path) { try files.copyItem(at:url,to:dest) }
        return Attachment(file:file,video:video,duration:duration,ratio:Double(image.size.width/max(image.size.height,1)))
    }
    static func cached(_ asset:Attachment,at dir:URL) async -> UIImage? {
        let thumb=URL.cachesDirectory.appending(path:asset.file+".jpg")
        if let image=UIImage(contentsOfFile:thumb.path) { return image }
        guard let image=try? await thumbnail(dir.appending(path:asset.file),video:asset.video) else { return nil }
        try? image.jpegData(compressionQuality:0.82)?.write(to:thumb,options:.atomic)
        return image
    }
}
struct Tile: View {
    let asset: Attachment
    let dir: URL
    @State private var thumb: UIImage?
    var body: some View {
        GeometryReader { g in
            ZStack(alignment:.bottomLeading) {
                Color.secondary.opacity(0.09)
                if let thumb { Image(uiImage:thumb).resizable().scaledToFill().frame(width:g.size.width,height:g.size.height).clipped() }
                if asset.video { Label(String(format:"%d:%02d",Int(asset.duration)/60,Int(asset.duration)%60),systemImage:"play.fill").font(.caption.bold()).padding(5).background(.black.opacity(0.7)).foregroundStyle(.white) }
            }
        }.clipShape(RoundedRectangle(cornerRadius:5)).task(id:asset.file) { thumb=await MediaIO.cached(asset,at:dir) }
        .accessibilityLabel(asset.video ? "播放视频" : "查看原图")
    }
}
struct Viewer: View {
    let asset:Attachment
    let dir:URL
    @Environment(\.dismiss) var dismiss
    @State private var player:AVPlayer?
    @State private var image:UIImage?
    var body:some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                if asset.video { VideoPlayer(player:player) }
                else if let image { Image(uiImage:image).resizable().scaledToFit() }
            }.toolbar { Button("完成"){dismiss()} }
        }.task {
            let url=dir.appending(path:asset.file)
            if asset.video { let p=AVPlayer(url:url); player=p;p.play() }
            else { image=await Task.detached { UIImage(contentsOfFile:url.path) }.value }
        }.onDisappear { player?.pause() }
    }
}
