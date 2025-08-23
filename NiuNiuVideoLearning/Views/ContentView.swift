//
//  ContentView.swift
//  NiuNiuVideoLearning
//
//  Created by Chengzhi 张 on 2025/8/22.
//

import SwiftUI
import UniformTypeIdentifiers

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
                        let col = collections[index]
                        CustomDisclosureRow(
                            title: col.name ?? "未命名",
                            color: tags[Int(col.tag)].color,
                            collection: col
                        )
                        .padding(.vertical, 6)
                        .padding(.horizontal, 8)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
        } detail: {
            Text("右侧内容区域")
        }
        .navigationTitle("牛牛看课")
        .toolbar {
            ToolbarItem(placement: .navigation) {
                HStack{
                    Button(action: { showAddCollection = true }) {
                        Image(systemName: "folder.badge.plus")
                    }
                    .help("新建课程")
                    .sheet(isPresented: $showAddCollection){
                        AddCollectionView()
                    }
                    
                    Button(action: { showAddVideo = true }) {
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

// MARK: - 折叠行（带子列表）
struct CustomDisclosureRow: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    let title: String
    let color: Color
    let collection: Collections
    
    @State private var expanded = false
    @State private var showDeleteConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: {
                withAnimation(.snappy) { expanded.toggle() }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "tag")
                        .foregroundStyle(color)

                    Text(title)
                        .font(.headline)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(expanded ? 90 : 0))
                }
            }
            .buttonStyle(.plain)
            .contextMenu {
                Button("删除当前课程") { showDeleteConfirm = true }
            }
            .alert(
                "确定删除该课程？",
                isPresented: $showDeleteConfirm
            ) {
                Button("取消", role: .cancel) { }
                Button("确认删除", role: .destructive) {
                    deleteCollectionAndVideos(id: collection.id!, context: viewContext)
                }
            } message: {
                Text("这将同时删除该课程下的所有视频，且无法恢复。")
            }
            
            if expanded {
                Divider().opacity(0.4)
                VideosForCollectionView(collectionID: collection.id)
                    .padding(.leading)
            }
        }
    }
}

