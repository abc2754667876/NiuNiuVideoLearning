//
//  AddVideoView.swift
//  NiuNiuVideoLearning
//
//  Created by Chengzhi 张 on 2025/8/23.
//

import SwiftUI
import CoreData
import AVFoundation
import UniformTypeIdentifiers
import CryptoKit
import AppKit

// 临时数据模型
struct PickedVideo: Identifiable, Hashable {
    let id = UUID()
    let duration: Double
    let hash: String
    let path: String
    let fileSize: Int64
    let fileName: String
    let bookmark: Data              // ✅ 新增：持久化访问授权
}

struct AddVideoView: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.managedObjectContext) private var viewContext
    
    let preSelectedUUID: UUID?
    let prePickedVideos: [String]
    
    @State private var showAlert = false
    @State private var alertInfo = ""
    @State private var loadingVideo = false
    
    @State private var selectedName: String = "请选择"
    @State private var selectedID: UUID? = nil
    
    // 选中的视频们 & 列表选中项
    @State private var pickedVideos: [PickedVideo] = []
    @State private var selectedRows = Set<UUID>()   // 选中哪几行（用于删除）
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Collections.date, ascending: false)],
        animation: .default
    )
    private var collections: FetchedResults<Collections>
    
    var body: some View {
        VStack{
            HStack{
                Text("导入视频到课程")
                    .font(.title2)
                    .bold()
                    .padding(.bottom)
                
                Spacer()
            }
            
            HStack{
                Text("课程：")
                Spacer()
                Picker("", selection: $selectedID) {
                    Text("请选择").tag(UUID?.none)

                    ForEach(collections) { item in
                        Text(item.name?.isEmpty == false ? item.name! : "未命名")
                            .tag(item.id)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .onChange(of: selectedID) { newValue in
                    if let id = newValue,
                       let found = collections.first(where: { $0.id == id }) {
                        selectedName = (found.name?.isEmpty == false) ? found.name! : "未命名"
                    } else {
                        selectedName = "请选择"
                    }
                }
            }

            // “视频：” + 右侧列表
            HStack(alignment: .top, spacing: 12) {
                Text("视频：")

                Table(pickedVideos, selection: $selectedRows) {
                    TableColumn("文件名") { v in Text(v.fileName) }
                    TableColumn("时长(s)") { v in Text(String(format: "%.2f", v.duration)) }
                    TableColumn("大小") { v in Text(byteString(v.fileSize)) }
                    TableColumn("路径") { v in Text(v.path).lineLimit(1) }
                }
                .frame(minHeight: 160, maxHeight: 220)
            }
            .padding(.top, 8)
            
            Divider()
                .padding(.vertical)
            
            HStack{
                Button("选择视频…") { pickVideos() }
                    .buttonStyle(.borderedProminent)

                Button("删除选中") {
                    pickedVideos.removeAll { selectedRows.contains($0.id) }
                    selectedRows.removeAll()
                }
                .disabled(selectedRows.isEmpty)

                Button("清空全部") {
                    pickedVideos.removeAll()
                    selectedRows.removeAll()
                }
                .disabled(pickedVideos.isEmpty)
                
                Spacer()
                
                if loadingVideo {
                    ProgressView()
                }
                
                Button("取消"){
                    presentationMode.wrappedValue.dismiss()
                }
                
                Button("添加"){
                    if selectedID == nil {
                        alertInfo = "请选择要加入的课程集"
                        showAlert = true
                        
                        return
                    }
                    
                    addVideos()
                    presentationMode.wrappedValue.dismiss()
                }
                .disabled(selectedID == nil || pickedVideos.isEmpty)
                .buttonStyle(.borderedProminent)
            }
            
        }
        .frame(width: 760)
        .padding()
        .alert("提示", isPresented: $showAlert) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(alertInfo)
        }
        .onAppear{
            if preSelectedUUID != nil {
                selectedID = preSelectedUUID
            }
            
            if !prePickedVideos.isEmpty {
                loadingVideo = true
                Task.detached {
                    var newOnes: [PickedVideo] = []
                    for path in prePickedVideos {
                        let url = URL(fileURLWithPath: path)
                        if let v = await makePickedVideo(from: url) {
                            newOnes.append(v)
                        }
                    }
                    await MainActor.run {
                        let existingPaths = Set(pickedVideos.map { $0.path })
                        let filtered = newOnes.filter { !existingPaths.contains($0.path) }
                        pickedVideos.append(contentsOf: filtered)
                        loadingVideo = false
                    }
                }
            }
        }
    }
    
    // MARK: - 添加视频到coredata
    private func addVideos() {
        for video in pickedVideos {
            addVideo(
                context: viewContext,
                collection: selectedID,
                duration: video.duration,
                fileHash: video.hash,
                filePosition: video.path,
                fileSize: video.fileSize,
                name: video.fileName,
                fileBookmark: video.bookmark          // ✅ 新增：入库 bookmark
            )
        }
    }
    
    // MARK: - 文件选择（macOS）
    private func pickVideos() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.movie, .video, .mpeg4Movie, .quickTimeMovie]
        panel.prompt = "选择"
        if panel.runModal() == .OK {
            loadingVideo = true
            Task.detached {
                var newOnes: [PickedVideo] = []
                for url in panel.urls {
                    if let v = await makePickedVideo(from: url) {
                        newOnes.append(v)
                    }
                }
                await MainActor.run {
                    let existingPaths = Set(pickedVideos.map { $0.path })
                    let filtered = newOnes.filter { !existingPaths.contains($0.path) }
                    pickedVideos.append(contentsOf: filtered)
                    loadingVideo = false
                }
            }
        }
    }

    // MARK: - 元数据解析
    private func makePickedVideo(from url: URL) async -> PickedVideo? {
        // ✅ 为该 URL 生成 security-scoped bookmark（用于跨重启访问）
        let bookmark: Data
        do {
            bookmark = try url.bookmarkData(options: [.withSecurityScope],
                                            includingResourceValuesForKeys: nil,
                                            relativeTo: nil)
        } catch {
            print("❌ 生成书签失败：\(error.localizedDescription)")
            return nil
        }

        // ✅ 进入作用域以便读取元数据（时长 / 大小 / 哈希）
        var didAccess = false
        var scopedURL = url
        if url.startAccessingSecurityScopedResource() {
            didAccess = true
        } else {
            // 某些情况下 NSOpenPanel 返回的 URL 在当前会话已可读；若失败也尝试继续使用
            // 可根据需要决定是否在此直接 return
            print("⚠️ 未能进入安全作用域，尝试直接读取")
        }

        defer {
            if didAccess { scopedURL.stopAccessingSecurityScopedResource() }
        }

        // 时长
        let asset = AVURLAsset(url: scopedURL)
        let seconds = CMTimeGetSeconds(asset.duration)

        // 文件大小
        let fileSize = (try? scopedURL.resourceValues(forKeys: [.fileSizeKey]).fileSize)
            .map(Int64.init) ?? 0

        // 文件名（无后缀）
        let name = scopedURL.deletingPathExtension().lastPathComponent

        // 绝对路径
        let path = scopedURL.path

        // 哈希（SHA256）——用作用域内的 URL 读取
        guard let sha = sha256Hex(of: scopedURL) else { return nil }

        return PickedVideo(
            duration: seconds,
            hash: sha,
            path: path,
            fileSize: fileSize,
            fileName: name,
            bookmark: bookmark                  // ✅ 带回书签
        )
    }

    // MARK: - 工具：SHA256（流式）
    private func sha256Hex(of url: URL) -> String? {
        guard let stream = InputStream(url: url) else { return nil }
        stream.open()
        defer { stream.close() }
        var hasher = SHA256()
        let bufSize = 1024 * 1024
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufSize)
        defer { buffer.deallocate() }
        while stream.hasBytesAvailable {
            let read = stream.read(buffer, maxLength: bufSize)
            if read < 0 { return nil }
            if read == 0 { break }
            hasher.update(data: Data(bytesNoCopy: buffer, count: read, deallocator: .none))
        }
        let digest = hasher.finalize()
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - 工具：字节可读化
    private func byteString(_ size: Int64) -> String {
        let units = ["B","KB","MB","GB","TB"]
        var s = Double(size)
        var i = 0
        while s >= 1024 && i < units.count-1 { s /= 1024; i += 1 }
        return String(format: "%.2f %@", s, units[i])
    }
}
