import SwiftUI
import PhotosUI
import CryptoKit

enum TopicDesign {
    static func icon(_ topic:String)->String {
        switch topic {case "独立开发日志":return "mark-build";case "海岸散步":return "mark-coast";default:return "mark-life"}
    }
    static var examples:[Moment] {
        let specs:[(String,String,String,StateTag)]=[
            ("独立开发日志","画出第一版首页","删掉重复的入口，给手记本身多留一点空间。",.done),
            ("独立开发日志","打磨离线体验","在地铁上记了一段话，准备到站后检查保存结果。",.open),
            ("独立开发日志","搁置桌面小组件","先把手机上的阅读体验做好。",.paused),
            ("海岸散步","走到白城沙滩","退潮后沿着潮线慢慢走，捡到一枚有细纹的贝壳。",.done),
            ("海岸散步","再去一次灯塔","想在傍晚同一个位置拍下涨潮后的样子。",.open)]
        return specs.enumerated().map { index,spec in
            var m=Moment()
            let key=UUID(uuidString:String(format:"9239AAAD-FD82-4774-91B2-%012d",index+1))!
            m.id=key;m.record=key;m.topic=spec.0;m.title=spec.1;m.body=spec.2;m.status=spec.3
            m.date=Date(timeIntervalSince1970:1795309200+Double(index)*86400);m.created=m.date;m.modified=m.date
            return m
        }
    }
}
struct TopicBanner:View {
    let title:String,root:URL
    @State private var photo:UIImage?
    @State private var selected:PhotosPickerItem?
    @State private var error=""
    private var file:URL {
        let key=SHA256.hash(data:Data(title.utf8)).map{String(format:"%02x",$0)}.joined()
        return root.appending(path:"cover-"+key+".jpg")
    }
    var body:some View {
        ZStack(alignment:.bottomLeading){
            GeometryReader{g in
                Image(uiImage:photo ?? UIImage(named:title=="海岸散步" ? "sample-sea":"sample-cafe") ?? UIImage())
                    .resizable().scaledToFill().frame(width:g.size.width,height:g.size.height).clipped()
            }
            LinearGradient(colors:[.clear,.black.opacity(0.78)],startPoint:.top,endPoint:.bottom)
            HStack(alignment:.bottom){
                VStack(alignment:.leading,spacing:8){
                    Image(TopicDesign.icon(title)).resizable().frame(width:48,height:48).clipShape(RoundedRectangle(cornerRadius:12))
                    Text(title).font(.title2.bold()).foregroundStyle(.white)
                }
                Spacer()
                PhotosPicker(selection:$selected,matching:.images){Image(systemName:"photo.badge.plus").padding(10).background(.black.opacity(0.5),in:Circle()).foregroundStyle(.white)}.accessibilityLabel("更换封面")
            }.padding(16)
        }.frame(height:146).task{photo=UIImage(contentsOfFile:file.path)}
        .onChange(of:selected){_,item in Task{do{
            guard let data=try await item?.loadTransferable(type:Data.self),let full=UIImage(data:data),let thumb=await full.byPreparingThumbnail(ofSize:CGSize(width:1400,height:1400)),let jpeg=thumb.jpegData(compressionQuality:0.85) else{throw Problem("无法读取封面图片。")}
            try jpeg.write(to:file,options:.atomic);photo=thumb
        }catch{self.error=error.localizedDescription}}}
        .alert("更换封面失败",isPresented:Binding(get:{!error.isEmpty},set:{_ in error=""})){Button("好"){} } message:{Text(error)}
    }
}
