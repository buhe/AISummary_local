//
//  ShareViewController.swift
//  ShareExt
//
//  Created by 顾艳华 on 2023/7/3.
//

import UIKit
import Social
import SwiftUI
import LangChain
import AsyncHTTPClient
import Foundation
import NIOPosix
import StoreKit
import CoreData
import IAP
import UIx

enum Cause {
    case NoSubtitle
    case Expired
    case Success
    case NotYoutube
    case SuccessDone
}
struct VideoInfo {
    let title: String
    let summarize: String
    let description: String
    let thumbnail: String
    let url: String
    let successed: Bool
    let cause: Cause
    let id: String
}
struct LoadingState {
    let loading: Bool
    let text: String
}
@available(iOSApplicationExtension, unavailable)
class ShareViewController: UIViewController {
    var requested = false
    let persistenceController = PersistenceController.shared
    @AppStorage(wrappedValue: NSLocale.preferredLanguages.first!, "lang", store: UserDefaults.shared) var lang: String
    
    @AppStorage(wrappedValue: countInit, "tryout", store: UserDefaults.shared) var tryout: Int

    var hasTry = false

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
//        print("lang: \(userDefaults?.object(forKey: "lang") ?? "")")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let sui = SwiftUIView(close: {
            self.extensionContext!.completeRequest(returningItems: nil, completionHandler: nil)
        })
        // Do any additional setup after loading the view.
        let vc  = UIHostingController(rootView: sui)
        self.addChild(vc)
        self.view.addSubview(vc.view)
        vc.didMove(toParent: self)

        vc.view.translatesAutoresizingMaskIntoConstraints = false
        vc.view.heightAnchor.constraint(equalTo: self.view.heightAnchor).isActive = true
        vc.view.leftAnchor.constraint(equalTo: self.view.leftAnchor).isActive = true
        vc.view.rightAnchor.constraint(equalTo: self.view.rightAnchor).isActive = true
        vc.view.centerYAnchor.constraint(equalTo: self.view.centerYAnchor).isActive = true
        vc.view.backgroundColor = UIColor.clear
    
       
    }
    
    fileprivate func hanleExtension() {
        for item in extensionContext!.inputItems as! [NSExtensionItem] {
            if let attachments = item.attachments {
                for itemProvider in attachments {
                    // brower
                    if itemProvider.hasItemConformingToTypeIdentifier("public.url") {
                        itemProvider.loadItem(forTypeIdentifier: "public.url", options: nil, completionHandler: { (item, error) in
                            let url = item as! NSURL
                            // parse https://www.youtube.com/watch?v=c6SSUhsU0A0
                            if url.absoluteString!.contains("watch") && url.absoluteString!.contains("youtube") {
                                if !self.requested {
                                    self.requested = true
                                    Task {
                                        await self.parseURL2(url:url.absoluteString!, callback: {
                                            try! await self.sum(video_id: $0)
                                        })
                                    }
                                }
                            } else if url.absoluteString!.contains("youtu.be") {
                                // parse https://youtu.be/r25tAO1HaAI
                                if !self.requested {
                                    self.requested = true
                                    Task {
                                        await self.parseURL(url:url.absoluteString!, callback: {
                                            try! await self.sum(video_id: $0)
                                        })
                                    }
                                }
                            } else {
                                let payload = VideoInfo(title: "", summarize: "", description: "", thumbnail: "", url: "", successed: false, cause: .NotYoutube, id: "")
                                NotificationCenter.default.post(name: Notification.Name("Summarize"), object: payload)
                            }
                        })
                    }
                    // youtube app
                    if itemProvider.hasItemConformingToTypeIdentifier("public.text") {
                        itemProvider.loadItem(forTypeIdentifier: "public.text", options: nil, completionHandler: { (item, error) in
                            let url = item as! String
                            // https://www.youtube.com/watch?v=c6SSUhsU0A0
                            if url.contains("watch") {
                                if !self.requested {
                                    self.requested = true
                                    Task {
                                        await self.parseURL2(url: url, callback: {
                                            try! await self.sum(video_id: $0)
                                        })
                                    }
                                }
                            }
                        })
                    }
                }
            }
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if IAPCache.five.checkSubscriptionStatus(password: "0d68c1da7f4241e6af9b7df3ae540ce4") {
            hanleExtension()
        } else if tryout > 0 {
            hasTry = true
            hanleExtension()
        }
        else {
            let loading2 =  LoadingState(loading: false, text: "")
            NotificationCenter.default.post(name: Notification.Name("Loading"), object: loading2)
            let payload = VideoInfo(title: "", summarize: "", description: "", thumbnail: "", url: "", successed: false, cause: .Expired, id: "")
            NotificationCenter.default.post(name: Notification.Name("Summarize"), object: payload)
            UIApplication.shared.open(URL(string:"sum://")!)
        }
    }
    func parseURL(url: String, callback: (_ id: String) async -> Void) async {
        let c = URLComponents(string: url)
        if let id = c?.path.replacingOccurrences(of: "/", with: "") {
            await callback(id)
        }
    }
    func parseURL2(url: String, callback: (_ id: String) async -> Void) async {
        let c = URLComponents(string: url)
        if let queryItems = c?.queryItems {
            for item in queryItems {
                if item.name ==  "v" {
                    let video_id = item.value!
                    await callback(video_id)
                }
            }
        }
    }
    func sum(video_id: String) async throws {
        var p = ""
        switch lang {
        case let x where x.hasPrefix("zh-Hans"):
            p = """
以下是 youtube 一个视频的字幕 : {youtube} , 请总结主要内容, 要求在100个字以内.
"""
        case let x where x.hasPrefix("zh-Hant"):
            p = """
以下是 youtube 一個視頻的字幕 ： {youtube} ， 請總結主要內容， 要求在100個字以內.
"""
        case let x where x.hasPrefix("en"):
            p = """
Here are the subtitles of a YouTube video : {youtube} , please summarize the main content, within 100 words.
"""
        case let x where x.hasPrefix("fr"):
            p = """
Voici les sous-titres d’une vidéo YouTube : {youtube} , veuillez résumer le contenu principal, en 100 mots.
"""
        case let x where x.hasPrefix("ja"):
            p = """
YouTubeビデオの字幕は次のとおりです:{youtube} 、メインコンテンツを100語以内に要約してください。
"""
        case let x where x.hasPrefix("ko"):
            p = """
YouTube 동영상의 자막은 다음과 같습니다 : {youtube} , 주요 내용을 100단어 이내로 요약해 주세요.
"""
        case let x where x.hasPrefix("es"):
            p = """
Aquí están los subtítulos de un video de YouTube: {youtube} , resuma el contenido principal, dentro de 100 palabras.
"""
        case let x where x.hasPrefix("it"):
            p = """
Ecco i sottotitoli di un video di YouTube: {youtube} , si prega di riassumere il contenuto principale, entro 100 parole.
"""
        case let x where x.hasPrefix("de"):
            p = """
Hier sind die Untertitel eines YouTube-Videos: {youtube} , bitte fassen Sie den Hauptinhalt innerhalb von 100 Wörtern zusammen.
"""
        default:
            p = ""
        }
        print(lang)
        let loader = YoutubeLoader(video_id: video_id, language: lang)
        let loading =  LoadingState(loading: true, text: "Fetching Youtube subtitles.")
        NotificationCenter.default.post(name: Notification.Name("Loading"), object: loading)
        let doc = await loader.load()
        
        if doc.isEmpty {
            let payload = VideoInfo(title: "", summarize: "", description: "", thumbnail: "", url: "", successed: false, cause: .NoSubtitle, id: "")
            NotificationCenter.default.post(name: Notification.Name("Summarize"), object: payload)
            
            let loading =  LoadingState(loading: false, text: "")
            NotificationCenter.default.post(name: Notification.Name("Loading"), object: loading)
           
        } else {
            let prompt = PromptTemplate(input_variables: ["youtube"],partial_variable: [:], template: p)
            let request = prompt.format(args: ["youtube":String(doc.first!.page_content.prefix(2000))])
            let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
            
            let httpClient = HTTPClient(eventLoopGroupProvider: .shared(eventLoopGroup))
            defer {
                // it's important to shutdown the httpClient after all requests are done, even if one failed. See: https://github.com/swift-server/async-http-client
                try? httpClient.syncShutdown()
            }
            if let envPath = Bundle.main.path(forResource: "Cerebras", ofType: "txt") {
                let llm = Local(inference: .GPT2, modelPath: envPath)
                let reply = await llm.generate(text: request)
                print(reply!.llm_output!)
                let loading =  LoadingState(loading: true, text: "Fetch video info.")
                NotificationCenter.default.post(name: Notification.Name("Loading"), object: loading)
                
                let info = await YoutubeHackClient.info(video_id: video_id, httpClient: httpClient)
                let loading2 =  LoadingState(loading: false, text: "")
                NotificationCenter.default.post(name: Notification.Name("Loading"), object: loading2)
               
                let uuid = UUID()
                let uuidString = uuid.uuidString
                let summary = reply!.llm_output!
//                for try await c in reply!.getGeneration()! {
//                    if let message = c {
//                        let payload = VideoInfo(title: info!.title, summarize: message, description: info!.description, thumbnail: info!.thumbnail, url: "https://www.youtube.com/watch?v=" + video_id, successed: true, cause: .Success,id: uuidString)
//                        summary += message
//                        NotificationCenter.default.post(name: Notification.Name("Summarize"), object: payload)
//                    }
//                }
                let payload = VideoInfo(title: info!.title, summarize: summary, description: info!.description, thumbnail: info!.thumbnail, url: "https://www.youtube.com/watch?v=" + video_id, successed: true, cause: .SuccessDone,id: uuidString)
                print("summarize: \(summary)")
                NotificationCenter.default.post(name: Notification.Name("Summarize"), object: payload)
                if hasTry {
                    tryout -= 1
                    hasTry = false
                }
            } else {
                print("⚠️ loss model")
            }
        }
    }

}
struct SwiftUIView: View {
    @Environment(\.colorScheme) private var colorScheme
    
