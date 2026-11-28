import SwiftUI

private struct DirectoryPalette {
    let dark: Bool
    private func gray(_ darkValue: Int,_ lightValue: Int)->Color {
        let rgb = dark ? darkValue : lightValue
        return Color(red:Double(rgb >> 16)/255,green:Double(rgb >> 8 & 255)/255,blue:Double(rgb & 255)/255)
    }
    var background:Color { dark ? .black:.white }
    var card:Color { gray(0x1A1A1A,0xF3F3F3) }
    var pill:Color { gray(0x2D2D2D,0xE7E7E7) }
    var secondary:Color { gray(0xA1A1A1,0x626262) }
    var foreground:Color { dark ? .white:.black }
}
private struct CollectionPress:ButtonStyle {
    @Environment(\.accessibilityReduceMotion) var reduced
    func makeBody(configuration:Configuration)->some View {
        configuration.label
            .brightness(configuration.isPressed ? 0.055:0)
            .scaleEffect(configuration.isPressed && !reduced ? 0.98:1)
            .animation(reduced ? nil:.easeOut(duration:0.12),value:configuration.isPressed)
    }
}
struct DirectoryHome:View {
    @ObservedObject var book:Library
    let settings:()->Void
    let enter:(StateTag?,String)->Void
    @Environment(\.colorScheme) private var scheme
    @Environment(\.scenePhase) private var phase
    @FocusState private var focused:Bool
    @State private var keyword=""
    @StateObject private var voice=SearchDictation()
    private var colors:DirectoryPalette { DirectoryPalette(dark:scheme == .dark) }
    private var records:[Moment] { book.items.filter{!$0.deleted} }
    private struct GroupRow:Identifiable {
        let scope:StateTag?
        let title:String
        let icon:String
        let records:[Moment]
        let query:String
        var id:String {scope?.rawValue ?? "all"}
        var metadata:String {
            guard let first=records.first,let last=records.last else{return "0 个节点"}
            let cal=Calendar.current
            let days=(cal.dateComponents([.day],from:cal.startOfDay(for:last.date),to:cal.startOfDay(for:first.date)).day ?? 0)+1
            return "\(records.count) 个节点 · 跨度 \(days) 天"
        }
    }
    private var groups:[GroupRow] {
        let all=records,term=keyword.trimmingCharacters(in:.whitespacesAndNewlines)
        let definitions:[(StateTag?,String,String)]=[
            (nil,"全部记录","point.3.connected.trianglepath.dotted"),
            (.open,"未完成","circle.dotted"),
            (.paused,"暂时挂起","pause.fill"),
            (.done,"已完成","checkmark")]
        return definitions.compactMap { scope,title,icon in
            let named=title.localizedCaseInsensitiveContains(term)
            let items=all.filter { item in
                (scope==nil || item.status==scope) && (term.isEmpty || named || [item.title,item.body,item.place].contains{$0.localizedCaseInsensitiveContains(term)})
            }
            guard term.isEmpty || named || !items.isEmpty else{return nil}
            return GroupRow(scope:scope,title:title,icon:icon,records:items,query:named ? "":term)
        }
    }
    var body:some View {
        ScrollView {
            VStack(alignment:.leading,spacing:0) {
                HStack {
                    Text("时间线").font(.largeTitle.bold())
                    Spacer()
                    Button { voice.stop(); focused=false;settings() } label:{
                        Text("锦").font(.headline).foregroundStyle(.primary)
                            .frame(width:36,height:36).modifier(DirectoryGlass())
                            .frame(width:44,height:44)
                    }.accessibilityLabel("个人设置")
                }.padding(.bottom,22)
                Text("我的时间线").font(.subheadline.weight(.medium)).foregroundStyle(colors.secondary)
                    .padding(.leading,12).padding(.bottom,12)
                if !book.ready { ProgressView("正在读取手记") }
                else if groups.isEmpty { ContentUnavailableView("没有匹配的时间线",systemImage:"magnifyingglass") }
                else {
                    LazyVStack(spacing:12){
                        ForEach(groups){ row in
                            Button {
                                voice.stop();focused=false;enter(row.scope,row.query)
                            } label:{
                                HStack(spacing:12){
                                    Image(systemName:row.icon).font(.title3.weight(.semibold)).foregroundStyle(colors.foreground)
                                        .frame(width:48,height:48).background(colors.pill.gradient,in:RoundedRectangle(cornerRadius:12,style:.continuous))
                                    VStack(alignment:.leading,spacing:3){
                                        Text(row.title).font(.body.weight(.semibold)).lineLimit(1)
                                        Text(row.metadata).font(.footnote).foregroundStyle(colors.secondary)
                                    }.frame(maxWidth:.infinity,alignment:.leading)
                                    Text("进入").font(.system(size:14,weight:.semibold)).foregroundStyle(colors.foreground)
                                        .padding(.vertical,6).padding(.horizontal,16).background(colors.pill,in:Capsule()).fixedSize()
                                }.padding(.horizontal,16).padding(.vertical,12)
                                    .background(colors.card,in:RoundedRectangle(cornerRadius:16,style:.continuous))
                                    .contentShape(RoundedRectangle(cornerRadius:16,style:.continuous))
                            }.buttonStyle(CollectionPress()).accessibilityIdentifier("collection."+row.id)
                        }
                    }
                }
            }.padding(.horizontal,16).padding(.top,12).frame(maxWidth:.infinity,alignment:.leading)
        }.scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge:.bottom){
            HStack(spacing:9){
                Image(systemName:"magnifyingglass").foregroundStyle(colors.secondary)
                TextField("搜索",text:$keyword,prompt:Text("搜索").foregroundColor(colors.secondary))
                    .focused($focused).submitLabel(.search)
                if !keyword.isEmpty { Button {voice.stop();keyword=""} label:{Image(systemName:"xmark.circle.fill")}.accessibilityLabel("清除搜索") }
                Button {
                    if voice.running {voice.stop()} else{focused=false;voice.start{keyword=$0}}
                } label:{ Image(systemName:voice.running ? "stop.circle.fill":"mic.fill").frame(width:36,height:44) }
                .foregroundStyle(voice.running ? colors.foreground:colors.secondary)
                .accessibilityLabel(voice.running ? "停止听写":"语音搜索")
            }.padding(.leading,14).padding(.trailing,3).frame(minHeight:44)
                .modifier(DirectoryGlass())
                .padding(.horizontal,16).padding(.vertical,8)
        }
        .background(colors.background.ignoresSafeArea()).foregroundStyle(Color.primary).tint(colors.foreground)
        .onDisappear{voice.stop()}
        .onChange(of:phase){_,new in if new != .active && voice.recording {voice.stop()}}
        .alert("语音搜索",isPresented:Binding(get:{!voice.message.isEmpty},set:{_ in voice.message=""})){Button("好") {}} message:{Text(voice.message)}
    }
}

private struct DirectoryGlass: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular.interactive(), in: .capsule)
        } else {
            content.background(.regularMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(Color.primary.opacity(0.15), lineWidth: 0.5))
        }
    }
}
