import AVFoundation
import Speech

@MainActor final class SearchDictation:ObservableObject {
    @Published private(set) var running=false
    @Published var message=""
    private let engine=AVAudioEngine()
    private var task:SFSpeechRecognitionTask?
    private var request:SFSpeechAudioBufferRecognitionRequest?
    private var generation=UUID()
    private var tapped=false
    private var activated=false
    var recording:Bool {engine.isRunning}

    func start(update:@escaping (String)->Void) {
        guard !running else{return}
        running=true
        let token=UUID()
        generation=token
        Task {
            let authorization=await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { continuation.resume(returning:$0) }
            }
            guard generation==token else{return}
            guard authorization == .authorized else{fail("请在系统设置中允许语音识别，也可以用键盘搜索。");return}
            let allowed=await AVAudioApplication.requestRecordPermission()
            guard generation==token else{return}
            guard allowed else{fail("请在系统设置中允许使用麦克风。");return}
            guard let recognizer=SFSpeechRecognizer(locale:Locale(identifier:"zh-CN")),recognizer.isAvailable else{
                fail("当前无法使用中文听写，请稍后重试。");return
            }
            do{
                let session=AVAudioSession.sharedInstance()
                try session.setCategory(.record,mode:.measurement)
                try session.setActive(true)
                activated=true
                let input=engine.inputNode,format=input.outputFormat(forBus:0)
                guard format.sampleRate>0,format.channelCount>0 else{fail("未检测到可用麦克风。");return}
                let buffer=SFSpeechAudioBufferRecognitionRequest()
                buffer.shouldReportPartialResults=true
                buffer.requiresOnDeviceRecognition=recognizer.supportsOnDeviceRecognition
                request=buffer
                Self.attach(input,format:format,to:buffer)
                tapped=true
                engine.prepare();try engine.start()
                task=recognizer.recognitionTask(with:buffer){ [weak self] result,error in
                    let text=result?.bestTranscription.formattedString,final=result?.isFinal==true
                    Task { @MainActor in
                        guard let self,self.generation==token else{return}
                        if let text{update(text)}
                        if final{self.stop()}else if error != nil{self.fail("听写已中断，请重试或使用键盘。")}
                    }
                }
            }catch{fail("无法启动录音，请检查麦克风后重试。")}
        }
    }
    nonisolated private static func attach(_ input:AVAudioInputNode,format:AVAudioFormat,to buffer:SFSpeechAudioBufferRecognitionRequest){
        input.installTap(onBus:0,bufferSize:1024,format:format){audio,_ in buffer.append(audio)}
    }
    private func fail(_ reason:String){stop();message=reason}
    func stop(){
        generation=UUID()
        if engine.isRunning{engine.stop()}
        if tapped{engine.inputNode.removeTap(onBus:0);tapped=false}
        request?.endAudio();task?.cancel();task=nil;request=nil
        if activated{try? AVAudioSession.sharedInstance().setActive(false,options:.notifyOthersOnDeactivation);activated=false}
        running=false
    }
}
