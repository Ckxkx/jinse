import SwiftUI
import UniformTypeIdentifiers

@MainActor final class SyncController:ObservableObject {
    @Published var login=Login.load()
    @Published var busy=false
    @Published var progress=""
    @Published var failure=""
    @Published var enabled=UserDefaults.standard.bool(forKey:"autoSync") {
        didSet{UserDefaults.standard.set(enabled,forKey:"autoSync")}
    }
    @Published var last=UserDefaults.standard.object(forKey:"lastSync") as? Date
    @Published var known=Set(UserDefaults.standard.stringArray(forKey:"knownRevisions") ?? [])
    private var pending:Task<Void,Never>?
    func count(_ book:Library)->Int{book.items.filter{!known.contains($0.id.uuidString)}.count}
    func state(_ book:Library)->String{
        if !failure.isEmpty{return "同步失败"}
        if login.server.isEmpty{return "已保存到此设备"}
        return last==nil || count(book)>0 ? "待同步":"已同步"
    }
    func configure(_ settings:Login)throws {
        guard !busy else{throw Problem("请等待同步结束。")}
        _=try DAV(settings);try settings.store()
        if settings != login{
            known=[];last=nil;failure=""
            UserDefaults.standard.removeObject(forKey:"lastSync");UserDefaults.standard.removeObject(forKey:"knownRevisions")
        }
        login=settings
    }
    func schedule(_ book:Library){
        pending?.cancel()
        guard !CommandLine.arguments.contains("--ui-test"),ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1",enabled,book.ready,!busy,!login.server.isEmpty else{return}
        pending=Task{try? await Task.sleep(for:.seconds(2));guard !Task.isCancelled else{return};pending=nil;await run(book)}
    }
    func run(_ book:Library) async {
        guard !busy,book.ready else{return}
        busy=true;failure="";progress="读取并校验远端版本…"
        defer {
            busy=false;progress=""
            if failure.isEmpty && count(book)>0 {schedule(book)}
        }
        do {
            let client=try DAV(login),items=book.items,media=book.media
            let batch=try await client.exchange(items:items,media:media){ value in Task{@MainActor in self.progress=value} }
            defer{try? files.removeItem(at:batch.folder)}
            try await Task.detached { try batch.install(in:media) }.value
            try book.replace(History.merge(book.items,batch.items))
            known=Set(batch.items.map{$0.id.uuidString});last=Date()
            UserDefaults.standard.set(Array(known),forKey:"knownRevisions");UserDefaults.standard.set(last,forKey:"lastSync")
        }catch let e as URLError {failure="网络连接中断（"+String(e.errorCode)+"），检查网络后点立即同步。"}
        catch{failure=error.localizedDescription}
    }
}
struct Settings:View {
    @AppStorage("appearance") private var appearance="system"
    @ObservedObject var book:Library
    @ObservedObject var sync:SyncController
    let importOnOpen:Bool
    @Environment(\.dismiss) var dismiss
    @State private var config=Login.load()
    @State private var choosing=false
    @State private var batch:ImportBatch?
    @State private var exporting:URL?
    @State private var working=""
    @State private var note=""
    @State private var confirmReplace=false
    @State private var advanced=false
    var conflicts:[Moment]{book.items.filter{v in book.items.contains{$0.record==v.record && $0.id != v.id}}}
    var body:some View {
        NavigationStack{
            Form {
                Section("外观") {
                    Picker("显示模式", selection:$appearance) {
                        Text("跟随系统").tag("system")
                        Text("浅色").tag("light")
                        Text("深色").tag("dark")
                    }.pickerStyle(.segmented)
                }
                Section("设备与备份"){
                    Text(sync.state(book))
                    Button("导出完整备份（未加密）"){export()}
                    if let exporting{ShareLink(item:exporting){Label("存入文件或分享备份",systemImage:"square.and.arrow.up")}}
                    Button("从文件导入"){choosing=true}
                    if files.fileExists(atPath:book.snapshot.path){Button("打开上次恢复快照"){read(book.snapshot)}}
                }
                if let batch{
                    Section("导入预览"){
                        ImportSummary(local:book.items,incoming:batch.items)
                        Button("合并到此设备"){apply(batch,replace:false)}
                        Button("用备份替换整库",role:.destructive){confirmReplace=true}
                        Button("取消导入"){clear()}
                    }
                }
                syncSection
                if !conflicts.isEmpty{Section("同步冲突 · 选择保留的版本"){ForEach(conflicts){v in
                    VStack(alignment:.leading){Text(v.heading);Text(v.body);Text(v.deleted ? "已删除":v.status.rawValue);Button("保留此版本"){book.resolve(v)}}
                }}}
                Section("最近删除"){
                    let removed=book.items.filter(\.deleted)
                    if removed.isEmpty{Text("暂无删除的记录").foregroundStyle(.secondary)}
                    ForEach(removed){v in HStack{Text(v.heading);Spacer();Button("恢复"){book.change(v){$0.deleted=false}}}}
                }
                if !working.isEmpty{ProgressView(working)}
                if !note.isEmpty{Text(note)}
            }.disabled(!working.isEmpty || sync.busy)
            .navigationTitle("设置").navigationBarTitleDisplayMode(.inline)
            .toolbar{Button("完成"){dismiss()}.disabled(!working.isEmpty)}
            .task{if importOnOpen{choosing=true}}
            .interactiveDismissDisabled(!working.isEmpty)
            .onDisappear{clear()}
            .fileImporter(isPresented:$choosing,allowedContentTypes:[.data]){result in
                do{read(try result.get())}catch{note=error.localizedDescription}
            }
            .confirmationDialog("先备份当前整库，再替换？",isPresented:$confirmReplace,titleVisibility:.visible){Button("创建快照并替换",role:.destructive){if let batch{apply(batch,replace:true)}}}
        }
    }
    var syncSection:some View {
                Section("加密同步"){
                    Text(sync.state(book)+" · 待同步 "+String(sync.count(book))+" 条")
                    if let last=sync.last{Text("最近成功："+last.formatted(date:.abbreviated,time:.shortened)).font(.footnote)}
                    DisclosureGroup("WebDAV 连接与加密口令",isExpanded:$advanced){
                        TextField("HTTPS 服务地址",text:$config.server).textInputAutocapitalization(.never).keyboardType(.URL)
                        TextField("远端目录",text:$config.folder)
                        TextField("服务器账号",text:$config.user).textInputAutocapitalization(.never)
                        SecureField("服务器密码",text:$config.password)
                        Text("服务器密码用于登录。独立的加密口令在本设备解锁手记，新设备需要相同口令。").font(.footnote)
                        SecureField("独立加密口令",text:$config.phrase)
                        Button("测试连接"){Task{working="正在连接…";defer{working=""};do{let dav=try DAV(config);try await dav.prepare();note="连接成功。请设置加密口令后保存。"}catch{note=error.localizedDescription}}}
                        Button("保存配置"){do{try sync.configure(config);note="配置已存入钥匙串。"}catch{note=error.localizedDescription}}
                    }
                    Toggle("自动同步",isOn:$sync.enabled).onChange(of:sync.enabled){_,_ in sync.schedule(book)}
                    Button("立即同步"){Task{await sync.run(book)}}
                    if sync.busy{ProgressView(sync.progress)}
                    if !sync.failure.isEmpty{Text(sync.failure).foregroundStyle(.red)}
                }
    }
    func clear(){if let batch{try? files.removeItem(at:batch.folder)};batch=nil}
    func read(_ url:URL){
        clear();working="校验备份与全部附件…";note=""
        Task{
            defer{working=""}
            do{batch=try await Task.detached{
                let access=url.startAccessingSecurityScopedResource();defer{if access{url.stopAccessingSecurityScopedResource()}}
                return try Archive.read(url)
            }.value}catch{note="损坏或无法读取的备份：1。"+error.localizedDescription}
        }
    }
    func export(){
        working="正在导出完整备份…";let items=book.items,media=book.media
        Task{defer{working=""};do{exporting=try await Task.detached{let url=try tempFolder().appending(path:"锦瑟-未加密.jinse");try Archive.write(items,media:media,to:url);return url}.value}catch{note=error.localizedDescription}}
    }
    func apply(_ input:ImportBatch,replace:Bool){
        working="正在写入…"
        Task{defer{working=""};do{
            let items=book.items,media=book.media,snapshot=book.snapshot
            try await Task.detached{
                if replace{try Archive.write(items,media:media,to:snapshot);let checked=try Archive.read(snapshot);try? files.removeItem(at:checked.folder)}
                try input.install(in:media)
            }.value
            guard book.items==items else{throw Problem("设备数据刚刚更新，请重新确认导入。")}
            try book.replace(replace ? input.items:History.merge(items,input.items))
            clear();note="导入完成，已保存到此设备。"
        }catch{note=error.localizedDescription}}
    }
}

private struct ImportSummary:View {
    let local:[Moment],incoming:[Moment]
    private var groups:[String:[Moment]] {
        let versions=Dictionary(grouping:local,by:\.record)
        return Dictionary(grouping:incoming){ item in
            guard let existing=versions[item.record] else{return "新增"}
            if existing.contains(where:{$0.id==item.id || $0.ancestors.contains(item.id)}){return "重复"}
            return existing.allSatisfy{item.ancestors.contains($0.id)} ? "更新":"冲突"
        }
    }
    var body:some View {
        let summary=groups
        ForEach(["新增","更新","重复","冲突","损坏"],id:\.self) { label in
            let records=summary[label,default:[]]
            if records.isEmpty {Text("\(label) 0").foregroundStyle(.secondary)}
            else {
                DisclosureGroup("\(label) \(records.count)") {
                    ForEach(records){item in VStack(alignment:.leading){Text(item.heading);Text(item.date,style:.date).font(.caption)}}
                }
            }
        }
    }
}
