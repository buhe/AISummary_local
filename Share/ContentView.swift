//
//  ContentView.swift
//  Share
//
//  Created by 顾艳华 on 2023/7/3.
//

import SwiftUI
import CoreData
import SwiftUIX

struct ContentView: View {
    @State var search = ""
    @State var tabIndex = 0
    @State var showSetting = false
    @State var showHelp = false
    @State var showPro = false
    @State var showPlus = false
    @State var firstLaunch = true
    
    var body: some View {
        NavigationStack {
            VStack{
                SearchBar(text: $search)
                    .padding(.horizontal)
                TabBar(tabIndex: $tabIndex).padding(.horizontal, 26)
                switch tabIndex {
                case 0:
                    Sum(fav: .all, search: search)
                case 1:
                    Sum(fav: .id(true), search: search)
                default:
                    EmptyView()
                }
            }
            .toolbar {
                ToolbarItem() {
                    Button{
                        showPlus = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem() {
                    Button{
                        showHelp = true
                    } label: {
                        Image(systemName: "questionmark.circle")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button{
                        showSetting = true
                    } label: {
                        Image(systemName: "gear")
                    }
                }
            }
            .sheet(isPresented: $showSetting){
                Setting()
            }
            .sheet(isPresented: $showHelp){
                NavContainer{
                    showHelp = false
                }
            }
            .sheet(isPresented: $showPro){
                ProView(scheme: true){}
            }
            .sheet(isPresented: $showPlus){
                PlusView()
            }
            .onOpenURL{
                url in
                showPro = true
            }
        
        }
    }
}

struct TabBar: View {
    @Binding var tabIndex: Int
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 20) {
                TabBarButton(text: "All", isSelected: .constant(tabIndex == 0))
                    .onTapGesture { onButtonTapped(index: 0) }
                TabBarButton(text: "Favorites", isSelected: .constant(tabIndex == 1))
                    .onTapGesture { onButtonTapped(index: 1) }
            }
        }
//        .border(width: 1, edges: [.bottom], color: .systemGray)
    }
    
    private func onButtonTapped(index: Int) {
        withAnimation { tabIndex = index }
    }
}

struct TabBarButton: View {
    let text: String
    @Binding var isSelected: Bool
    var body: some View {
        Text(text)
            .fontWeight(isSelected ? .heavy : .regular)
            .font(.custom("Avenir", size: 16))
            .padding(.vertical, 10)
//            .border(width: isSelected ? 2 : 1, edges: [.bottom], color: .systemGray)
    }
}
