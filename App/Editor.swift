import SwiftUI
import PhotosUI

struct Composer:View {
    let initial:Moment?
    @ObservedObject var book:Library
    @Environment(\.dismiss) var dismiss
    @State private var draft:Moment
    @State private var fresh:Moment
    @State private var staging:URL?
    @State private var picks:[PhotosPickerItem]=[]
    @State private var busy=false
    @State private var message=""
    @State private var discard=false
    init(initial:Moment?,book:Library){
        self.initial=initial;self.book=book
        let value=initial ?? Moment()
        _draft=State(initialValue:value);_fresh=State(initialValue:value)
    }
    func directory(_ a:Attachment)->URL { if let staging,files.fileExists(atPath:staging.appending(path:a.file).path){return staging};return book.media }
    var body:some View {
        NavigationStack {
            Form {
                Section {
                    TextField("小标题",text:$draft.title,axis:.vertical)
                    TextField("写下当时的事…",text:$draft.body,axis:.vertical).lineLimit(4...18)
                }
                Section("状态"){
                    ForEach(StateTag.allCases,id:\.self){s in Button {draft.status=s} label:{HStack{Label(s.rawValue,systemImage:s.icon);Spacer();if draft.status==s{Image(systemName:"checkmark")}}}.accessibilityAddTraits(draft.status==s ? .isSelected:[]) }
                }
                Section {DatePicker("记录时间",selection:$draft.date,displayedComponents:[.date,.hourAndMinute])}
                Section("图片与视频") {
                    ForEach(Array(draft.media.enumerated()),id:\.element.id){i,a in
                        HStack{
                            Tile(asset:a,dir:directory(a)).frame(width:65,height:52)
                            Spacer()
                            Button {draft.media.swapAt(i,i-1)} label:{Image(systemName:"arrow.up")}.disabled(i==0).accessibilityLabel("前移")
                            Button {draft.media.swapAt(i,i+1)} label:{Image(systemName:"arrow.down")}.disabled(i==draft.media.count-1).accessibilityLabel("后移")
                            Button {draft.media.remove(at:i)} label:{Image(systemName:"minus.circle")}.accessibilityLabel("移除")
                        }.buttonStyle(.borderless)
                    }
                    PhotosPicker(selection:$picks,selectionBehavior:.ordered,matching:.any(of:[.images,.videos])){Label("选择图片和视频",systemImage:"photo.on.rectangle")}
                }
                if busy {ProgressView("正在处理附件…")}
                if !message.isEmpty {Text(message).foregroundStyle(.red)}
            }.disabled(busy).navigationTitle(initial==nil ? "写记录":"编辑记录").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement:.cancellationAction){Button("取消"){if draft != fresh {discard=true}else{dismiss()}}.disabled(busy)}
                ToolbarItem(placement:.confirmationAction){Button("保存"){save()}.disabled(busy || (draft.title+draft.body).trimmingCharacters(in:.whitespacesAndNewlines).isEmpty)}
            }
            .interactiveDismissDisabled(draft != fresh || busy)
            .confirmationDialog("放弃这次修改？",isPresented:$discard,titleVisibility:.visible){Button("放弃修改",role:.destructive){dismiss()};Button("继续编辑",role:.cancel){}}
            .onChange(of:picks){_,selection in
                guard !selection.isEmpty else{return}
                busy=true
                Task {
                    defer {picks=[];busy=false}
                    do {
                        let folder=try staging ?? tempFolder();staging=folder
                        for item in selection {
                            guard let pick=try await item.loadTransferable(type:PickedFile.self) else{throw Problem("媒体未能从相册读取。")}
                            defer {try? files.removeItem(at:pick.url)}
                            let video=item.supportedContentTypes.contains{$0.conforms(to:.movie)}
                            draft.media.append(try await MediaIO.ingest(pick.url,video:video,into:folder))
                        }
                    } catch {message=error.localizedDescription}
                }
            }.onDisappear{if let staging{try? files.removeItem(at:staging)}}
        }
    }
    func save(){
        do {
            for a in draft.media {
                let dest=book.media.appending(path:a.file)
                if !files.fileExists(atPath:dest.path){try files.copyItem(at:directory(a).appending(path:a.file),to:dest)}
            }
            var item=initial==nil ? draft:draft.revised()
            item.modified=Date()
            if initial==nil {item.created=item.modified}
            try book.save(item);dismiss()
        }catch{message="保存失败，草稿已保留。"+error.localizedDescription}
    }
}
struct Detail:View {
    let item:Moment
    @ObservedObject var book:Library
    @Environment(\.dismiss) var dismiss
    @State private var editing=false
    @State private var deleting=false
    @State private var preview:Attachment?
    var current:Moment { book.items.first{$0.id==item.id} ?? book.items.first{$0.record==item.record && $0.ancestors.contains(item.id)} ?? item }
    var body:some View {
        NavigationStack{
            ScrollView{VStack(alignment:.leading,spacing:18){
                if !current.title.isEmpty { Text(current.title).font(.title2.bold()) }
                Label(current.status.rawValue,systemImage:current.status.icon)
                Text(current.date.formatted(date:.long,time:.shortened)).font(.subheadline).foregroundStyle(.secondary)
                if !current.place.isEmpty{Text(current.place)}
                if !current.body.isEmpty{Text(current.body).textSelection(.enabled)}
                Gallery(media:current.media,dir:book.media){preview=$0}
                Button("删除记录",role:.destructive){deleting=true}
            }.padding().frame(maxWidth:.infinity,alignment:.leading)}.background(paper)
            .toolbar{ToolbarItem(placement:.cancellationAction){Button("返回"){dismiss()}};ToolbarItem(placement:.primaryAction){Button("编辑"){editing=true}}}
            .sheet(isPresented:$editing){Composer(initial:current,book:book)}
            .sheet(item:$preview){Viewer(asset:$0,dir:book.media)}
            .confirmationDialog("移入最近删除？",isPresented:$deleting,titleVisibility:.visible){Button("删除，可在设置中恢复",role:.destructive){book.change(current){$0.deleted=true};dismiss()}}
        }
    }
}
