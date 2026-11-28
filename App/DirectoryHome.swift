import SwiftUI

private struct DirectoryPalette {
    let dark: Bool
    private func gray(_ darkValue: Int,_ lightValue: Int)->Color {
        let rgb = dark ? darkValue : lightValue
        return Color(red:Double(rgb >> 16)/255,green:Double(rgb >> 8 & 255)/255,blue:Double(rgb & 255)/255)
    }
    var background:Color { dark ? .black:.white }
    var card:Color { gray(0x1C1C1E,0xF2F2F7) }
    var pill:Color { gray(0x2C2C2E,0xE3E3E8) }
    var secondary:Color { gray(0x8E8E93,0x646469) }
    var blue:Color { gray(0x0A84FF,0x005BBB) }
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
        let tint:Color
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
        let definitions:[(StateTag?,String,String,Color)]=[
            (nil,"全部记录","point.3.connected.trianglepath.dotted",.indigo),
            (.open,"未完成","circle.dotted",.orange),
            (.paused,"暂时挂起","pause.fill",.purple),
            (.done,"已完成","checkmark",.teal)]
        return definitions.compactMap { scope,title,icon,tint in
            let named=title.localizedCaseInsensitiveContains(term)
            let items=all.filter { item in
                (scope==nil || item.status==scope) && (term.isEmpty || named || [item.title,item.body,item.place].contains{$0.localizedCaseInsensitiveContains(term)})
            }
            guard term.isEmpty || named || !items.isEmpty else{return nil}
            return GroupRow(scope:scope,title:title,icon:icon,tint:tint,records:items,query:named ? "":term)
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
                            .frame(width:36,height:36).background(colors.pill,in:Circle())
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
                                    Image(systemName:row.icon).font(.title3.weight(.semibold)).foregroundStyle(.white)
                                        .frame(width:48,height:48).background(row.tint.gradient,in:RoundedRectangle(cornerRadius:12,style:.continuous))
                                    VStack(alignment:.leading,spacing:3){
                                        Text(row.title).font(.body.weight(.semibold)).lineLimit(1)
                                        Text(row.metadata).font(.footnote).foregroundStyle(colors.secondary)
                                    }.frame(maxWidth:.infinity,alignment:.leading)
                                    Text("进入").font(.system(size:14,weight:.semibold)).foregroundStyle(colors.blue)
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
                .foregroundStyle(voice.running ? colors.blue:colors.secondary)
                .accessibilityLabel(voice.running ? "停止听写":"语音搜索")
            }.padding(.leading,14).padding(.trailing,3).frame(minHeight:44)
                .background(.ultraThinMaterial,in:Capsule())
                .background(colors.card.opacity(0.85),in:Capsule())
                .overlay(Capsule().strokeBorder(Color.primary.opacity(0.14),lineWidth:0.5))
                .padding(.horizontal,16).padding(.vertical,8)
        }
        .background(colors.background.ignoresSafeArea()).foregroundStyle(Color.primary).tint(colors.blue)
        .onDisappear{voice.stop()}
        .onChange(of:phase){_,new in if new != .active && voice.recording {voice.stop()}}
        .alert("语音搜索",isPresented:Binding(get:{!voice.message.isEmpty},set:{_ in voice.message=""})){Button("好") {}} message:{Text(voice.message)}
    }
}
