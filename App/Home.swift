import SwiftData
import SwiftUI

let paper = Color.white
let ink = Color(white: 23/255)
let pine = Color(red: 50/255, green: 89/255, blue: 78/255)
func song(_ size: CGFloat) -> Font { .system(size: size, weight: .semibold) }

struct Home: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Entry.date, order: .reverse) private var entries: [Entry]
    @AppStorage("month") private var stamp = Journal.october(1).timeIntervalSince1970
    @State private var tag = "全部"
    @State private var query = ""
    @State private var error = ""
    @State private var searching = false
    @State private var adding = false
    @State private var calendar = false
    @State private var picking = false
    @State private var day: Date?
    @State private var overview = true
    private let cal = Journal.cal
    var month: Date { Date(timeIntervalSince1970: stamp) }
    var monthly: [Entry] { entries.filter { cal.isDate($0.date, equalTo: month, toGranularity: .month) } }
    var visible: [Entry] {
        monthly.filter { e in
            (tag == "全部" || e.tag == tag) && (query.isEmpty || [e.title,e.bodyText,e.place].contains { $0.localizedCaseInsensitiveContains(query) }) && (day.map { cal.isDate($0, inSameDayAs: e.date) } ?? true)
        }
    }
    func reset() { tag = "全部"; query = ""; day = nil }
    func reveal(_ date: Date) { stamp = date.timeIntervalSince1970; reset(); calendar = false; searching = false; overview = false }
    var body: some View {
        NavigationStack {
            Group {
            if overview { landing } else {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Button { overview = true } label: { Label("首页",systemImage:"chevron.left") }
                    Spacer()
                    Text(calendar ? "日历" : "时间线").font(.headline)
                    Spacer()
                    Button { searching.toggle(); query = "" } label: { Image(systemName: "magnifyingglass") }.accessibilityLabel("搜索")
                }
                if searching { TextField("搜索标题、正文或地点", text: $query).textFieldStyle(.roundedBorder) }
                HStack {
                    Button { picking = true } label: {
                        Text(month.formatted(.dateTime.year().month().locale(Locale(identifier:"zh_CN"))))
                        Image(systemName:"chevron.down").font(.caption)
                    }
                    Spacer()
                    ForEach(["全部","旅行","日常"], id: \.self) { item in
                        Button(item) { tag = item }.font(.subheadline).foregroundStyle(tag == item ? pine : .secondary)
                            .underline(tag == item)
                    }
                }
                Divider()
                ScrollView {
                    if calendar { calendarGrid }
                    if visible.isEmpty {
                        ContentUnavailableView {
                            Label(monthly.isEmpty ? "这个月还没有记录" : "没有匹配的记录", systemImage: "book")
                        } description: { EmptyView() } actions: {
                            if monthly.isEmpty { Text("点右下角加号，写下第一件事。").font(.footnote) } else { Button("清除条件") { reset() } }
                        }
                    }
                    LazyVStack(spacing: 0) {
                        ForEach(visible) { e in
                            let first = visible.first { cal.isDate($0.date, inSameDayAs: e.date) }
                            NavigationLink {
                                Detail(entry: e, reveal: reveal)
                            } label: {
                                HStack(alignment: .top, spacing: 12) {
                                    Text(first == e ? String(format:"%02d",cal.component(.day, from: e.date)) : "").font(song(31)).frame(width:44)
                                    Rectangle().fill(pine.opacity(0.24)).frame(width:1)
                                        .overlay(alignment:.top) { Circle().fill(pine).frame(width:8,height:8).offset(y:12) }
                                    VStack(alignment:.leading, spacing:8) {
                                        Text(e.title).font(.headline)
                                        if !e.bodyText.isEmpty { Text(e.bodyText).lineLimit(2).font(.subheadline).foregroundStyle(.secondary) }
                                        Text([e.place,e.tag].filter { !$0.isEmpty }.joined(separator:" · ")).font(.caption).foregroundStyle(.secondary)
                                        Divider().padding(.vertical,8)
                                    }.frame(maxWidth:.infinity,alignment:.leading)
                                    if let name=e.photos.first, let photo=Journal.image(name) { Image(uiImage:photo).resizable().scaledToFill().frame(width:52,height:52).clipped().cornerRadius(6) }
                                }
                            }.buttonStyle(.plain)
                        }
                    }
                }
            }.padding(.horizontal,20).padding(.top,12).background(paper)
            .safeAreaInset(edge:.bottom) {
                VStack(alignment:.trailing,spacing:4) {
                    Button { adding = true } label: {
                        Image(systemName:"plus").font(.title2.weight(.medium)).frame(width:52,height:52)
                            .background(pine,in:Circle()).foregroundStyle(.white)
                    }.accessibilityLabel("添加记录").padding(.trailing,18)
                    HStack {
                        Button("时间线") { calendar = false; day = nil }
                        Spacer()
                        Button("日历") { calendar = true }
                    }.padding(.horizontal,40).padding(.vertical,6)
                }.background(paper)
            }
            }
            }
            .sheet(isPresented:$adding) { Editor(entry:nil, saved:reveal) }
            .sheet(isPresented:$picking) {
                VStack {
                    DatePicker("选择月份",selection:Binding(get:{month},set:{stamp = $0.timeIntervalSince1970; day = nil}),displayedComponents:.date).datePickerStyle(.wheel)
                    Button("完成") { picking = false }
                }.presentationDetents([.medium])
            }.task { do { try Journal.seed(context) } catch { self.error = "示例初始化失败，请重新打开应用。" } }
            .alert("读取失败",isPresented:Binding(get:{!error.isEmpty},set:{_ in error = ""})) { Button("好") {} } message: { Text(error) }
        }.foregroundStyle(ink).tint(pine).preferredColorScheme(.light)
    }
    var landing: some View {
        ScrollView {
            VStack(alignment:.leading,spacing:24) {
                Text("锦瑟手记").font(.largeTitle.bold())
                Button { reset(); calendar = false; overview = false } label: {
                    HStack {
                        VStack(alignment:.leading,spacing:6) {
                            Text("我的时间线").font(.title2.bold())
                            Text("共 \(entries.count) 篇手记").font(.subheadline)
                        }
                        Spacer()
                        Image(systemName:"arrow.right")
                    }.padding(22).background(pine,in:RoundedRectangle(cornerRadius:12)).foregroundStyle(.white)
                }.accessibilityIdentifier("openTimeline")
                Text("最近事件").font(.headline)
                if entries.isEmpty { Text("进入时间线，点右下角加号添加事件。").foregroundStyle(.secondary) }
                ForEach(Array(entries.prefix(5))) { entry in
                    NavigationLink {
                        Detail(entry:entry,reveal:reveal)
                    } label: {
                        HStack {
                            VStack(alignment:.leading,spacing:4) {
                                Text(entry.title).font(.headline)
                                Text(entry.date,style:.date).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName:"chevron.right").font(.caption).foregroundStyle(.secondary)
                        }.contentShape(Rectangle())
                    }.buttonStyle(.plain)
                    Divider()
                }
            }.padding(22).frame(maxWidth:.infinity,alignment:.leading)
        }.background(paper)
    }
    var calendarGrid: some View {
        let start = cal.dateInterval(of:.month,for:month)!.start
        let offset = cal.component(.weekday,from:start)-1
        let count = cal.range(of:.day,in:.month,for:start)!.count
        return LazyVGrid(columns:Array(repeating:GridItem(.flexible()),count:7)) {
            ForEach(Array("日一二三四五六"),id:\.self) { Text(String($0)).font(.caption) }
            ForEach(0..<(count+offset),id:\.self) { index in
                if index < offset { Color.clear } else {
                    let date = cal.date(byAdding:.day,value:index-offset,to:start)!
                    Button { day = date } label: {
                        VStack { Text("\(index-offset+1)"); Circle().fill(monthly.contains { cal.isDate($0.date,inSameDayAs:date) } ? pine : .clear).frame(width:5,height:5) }
                    }.background(day.map { cal.isDate($0,inSameDayAs:date) } == true ? pine.opacity(0.15) : .clear)
                }
            }
        }.padding(.bottom)
    }
}