    @State var text = ""
    @State var loadingText = "Summarize Youtube."
    @State var isLoading: Bool = true
    init(close: @escaping () -> Void) {
        self.close = close
    }
    let close: () -> Void
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 25, style: .continuous)
                .fill(colorScheme == .light ? .white : .gray)
                .shadow(radius: 10)
            VStack {
                HStack {
                    Spacer()
                    Button {
                        close()
                    } label: {
                        Image(systemName: "xmark.circle")
                    }
                    .font(.title)
                    .padding()
                }
                Text("Summarize Youtube")
                    .bold()
                    .font(.title)
                ScrollView {
                    Text(text)
                        .font(.title2)
                }
                .padding([.bottom,.horizontal])
                Spacer()
            
            }
        }
        .circleIndicatorWithSize(when: $isLoading, lineWidth: 5, size: 44, pathColor: .blue, lineColor: .blue, text: loadingText)
        .padding()
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("Loading"))) { msg in
            let payload = msg.object as! LoadingState
            DispatchQueue.main.async {
                loadingText = payload.text
                isLoading = payload.loading
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("Summarize"))) { msg in
            let payload = msg.object as! VideoInfo
            if payload.successed {
//                withAnimation {
                switch payload.cause {
                    case .SuccessDone:
                        DispatchQueue.main.async {
                            text = payload.summarize
                        }
                        addItem(payload: payload)
                    default: break
                }
            } else {
                switch payload.cause {
                    case .NoSubtitle:
                        text = "The video has no subtitles, and the summary fails."
                    case .Expired:
                        text = "You have exceeded the number of trials and are not subscribed."
                    case .NotYoutube:
                        text = "Not a YouTube link"
                    default:
                    // not reachered
                        text = ""
                }
            }
        }
    }
    
    private func addItem(payload: VideoInfo) {
        let viewContext = PersistenceController.shared.container.viewContext
        // 创建一个NSFetchRequest对象来指定查询的实体
        let fetchRequest: NSFetchRequest<Item> = Item.fetchRequest()

        // 创建一个NSPredicate对象来定义查询条件
        let predicate = NSPredicate(format: "uuid == %@", payload.id)

        // 将NSPredicate对象赋值给fetchRequest的predicate属性
        fetchRequest.predicate = predicate

        do {
            let results = try viewContext.fetch(fetchRequest)
            
            if results.isEmpty {
                
                let newItem = Item(context: viewContext)
                newItem.timestamp = Date()
                newItem.summary = payload.summarize
                newItem.title = payload.title
                newItem.url = payload.url
                newItem.desc = payload.description
                newItem.thumbnail = payload.thumbnail
                newItem.fav = false
                newItem.uuid = payload.id
                do {
                    try viewContext.save()
                } catch {
                    // Replace this implementation with code to handle the error appropriately.
                    // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                    let nsError = error as NSError
                    fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
                }
            }
        } catch {
            // 处理错误
            print("Error fetching data: \(error)")
        }
        
        
    }
}
