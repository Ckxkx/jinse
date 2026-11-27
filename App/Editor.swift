import PhotosUI
import SwiftData
import SwiftUI

struct DraftPhoto: Identifiable {
    let id = UUID()
    var name: String?
    var bytes: Data?
    var image: UIImage? { bytes.flatMap { UIImage(data:$0) } ?? name.flatMap(Journal.image) }
}

struct Editor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    let entry: Entry?
    let saved: (Date) -> Void
    @State private var title: String, note: String, place: String, tag: String
    @State private var date: Date, photos: [DraftPhoto]
    @State private var selection: [PhotosPickerItem] = []
    @State private var loading = false, error = ""
    init(entry: Entry?, saved: @escaping (Date) -> Void) {
        self.entry = entry
        self.saved = saved
        _title = State(initialValue:entry?.title ?? "")
        _note = State(initialValue:entry?.bodyText ?? "")
        _place = State(initialValue:entry?.place ?? "")
        _tag = State(initialValue:entry?.tag ?? "日常")
        _date = State(initialValue:entry?.date ?? Date())
        _photos = State(initialValue:(entry?.photos ?? []).map { DraftPhoto(name:$0) })
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment:.leading,spacing:18) {
                    TextField("标题",text:$title).font(song(26))
                    Divider()
                    TextField("写下今天的故事…",text:$note,axis:.vertical).lineLimit(4...18)
                    ForEach(photos) { photo in
                        if let image = photo.image {
                            Image(uiImage:image).resizable().scaledToFit().overlay(alignment:.topTrailing) {
                                Button { photos.removeAll { $0.id == photo.id } } label: { Image(systemName:"xmark.circle.fill").padding(8).background(.regularMaterial,in:Circle()) }.accessibilityLabel("移除照片")
                            }
                        }
                    }
                    PhotosPicker(selection:$selection,matching:.images) { Label(loading ? "正在读取…" : "添加照片",systemImage:"photo") }.disabled(loading)
                    Divider()
                    DatePicker("日期",selection:$date,displayedComponents:.date)
                    LabeledContent("地点") { TextField("填写地点",text:$place).multilineTextAlignment(.trailing) }
                    Picker("标签",selection:$tag) { Text("旅行").tag("旅行"); Text("日常").tag("日常") }.pickerStyle(.segmented)
                }.padding()
            }.background(paper).scrollDismissesKeyboard(.interactively)
            .navigationTitle(entry == nil ? "添加记录" : "编辑记录").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement:.cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement:.confirmationAction) { Button("保存",action:save).disabled(title.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty || loading) }
            }.onChange(of:selection) { _, items in
                guard !items.isEmpty else { return }
                loading = true
                Task {
                    defer { loading = false; selection = [] }
                    for item in items {
                        if let data = try? await item.loadTransferable(type:Data.self), UIImage(data:data) != nil {
                            photos.append(DraftPhoto(bytes:data))
                        } else { error = "照片读取失败，请重新选择。" }
                    }
                }
            }.alert("未能完成",isPresented:Binding(get:{!error.isEmpty},set:{_ in error = ""})) { Button("好") {} } message: { Text(error) }
        }
    }
    private func save() {
        var created: [String] = []
        let old = entry?.photos ?? []
        do {
            try FileManager.default.createDirectory(at:Journal.folder,withIntermediateDirectories:true)
            let names = try photos.map { photo -> String in
                if let name = photo.name { return name }
                guard let bytes = photo.bytes else { throw CocoaError(.fileWriteUnknown) }
                let name = UUID().uuidString
                try bytes.write(to:Journal.folder.appending(path:name),options:.atomic)
                created.append(name)
                return name
            }
            let model = entry ?? Entry(title,date:date)
            if entry == nil { context.insert(model) }
            model.title = title; model.bodyText = note; model.place = place
            model.tag = tag; model.date = date; model.photos = names
            try context.save()
            Journal.clean(old,in:context)
            saved(date)
            dismiss()
        } catch {
            context.rollback()
            Journal.clean(created,in:context)
            self.error = "保存失败，输入内容已保留。请检查剩余空间后重试。"
        }
    }
}

struct Detail: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    let entry: Entry
    let reveal: (Date) -> Void
    @State private var editing = false, deleting = false, failed = false
    var body: some View {
        ScrollView {
            VStack(alignment:.leading,spacing:16) {
                Text(entry.title).font(song(32))
                Text(entry.date,style:.date)
                Text([entry.place,entry.tag].filter { !$0.isEmpty }.joined(separator:" · ")).foregroundStyle(.secondary)
                Text(entry.bodyText)
                ForEach(entry.photos,id:\.self) { name in
                    if let image = Journal.image(name) { Image(uiImage:image).resizable().scaledToFit() }
                }
                Button("删除记录",role:.destructive) { deleting = true }
            }.padding().frame(maxWidth:.infinity,alignment:.leading)
        }.background(paper).toolbar { Button("编辑") { editing = true } }
        .sheet(isPresented:$editing) { Editor(entry:entry,saved:reveal) }
        .confirmationDialog("确定删除这条记录？",isPresented:$deleting,titleVisibility:.visible) {
            Button("删除",role:.destructive) {
                let names = entry.photos
                context.delete(entry)
                do { try context.save(); Journal.clean(names,in:context); dismiss() }
                catch { context.rollback(); failed = true }
            }
        }.alert("删除失败，请重试。",isPresented:$failed) { Button("好") {} }
    }
}
