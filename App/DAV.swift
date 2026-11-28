import Foundation
import CryptoKit
import CommonCrypto
import Security

struct Login:Codable,Equatable {
    var server="",folder="Jinse",user="",password="",phrase=""
    static let query:[String:Any]=[kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:"org.jinse.timeline.sync",kSecAttrAccount as String:"dav"]
    static func load()->Login {
        var q=query;q[kSecReturnData as String]=true
        var raw:CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary,&raw)==errSecSuccess,let data=raw as? Data else{return Login()}
        return (try? JSONDecoder().decode(Login.self,from:data)) ?? Login()
    }
    func store() throws {
        let data=try JSONEncoder().encode(self)
        let attrs:[String:Any]=[kSecValueData as String:data,kSecAttrAccessible as String:kSecAttrAccessibleWhenUnlockedThisDeviceOnly]
        var status=SecItemUpdate(Self.query as CFDictionary,attrs as CFDictionary)
        if status==errSecItemNotFound{status=SecItemAdd(Self.query.merging(attrs){$1} as CFDictionary,nil)}
        guard status==errSecSuccess else{throw Problem("无法写入钥匙串，请解锁设备再试。")}
    }
}
enum Vault {
    static func key(_ phrase:String,salt:Data)throws->SymmetricKey {
        guard !phrase.isEmpty,salt.count==16 else{throw Problem("请输入独立加密口令，或检查密文格式。")}
        let password=Array(phrase.utf8);var output=[UInt8](repeating:0,count:32)
        let result=password.withUnsafeBytes{pwd in salt.withUnsafeBytes{raw in
            CCKeyDerivationPBKDF(CCPBKDFAlgorithm(kCCPBKDF2),pwd.bindMemory(to:Int8.self).baseAddress,password.count,raw.bindMemory(to:UInt8.self).baseAddress,salt.count,CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),600000,&output,32)
        }}
        guard result==kCCSuccess else{throw Problem("加密密钥派生失败。")}
        return SymmetricKey(data:output)
    }
    static func subkey(_ master:SymmetricKey,_ name:String)->SymmetricKey {
        HKDF<SHA256>.deriveKey(inputKeyMaterial:master,info:Data(name.utf8),outputByteCount:32)
    }
    static func seal(_ data:Data,key:SymmetricKey,name:String)throws->Data {
        guard let bytes=try AES.GCM.seal(data,using:subkey(key,name)).combined else{throw Problem("加密失败。")};return bytes
    }
    static func open(_ data:Data,key:SymmetricKey,name:String)throws->Data {
        do{return try AES.GCM.open(AES.GCM.SealedBox(combined:data),using:subkey(key,name))}
        catch{throw Problem("口令不正确或密文校验失败。请核对加密口令；两端数据已保留。")}
    }
}
struct Envelope:Codable {let version:Int;let salt:Data;let identity:UUID;let sealed:Data}
struct Parts:Codable {let ids:[UUID]}
final class NoRedirect:NSObject,URLSessionTaskDelegate,@unchecked Sendable {
    func urlSession(_ session:URLSession,task:URLSessionTask,willPerformHTTPRedirection response:HTTPURLResponse,newRequest request:URLRequest,completionHandler:@escaping(URLRequest?)->Void){completionHandler(nil)}
}
struct DAV {
    let root:URL, login:Login
    static let session=URLSession(configuration:.ephemeral,delegate:NoRedirect(),delegateQueue:nil)
    static let head="b41f89f7-2c31-46d3-99a4-6a65e93fa406"
    init(_ login:Login)throws {
        guard var url=URL(string:login.server),url.scheme?.lowercased()=="https",url.host != nil,url.user==nil,url.password==nil,url.query==nil,url.fragment==nil else{throw Problem("请输入完整的 HTTPS WebDAV 地址。")}
        for part in login.folder.split(separator:"/"){guard part != "." && part != ".." else{throw Problem("远端目录无效。")};url.appendPathComponent(String(part),isDirectory:true)}
        self.root=url;self.login=login
    }
    func call(_ method:String,_ name:String="",data:Data?=nil,headers:[String:String]=[:],allowed:Set<Int>=[]) async throws -> (Data,HTTPURLResponse) {
        var r=URLRequest(url:name.isEmpty ? root:root.appending(path:name));r.httpMethod=method;r.httpBody=data;r.timeoutInterval=90
        r.setValue("Basic "+Data((login.user+":"+login.password).utf8).base64EncodedString(),forHTTPHeaderField:"Authorization")
        for (key,value) in headers{r.setValue(value,forHTTPHeaderField:key)}
        let (body,response)=try await Self.session.data(for:r)
        guard let h=response as? HTTPURLResponse else{throw Problem("服务响应无效。")}
        guard (200..<300).contains(h.statusCode)||allowed.contains(h.statusCode) else{
            switch h.statusCode {
            case 401:throw Problem("登录失败，请检查 WebDAV 账号与服务器密码。")
            case 403:throw Problem("目录权限不足，请为该账号开启读写。")
            case 409,412:throw Problem("远端版本或目录已变化，请重新同步。")
            default:throw Problem("WebDAV 返回 HTTP "+String(h.statusCode)+"，请检查目录及网络后重试。")
            }
        }
        return (body,h)
    }
    func prepare() async throws {
        let (_,r)=try await call("PROPFIND",headers:["Depth":"0"],allowed:[404])
        if r.statusCode==404{_=try await call("MKCOL",allowed:[405])}
    }
    func exchange(items:[Moment],media:URL,progress:@escaping @Sendable(String)->Void) async throws -> ImportBatch {
        try await prepare()
        let tmp=try tempFolder();defer{try? files.removeItem(at:tmp)}
        let archive=tmp.appending(path:"data")
        let (raw,response)=try await call("GET",Self.head,allowed:[404])
        var merged=items
        let master:SymmetricKey,salt:Data,condition:[String:String]
        if response.statusCode==404 {
            salt=Data((0..<16).map{_ in UInt8.random(in:0...255)});master=try Vault.key(login.phrase,salt:salt);condition=["If-None-Match":"*"]
        }else{
            guard let etag=response.value(forHTTPHeaderField:"ETag"),!etag.hasPrefix("W/"),etag.hasPrefix("\"") else{throw Problem("服务器缺少强 ETag，无法安全更新远端。")}
            condition=["If-Match":etag]
            let env=try JSONDecoder().decode(Envelope.self,from:raw)
            guard env.version==1 else{throw Problem("远端格式不支持。")}
            salt=env.salt;master=try Vault.key(login.phrase,salt:salt)
            let parts=try JSONDecoder().decode(Parts.self,from:Vault.open(env.sealed,key:master,name:env.identity.uuidString))
            try Data().write(to:archive)
            let output=try FileHandle(forWritingTo:archive);defer{try? output.close()}
            for (i,id) in parts.ids.enumerated() {
                progress("下载并校验分片 "+String(i+1)+"/"+String(parts.ids.count))
                let (bytes,_)=try await call("GET",id.uuidString)
                try output.write(contentsOf:Vault.open(bytes,key:master,name:id.uuidString))
            }
            let remote=try Archive.read(archive)
            do {
                merged=try History.merge(items,remote.items)
                if Set(merged.map(\.id))==Set(remote.items.map(\.id)){return remote}
                try remote.install(in:media)
            }catch{try? files.removeItem(at:remote.folder);throw error}
            try? files.removeItem(at:remote.folder)
        }
        try Archive.write(merged,media:media,to:archive)
        let total=try files.attributesOfItem(atPath:archive.path)[.size] as? NSNumber
        let input=try FileHandle(forReadingFrom:archive);defer{try? input.close()}
        var ids:[UUID]=[],sent=0
        while let data=try input.read(upToCount:4*1024*1024),!data.isEmpty{
            let id=UUID();let sealed=try Vault.seal(data,key:master,name:id.uuidString)
            _=try await call("PUT",id.uuidString,data:sealed,headers:["If-None-Match":"*"])
            ids.append(id);sent+=data.count;progress("上传 "+String(sent*100/max(1,total?.intValue ?? sent))+"%")
        }
        let id=UUID(),sealed=try Vault.seal(JSONEncoder().encode(Parts(ids:ids)),key:master,name:id.uuidString)
        let env=Envelope(version:1,salt:salt,identity:id,sealed:sealed)
        _=try await call("PUT",Self.head,data:JSONEncoder().encode(env),headers:condition)
        return try Archive.read(archive)
    }
}
