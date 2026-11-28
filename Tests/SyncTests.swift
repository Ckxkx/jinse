import XCTest
import Foundation
@testable import Timeline

// Emulate only the HTTP/WebDAV methods the client sends. Ciphertext and
// conditional requests go through the production URLSession and vault code.
private final class FixtureDAV:URLProtocol,@unchecked Sendable {
    static let lock=NSLock()
    static var objects:[String:(Data,String)]=[:]
    static var interrupt=false
    override class func canInit(with request:URLRequest)->Bool{request.url?.host=="journal-fixture.invalid"}
    override class func canonicalRequest(for request:URLRequest)->URLRequest{request}
    override func startLoading(){
        Self.lock.lock();defer{Self.lock.unlock()}
        let name=request.url!.lastPathComponent
        var status=200,data=Data(),headers:[String:String]=[:]
        switch request.httpMethod{
        case "PROPFIND":status=207
        case "GET":
            if let (bytes,etag)=Self.objects[name]{data=bytes;headers["ETag"]=etag}else{status=404}
        case "PUT":
            let current=Self.objects[name]?.1
            if let match=request.value(forHTTPHeaderField:"If-Match"),match != current{status=412}
            else if request.value(forHTTPHeaderField:"If-None-Match")=="*",current != nil{status=412}
            else if Self.interrupt && name==DAV.head {
                client?.urlProtocol(self,didFailWithError:URLError(.networkConnectionLost));return
            }else{
                var bytes=request.httpBody ?? Data()
                if let stream=request.httpBodyStream{
                    stream.open();defer{stream.close()};var buffer=[UInt8](repeating:0,count:16384)
                    while true {let n=stream.read(&buffer,maxLength:buffer.count);if n<=0{break};bytes.append(contentsOf:buffer.prefix(n))}
                }
                let tag="\""+UUID().uuidString+"\"";Self.objects[name]=(bytes,tag);headers["ETag"]=tag;status=201
            }
        case "DELETE":Self.objects[name]=nil;status=204
        default:status=405
        }
        client?.urlProtocol(self,didReceive:HTTPURLResponse(url:request.url!,statusCode:status,httpVersion:"HTTP/1.1",headerFields:headers)!,cacheStoragePolicy:.notAllowed)
        client?.urlProtocol(self,didLoad:data);client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading(){}
}
final class SyncTests:XCTestCase {
    func testTwoLibrariesConflictWrongKeyAndInterruptedPublication()async throws{
        let configuration=URLSessionConfiguration.ephemeral;configuration.protocolClasses=[FixtureDAV.self]
        let session=URLSession(configuration:configuration);defer{session.invalidateAndCancel()}
        var config=Login();config.server="https://journal-fixture.invalid";config.phrase="测试设备口令"
        let dav=try DAV(config,transport:session)
        let a=try tempFolder(),b=try tempFolder()
        defer{try? files.removeItem(at:a);try? files.removeItem(at:b)}
        var start=Moment();start.body="写下海风和潮声"
        let raw=a.appending(path:"original");try Data("original image bytes".utf8).write(to:raw)
        let file=try digest(raw)+".jpg";try files.moveItem(at:raw,to:a.appending(path:file))
        start.media=[Attachment(file:file,video:false,duration:0,ratio:1)]
        let one=try await dav.exchange(items:[start],media:a){_ in};defer{try? files.removeItem(at:one.folder)}
        let two=try await dav.exchange(items:[],media:b){_ in};defer{try? files.removeItem(at:two.folder)}
        try two.install(in:b);XCTAssertEqual(two.items,[start]);XCTAssertEqual(try digest(b.appending(path:file)),String(file.prefix(64)))
        var left=start.revised(),right=start.revised();left.body="在第一台继续写";right.deleted=true
        let upload=try await dav.exchange(items:[left],media:a){_ in};defer{try? files.removeItem(at:upload.folder)}
        let before=FixtureDAV.objects[DAV.head]!.0
        config.phrase="错误口令"
        do{_=try await DAV(config,transport:session).exchange(items:[right],media:b){_ in};XCTFail("应拒绝错误口令")}catch{}
        XCTAssertEqual(FixtureDAV.objects[DAV.head]?.0,before)
        FixtureDAV.interrupt=true
        do{_=try await dav.exchange(items:[right],media:b){_ in};XCTFail("应保留旧清单")}catch{}
        FixtureDAV.interrupt=false
        XCTAssertEqual(FixtureDAV.objects[DAV.head]?.0,before)
        let retry=try await dav.exchange(items:[right],media:b){_ in};defer{try? files.removeItem(at:retry.folder)}
        XCTAssertEqual(Set(retry.items.map(\.id)),[left.id,right.id])
        let again=try await dav.exchange(items:[left],media:a){_ in};defer{try? files.removeItem(at:again.folder)}
        XCTAssertEqual(Set(again.items.map(\.id)),[left.id,right.id])
    }
}
