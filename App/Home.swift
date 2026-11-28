import SwiftUI
import SwiftData

let accent=Color("JournalAccent")
let paper=Color("JournalPaper")
struct Home:View {
    @Environment(\.modelContext) var context
    @StateObject private var book:Library
    init(book:Library?=nil){
        _book=StateObject(wrappedValue:book ?? Library(root:CommandLine.arguments.contains("--ui-test") ? URL.temporaryDirectory.appending(path:UUID().uuidString):URL.applicationSupportDirectory.appending(path:"JournalV2")))
    }
    @StateObject private var sync=SyncController()
    @State private var query=""
    @State private var scope:StateTag?
    @AppStorage("appearance") private var appearance = "system"
    @State private var opened = false
    @State private var search=false
    @State private var settings=false
    @State private var create=false
    @State private var importing=false
    @State private var selected:Moment?
    @State private var asset:Attachment?
    @Environment(\.scenePhase) var phase
    @ScaledMetric(relativeTo:.caption) var column:CGFloat=62
    var shown:[Moment] { book.items.filter { !$0.deleted && (scope==nil || scope==$0.status) && (query.isEmpty || [$0.title,$0.body,$0.place].contains { $0.localizedCaseInsensitiveContains(query) }) } }
    var body:some View {
        NavigationStack {
            DirectoryHome(book:book, settings:{ settings=true }) { filter, keyword in
                scope=filter
                query=keyword
                search = !keyword.isEmpty
                opened=true
            }
            .navigationDestination(isPresented:$opened){ timeline }
        }
            .sheet(isPresented:$create){Composer(initial:nil,book:book)}
            .sheet(item:$selected){item in Detail(item:item,book:book)}
            .sheet(item:$asset){Viewer(asset:$0,dir:book.media)}
            .sheet(isPresented:$settings,onDismiss:{importing=false}){Settings(book:book,sync:sync,importOnOpen:importing)}
            .alert("操作未完成",isPresented:Binding(get:{!book.error.isEmpty},set:{_ in book.error=""})){Button("好") {}} message:{Text(book.error)}
        .preferredColorScheme(appearance=="dark" ? .dark : appearance=="light" ? .light:nil)
        .tint(accent).task{
            await book.start(context)
            #if DEBUG
            if CommandLine.arguments.contains("--preview-data"),CommandLine.arguments.contains("--ui-test"),book.items.isEmpty {
                do{try book.replace(await Samples.make(in:book.media))}catch{book.error=error.localizedDescription}
            }
            #endif
            sync.schedule(book)
        }
        .onChange(of:book.items){_,_ in sync.schedule(book)}
        .onChange(of:phase){_,new in if new == .active {sync.schedule(book)} }
    }
    private var timeline:some View {
            VStack(spacing:0) {
                HStack {
                    Text("我的时间线").font(.title2.bold())
                    Spacer()
                    Button { search.toggle(); if !search { query="" } } label:{Image(systemName:"magnifyingglass")}.accessibilityLabel("搜索")
                    Menu { Button("全部状态"){scope=nil};ForEach(StateTag.allCases,id:\.self){ s in Button(s.rawValue){scope=s} } } label:{Image(systemName:scope==nil ? "line.3.horizontal.decrease.circle":"line.3.horizontal.decrease.circle.fill")}.accessibilityLabel("筛选状态")
                    Button {settings=true} label:{Image(systemName:"gearshape")}.accessibilityLabel("设置")
                }.buttonStyle(.borderless).padding()
                if search { TextField("搜索标题、正文或地点",text:$query).textFieldStyle(.roundedBorder).padding(.horizontal) }
                if let scope { Button("清除筛选 · "+scope.rawValue){self.scope=nil}.font(.caption).padding(6) }
                Divider()
                if !book.ready { ProgressView("正在读取手记").frame(maxWidth:.infinity,maxHeight:.infinity) }
                else if shown.isEmpty {
                    ContentUnavailableView {
                        Label(book.items.allSatisfy(\.deleted) ? "从此刻开始" : "没有匹配的记录",systemImage:"book.pages")
                    } description:{ Text(book.items.allSatisfy(\.deleted) ? "记下今天做过的事，以及想留下的片刻。" : "试试其他关键词或状态。") } actions:{
                        if book.items.allSatisfy(\.deleted) {
                            Button("写下第一条记录"){create=true}
                            Button("导入已有数据"){importing=true;settings=true}
                        } else { Button("清除条件"){query="";scope=nil} }
                    }
                } else {
                    let rows=shown
                    ScrollView {
                        LazyVStack(spacing:0) {
                            ForEach(timelineRows(rows)) { row in
                                let index=row.index,item=row.item
                                let first=index==0 || !Calendar.current.isDate(rows[index-1].date,inSameDayAs:item.date)
                                TimelineRow(item:item,first:first,firstRow:index==0,lastRow:index==rows.count-1,
                                            nextDay:index+1<rows.count && !Calendar.current.isDate(rows[index+1].date,inSameDayAs:item.date),
                                            column:column,dir:book.media,open:{selected=item},preview:{asset=$0},
                                            change:{ state in book.change(item){$0.status=state} })
                            }
                        }.padding(.horizontal,14).padding(.top,20).padding(.bottom,90)
                    }
                }
            }.background(paper).overlay(alignment:.bottomTrailing) {
                if book.ready { Button {create=true} label:{Image(systemName:"plus").font(.title2).frame(width:52,height:52).background(accent,in:Circle()).foregroundStyle(paper)}.accessibilityLabel("添加记录").padding() }
            }
    }
}
struct RowIdentity:Identifiable {
    let id:UUID
    let index:Int
    let item:Moment
}
func timelineRows(_ items:[Moment])->[RowIdentity]{
    let counts=Dictionary(grouping:items,by:\.record)
    return items.enumerated().map { offset,item in
        RowIdentity(id:counts[item.record]?.count==1 ? item.record:item.id,index:offset,item:item)
    }
}
struct TimelineRow:View {
    let item:Moment
    let first:Bool, firstRow:Bool,lastRow:Bool,nextDay:Bool
    let column:CGFloat,dir:URL
    let open:()->Void,preview:(Attachment)->Void,change:(StateTag)->Void
    @ScaledMetric(relativeTo:.headline) var axis:CGFloat=12
    var body:some View {
        HStack(alignment:.top,spacing:0) {
            VStack(alignment:.trailing,spacing:3) {
                Text(item.date,format:.dateTime.hour(.twoDigits(amPM:.omitted)).minute()).font(.subheadline.weight(.medium)).monospacedDigit()
                if first {
                    if !Calendar.current.isDate(item.date,equalTo:Date(),toGranularity:.year){Text(item.date,format:.dateTime.year())}
                    Text(item.date,format:.dateTime.month().day())
                    Text(item.date,format:.dateTime.weekday(.abbreviated))
                }
            }.font(.caption).foregroundStyle(.secondary).frame(width:min(column,105),alignment:.trailing)
            Color.clear.frame(width:22)
            VStack(alignment:.leading,spacing:7) {
                ViewThatFits(in:.horizontal) {
                    HStack(alignment:.firstTextBaseline){title.fixedSize();status.fixedSize()}
                    VStack(alignment:.leading,spacing:5){title;status}
                }
                if !item.title.isEmpty && !item.body.isEmpty { Button(action:open){Text(item.body).font(.body).multilineTextAlignment(.leading)}.buttonStyle(JournalPress()) }
                if !item.media.isEmpty { Gallery(media:item.media,dir:dir,preview:preview) }
            }.frame(maxWidth:.infinity,alignment:.leading)
        }.padding(.bottom,lastRow ? 0 : (nextDay ? 32:16))
        .background(alignment:.topLeading){
            GeometryReader { g in
                Path { p in
                    let x=min(column,105)+11
                    p.move(to:CGPoint(x:x,y:firstRow ? axis:0));p.addLine(to:CGPoint(x:x,y:lastRow ? axis:g.size.height))
                }.stroke(Color("JournalRule"),lineWidth:1)
                Circle().fill(accent).frame(width:7,height:7).position(x:min(column,105)+11,y:axis)
            }
        }
    }
    var title:some View { Button(action:open){Text(item.title.isEmpty ? item.body:item.title).font(item.title.isEmpty ? .body:.headline).multilineTextAlignment(.leading)}.buttonStyle(JournalPress()) }
    var status:some View { Menu { ForEach(StateTag.allCases,id:\.self){s in Button {change(s)} label:{Label(s.rawValue,systemImage:s.icon)} } } label:{Label(item.status.rawValue,systemImage:item.status.icon).font(.caption).foregroundStyle(accent)} }
}
struct Gallery:View {
    let media:[Attachment],dir:URL,preview:(Attachment)->Void
    var body:some View {
        if media.count==1,let a=media.first {Button {preview(a)} label:{Tile(asset:a,dir:dir).aspectRatio(CGFloat(a.ratio),contentMode:.fit)}.buttonStyle(JournalPress())}
        else { LazyVGrid(columns:[GridItem(.adaptive(minimum:76))],spacing:5){ForEach(media){a in Button {preview(a)} label:{Tile(asset:a,dir:dir).aspectRatio(1,contentMode:.fit)}.buttonStyle(JournalPress())}} }
    }
}

struct JournalPress:ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration:Configuration)->some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.72:1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985:1)
    }
}
