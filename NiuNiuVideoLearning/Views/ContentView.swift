//
//  ContentView.swift
//  NiuNiuVideoLearning
//
//  Created by Chengzhi 张 on 2025/8/22.
//

import SwiftUI

struct ContentView: View {
    @Environment(\.openWindow) private var openWindow
    
    @State private var showAddCollection = false
    @State private var showAddVideo = false
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Collections.date, ascending: false)],
        animation: .default
    )
    private var collections: FetchedResults<Collections>
    
    var body: some View {
        NavigationSplitView {
            ScrollView{
                VStack(spacing: 8){
                    ForEach(collections.indices, id: \.self) { index in
                        CustomDisclosureRow(
                            title: collections[index].name ?? "未命名",
                            color: tags[Int(collections[index].tag)].color
                        )
                    }
                }
            }
            .padding(.horizontal)
        } detail: {
            Text("右侧内容区域")
        }
        .navigationTitle("牛牛看课")
        .toolbar {
            ToolbarItem(placement: .navigation) {
                HStack{
                    Button(action: {
                        showAddCollection = true
                    }) {
                        Image(systemName: "folder.badge.plus")
                    }
                    .help("新建课程")
                    .sheet(isPresented: $showAddCollection){
                        AddCollectionView()
                    }
                    
                    Button(action: {
                        showAddVideo = true
                    }) {
                        Image(systemName: "video.badge.plus")
                    }
                    .help("导入课程视频")
                    .sheet(isPresented: $showAddVideo){
                        AddVideoView()
                    }
                }
            }
        }
    }
}

struct CustomDisclosureRow: View {
    let title: String
    let color: Color
    @State private var expanded = false

    var body: some View {
        VStack {
            HStack(spacing: 5) {
                Image(systemName: "tag")
                    .foregroundStyle(color)

                Text(title)

                Spacer()

                Button(action: {
                    withAnimation {
                        expanded.toggle()
                    }
                }){
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(expanded ? 90 : 0))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

#Preview {
    ContentView()
}
