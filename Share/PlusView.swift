//
//  PlusView.swift
//  Share
//
//  Created by 顾艳华 on 2/1/24.
//

import SwiftUI
import UIKit
import Social
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

struct PlusView: View {
//    @AppStorage(wrappedValue: NSLocale.preferredLanguages.first!, "lang", store: UserDefaults.shared) var lang: String
    
    
    
    let screenWidth = UIScreen.main.bounds.width
    
    @State var requested = false
    @State var url = ""
    @State var image = ""
    @State var summary = "Video summary..."
    var body: some View {
        VStack(alignment: .leading) {
            TextField("Please enter video link", text: $url, onCommit: add)
                .padding(.vertical)

            Button {
                add()
            } label: {
                Text("Summarize")
            }.buttonStyle(.bordered)
            AsyncImage(url: URL(string: image)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } placeholder: {
                RoundedRectangle(cornerRadius: 10)
                    .foregroundColor(.gray)
                    .opacity(0.25)
            }
            .frame(width: screenWidth - 22 , height: screenWidth * 2 / 3)
            Text(summary)
                .padding(.vertical)
            Spacer()
        }.padding(.horizontal)
    }
    
    fileprivate func save(_ s: (String, String)?) {
        if let s = s {
            summary = s.0
            image = s.1
        }
    }
    
    func add() {
        if url.contains("watch") && url.contains("youtube") {
            if !self.requested {
                self.requested = true
                Task {
                    await self.parseURL2(url:url, callback: {
                        let s = try! await self.sum(video_id: $0)
                        save(s)
                    })
                }
            }
        } else if url.contains("youtu.be") {
            // parse https://youtu.be/r25tAO1HaAI
            if !self.requested {
                self.requested = true
                Task {
                    await self.parseURL(url:url, callback: {
                        let s = try! await self.sum(video_id: $0)
                        save(s)
                    })
                }
            }
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
    func sum(video_id: String) async throws -> (String, String)? {
        var p = """
Here are the subtitles of a YouTube video : {youtube} , please summarize the main content,the word count should be no less than 100 words
"""
//        switch lang {
//        case let x where x.hasPrefix("zh-Hans"):
//            p = """
//以下是 youtube 一个视频的字幕 : {youtube} , 请总结主要内容, 要求在100个字以内.
//"""
//        case let x where x.hasPrefix("zh-Hant"):
//            p = """
//以下是 youtube 一個視頻的字幕 ： {youtube} ， 請總結主要內容， 要求在100個字以內.
//"""
//        case let x where x.hasPrefix("en"):
//            p = """
//Here are the subtitles of a YouTube video : {youtube} , please summarize the main content, within 100 words.
//"""
//        case let x where x.hasPrefix("fr"):
//            p = """
//Voici les sous-titres d’une vidéo YouTube : {youtube} , veuillez résumer le contenu principal, en 100 mots.
//"""
//        case let x where x.hasPrefix("ja"):
//            p = """
//YouTubeビデオの字幕は次のとおりです:{youtube} 、メインコンテンツを100語以内に要約してください。
//"""
//        case let x where x.hasPrefix("ko"):
//            p = """
//YouTube 동영상의 자막은 다음과 같습니다 : {youtube} , 주요 내용을 100단어 이내로 요약해 주세요.
//"""
//        case let x where x.hasPrefix("es"):
//            p = """
//Aquí están los subtítulos de un video de YouTube: {youtube} , resuma el contenido principal, dentro de 100 palabras.
//"""
//        case let x where x.hasPrefix("it"):
//            p = """
//Ecco i sottotitoli di un video di YouTube: {youtube} , si prega di riassumere il contenuto principale, entro 100 parole.
//"""
//        case let x where x.hasPrefix("de"):
//            p = """
//Hier sind die Untertitel eines YouTube-Videos: {youtube} , bitte fassen Sie den Hauptinhalt innerhalb von 100 Wörtern zusammen.
//"""
//        default:
//            p = ""
//        }
//        print(lang)
        let loader = YoutubeLoader(video_id: video_id, language: "en")
        let loading =  LoadingState(loading: true, text: "Fetching Youtube subtitles.")
        NotificationCenter.default.post(name: Notification.Name("Loading"), object: loading)
        let doc = await loader.load()
        
        if doc.isEmpty {
            let payload = VideoInfo(title: "", summarize: "", description: "", thumbnail: "", url: "", successed: false, cause: .NoSubtitle, id: "")
            NotificationCenter.default.post(name: Notification.Name("Summarize"), object: payload)
            
            let loading =  LoadingState(loading: false, text: "")
            NotificationCenter.default.post(name: Notification.Name("Loading"), object: loading)
           return nil
        } else {
            let prompt = PromptTemplate(input_variables: ["youtube"],partial_variable: [:], template: p)
            let request = prompt.format(args: ["youtube":String(doc.first!.page_content.prefix(2000))])
            let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
            
            let httpClient = HTTPClient(eventLoopGroupProvider: .shared(eventLoopGroup))
            defer {
                // it's important to shutdown the httpClient after all requests are done, even if one failed. See: https://github.com/swift-server/async-http-client
                try? httpClient.syncShutdown()
            }
            if let envPath = Bundle.main.path(forResource: "llama-2-7b-chat.Q8_0", ofType: "txt") {
                let llm = Local(inference: .LLama_gguf, modelPath: envPath)
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
                return (summary, info!.thumbnail)
//                if hasTry {
//                    tryout -= 1
//                    hasTry = false
//                }
            } else {
                print("⚠️ loss model")
                return nil
            }
        }
    }
}

#Preview {
    PlusView()
}