// MARK: - 子视图：某个 Collection 下的 Videos 实时列表
struct VideosForCollectionView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    // 动态 FetchRequest：根据传入的 collectionID 过滤
    @FetchRequest private var videos: FetchedResults<Videos>
    
    // 状态：文件选择器 & 警告弹窗
    @State private var showFileImporter = false
    @State private var alertMessage: String = ""
    @State private var showAlert = false
    
    // 临时保存：当前“重新链接”的目标 video（以及待处理的 URL）
    @State private var pendingVideo: Videos?
    @State private var pendingURL: URL?
    
    @State private var id = UUID()
    
    init(collectionID: UUID?) {
        if let id = collectionID {
            _videos = FetchRequest(
                entity: Videos.entity(),
                sortDescriptors: [NSSortDescriptor(keyPath: \Videos.date, ascending: false)],
                predicate: NSPredicate(format: "collection == %@", id as CVarArg),
                animation: .default
            )
        } else {
            // 没有 id 的集合，返回空
            _videos = FetchRequest(
                entity: Videos.entity(),
                sortDescriptors: [],
                predicate: NSPredicate(value: false),
                animation: .default
            )
        }
    }
    
    var body: some View {
        if videos.isEmpty {
            HStack(spacing: 6) {
                Image(systemName: "tray")
                    .foregroundStyle(.secondary)
                Text("暂无视频")
                    .foregroundStyle(.secondary)
                    .font(.callout)
                Spacer()
            }
            .padding(.vertical, 6)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(videos) { video in
                    VideoRow(video: video)
                        .contentShape(Rectangle())
                        .contextMenu {
                            Button("重新链接") {
                                pendingVideo = video
                                showFileImporter = true
                            }
                            .disabled(video.exist) // 已存在就不需要重新链接
                            
                            Button("删除当前视频") { deleteVideo(id: video.id!, context: viewContext) }
                        }
                    Divider().opacity(0.15)
                }
            }
            .id(id)
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [.movie, .video],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    handlePickedURL(url)
                case .failure(let error):
                    presentAlert(title: "选择文件失败", message: error.localizedDescription)
                }
            }
            .alert("提示", isPresented: $showAlert) {
                Button("确定", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    /// 统一展示弹窗
    func presentAlert(title: String, message: String) {
        alertMessage = message
        showAlert = true
    }
    
    /// 处理从文件选择器返回的 URL：做文件名（无扩展）与 video.name 的一致性校验
    func handlePickedURL(_ url: URL) {
        guard let video = pendingVideo else {
            presentAlert(title: "操作异常", message: "未找到待重新链接的视频对象。")
            return
        }
        pendingURL = url
        
        // 取不含扩展名的文件名
        let pickedBaseName = url.deletingPathExtension().lastPathComponent.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // video.name 兜底
        guard let storedName = (video.name?.trimmingCharacters(in: .whitespacesAndNewlines)), !storedName.isEmpty else {
            presentAlert(title: "名称缺失", message: "该视频在数据库中的名称为空，无法核对。请先为视频设置名称。")
            return
        }
        
        // 名称一致则更新文件信息，不一致则提示
        if pickedBaseName == storedName {
            guard let id = video.id else {
                presentAlert(title: "更新失败", message: "该视频缺少唯一标识符（id）。")
                return
            }
            updateVideoFileInfo(id: id, newPath: url.path, context: viewContext)
            self.id = UUID()
        } else {
            presentAlert(
                title: "文件名与记录不一致",
                message: """
                选择的文件名（\(pickedBaseName)）与记录名称（\(storedName)）不一致。
                """
            )
        }
        
        // 清理临时状态
        pendingVideo = nil
        pendingURL = nil
    }
}

// MARK: - 单个视频行
struct VideoRow: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    let video: Videos
    
    @State private var exist = true
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "play.circle")
                .imageScale(.large)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(video.isFinished ? .green : .accentColor)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(video.name ?? "未命名视频")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(exist ? .black : .red)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    if video.lastPosition >= 1.0 {
                        Text("已看至\(formatDuration(video.lastPosition))")
                    }
                    Text(formatDuration(video.duration))
                    Text(fileSizeString(video.fileSize))
                }
                .foregroundStyle(.secondary)
                .font(.caption)
                .lineLimit(1)
            }
            
            Spacer()
            
            if video.lastPosition < 1.0 {
                Text("未观看")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            } else {
                if !video.isFinished {
                    Text("\(Int(video.lastPosition / video.duration * 100))%")
                } else {
                    Image(systemName: "checkmark.circle")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }
        }
        .padding(.vertical, 4)
        // 用 task 比 onAppear 更可靠；当 video 变动或复用时也会重新触发
        .task(id: video.objectID) {
            await checkAndSyncExistFlag()
        }
        .onAppear {
            // 初次渲染时优先用数据库值作为 UI 初值，避免“闪一下”
            exist = video.exist
        }
    }
    
    /// 后台检查文件是否存在；若与 Core Data 的 exist 不一致则写回，并同步本地 UI
    private func checkAndSyncExistFlag() async {
        let existsOnDisk: Bool = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let path = (video.filePosition ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                let result = !path.isEmpty && FileManager.default.fileExists(atPath: path)
                continuation.resume(returning: result)
            }
        }
        
        // 先更新本地 UI
        await MainActor.run {
            self.exist = existsOnDisk
        }
        
        // 与数据库一致就不写，避免无谓 save
        if video.exist == existsOnDisk { return }
        
        // 安全更新数据库：优先用你提供的 setVideoExist 方法；若 id 为空则直接回写对象
        if let id = video.id {
            setVideoExist(id: id, exist: existsOnDisk, context: viewContext)
        } else {
            // 兜底：当前对象没有 id，就直接改并保存
            await viewContext.perform {
                video.exist = existsOnDisk
                do { try viewContext.save() } catch {
                    print("❌ 保存 exist 失败：\(error.localizedDescription)")
                }
            }
        }
    }
}

// MARK: - 小工具
private func formatDuration(_ seconds: Double) -> String {
    guard seconds.isFinite && seconds >= 0 else { return "--:--" }
    let sec = Int(seconds.rounded())
    let h = sec / 3600
    let m = (sec % 3600) / 60
    let s = sec % 60
    return h > 0 ? String(format: "%d:%02d:%02d", h, m, s)
                 : String(format: "%02d:%02d", m, s)
}

private func fileSizeString(_ bytes: Int64) -> String {
    let b = Double(bytes)
    if b < 1024 { return "\(bytes)B" }
    let kb = b / 1024
    if kb < 1024 { return String(format: "%.0fKB", kb) }
    let mb = kb / 1024
    if mb < 1024 { return String(format: "%.1fMB", mb) }
    let gb = mb / 1024
    return String(format: "%.2fGB", gb)
}

#Preview {
    ContentView()
}
