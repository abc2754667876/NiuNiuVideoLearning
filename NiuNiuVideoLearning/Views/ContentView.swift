//
//  ContentView.swift
//  NiuNiuVideoLearning
//
//  Created by Chengzhi 张 on 2025/8/22.
//

import SwiftUI
import UniformTypeIdentifiers
import AVKit

struct ContentView: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(\.managedObjectContext) private var viewContext

    @State private var showAddCollection = false
    @State private var showAddVideo = false
    @State private var showSpeedPopover = false
    @State private var setRate: Float = 1.0
    @State private var selectedVideo: Videos?
    
    @State private var now = Date()   // 用来触发时间刷新

    // 定时器，每隔 30 秒刷新一次（避免时间不动）
    private let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    var estimatedEndTime: String? {
        guard playerCtl.isPlaying,
              playerCtl.itemReady,
              let video = selectedVideo else { return nil }

        let played = playerCtl.currentTime              // ✅ 实时进度（秒）
        let duration = video.duration
        let remain = max(duration - played, 0)
        // 过短或倍速接近 0 就不显示，避免异常
        guard remain > 1, playerCtl.rate >= 0.05 else { return nil }

        // 实际需要的“现实时间秒数”（考虑倍速）
        let realSeconds = remain / Double(playerCtl.rate)

        // 可选：取整到“下一分钟”避免秒级抖动
        let end = Date().addingTimeInterval(realSeconds)
        let endRoundedToMinute = Calendar.current.date(bySetting: .second, value: 0,
                                      of: end.addingTimeInterval(60)) ?? end

        let cal = Calendar.current
        let timeFmt = DateFormatter()
        timeFmt.dateFormat = "HH:mm"

        var prefix = ""
        if !cal.isDateInToday(endRoundedToMinute) {
            if cal.isDateInTomorrow(endRoundedToMinute) {
                prefix = "明日 "
            } else {
                let dayFmt = DateFormatter()
                dayFmt.dateFormat = "MM-dd "
                prefix = dayFmt.string(from: endRoundedToMinute)
            }
        }

        return "\(prefix)\(timeFmt.string(from: endRoundedToMinute))"
    }

    // ✅ 播放控制器（父级持有）
    @StateObject private var playerCtl = PlayerController()

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Collections.date, ascending: false)],
        animation: .default
    )
    private var collections: FetchedResults<Collections>

    var body: some View {
        NavigationSplitView {
            if collections.isEmpty {
                Text("请先创建课程")
                    .foregroundStyle(.secondary)
            } else {
                ScrollView{
                    VStack(spacing: 8){
                        ForEach(collections.indices, id: \.self) { index in
                            let col = collections[index]
                            CustomDisclosureRow(
                                title: col.name ?? "未命名",
                                color: tags[Int(col.tag)].color,
                                collection: col,
                                // ✅ 把“选中视频”的回调从最外层传进去
                                onSelectVideo: { video in
                                    playerCtl.isPlaying = false   // 👈 切视频先停
                                    selectedVideo = video
                                }
                            )
                            .padding(.vertical, 6)
                            .padding(.horizontal, 8)
                            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
            }
        } detail: {
            if let video = selectedVideo,
               let path = video.filePosition?.trimmingCharacters(in: .whitespacesAndNewlines),
               !path.isEmpty {
                VideoDetailPlayer(
                    filePath: path,
                    title: video.name ?? "未命名视频",
                    fileBookmark: video.fileBookmark,
                    controller: playerCtl,            // ✅ 传控制器
                    videoID: video.id!,                 // ✅ 新增
                    videoDuration: video.duration,       // ✅ 新增
                    lastPosition: video.lastPosition        // ✅ 新增
                )
                .id(video.id!)   // 👈 切视频时强制重建
            } else {
                Text("暂无要播放的视频").foregroundStyle(.secondary)
            }
        }
        // ✅ 动态标题：选中视频名，否则默认
        .navigationTitle(selectedVideo?.name ?? "牛牛看课")
        .toolbar {
            ToolbarItem(placement: .navigation) {
                HStack {
                    Button(action: { showAddCollection = true }) { Image(systemName: "folder.badge.plus") }
                        .help("新建课程")
                        .sheet(isPresented: $showAddCollection) { AddCollectionView() }

                    Button(action: { showAddVideo = true }) { Image(systemName: "video.badge.plus") }
                        .help("导入课程视频")
                        .sheet(isPresented: $showAddVideo) { AddVideoView(preSelectedUUID: nil, prePickedVideos: []) }
                }
            }

            // ✅ 这里放播放控制（可以随意换 placement）
            ToolbarItem(placement: .cancellationAction) {
                HStack(spacing: 14) {
                    // ✅ 显示预计结束时间
                    if let end = estimatedEndTime {
                        Text("将于\(end)结束")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Button {
                        showSpeedPopover.toggle()
                    } label: {
                        Label("播放速度", systemImage: "speedometer")
                    }
                    .help("调节播放速度")
                    .disabled(selectedVideo == nil)
                    .popover(isPresented: $showSpeedPopover, arrowEdge: .top) {
                        SpeedPopoverView(controller: playerCtl, setRate: $setRate)
                            .frame(width: 280)
                            .padding()
                        // macOS 风格的小气泡
                    }

                    Button {
                        playerCtl.togglePlay()
                    } label: {
                        Image(systemName: playerCtl.isPlaying ? "pause.fill" : "play.fill")
                    }
                    .disabled(selectedVideo == nil)
                    .help(playerCtl.isPlaying ? "暂停" : "播放")
                }
                .onChange(of: playerCtl.isPlaying) {
                    playerCtl.setRate(setRate)
                    if let id = selectedVideo?.id {
                        updateLastPosition(id: id, lastPosition: playerCtl.currentTime, context: viewContext)
                    }
                }
                .onChange(of: playerCtl.currentTime) {
                    if Int(playerCtl.currentTime) % 3 == 0 {
                        if let id = selectedVideo?.id {
                            updateLastPosition(id: id, lastPosition: playerCtl.currentTime, context: viewContext)
                        }
                    }
                }
            }
        }
        .onReceive(timer) { date in
            now = date
        }
    }
}

struct SpeedPopoverView: View {
    @ObservedObject var controller: PlayerController
    
    //@State private var tempRate: Float = 1.0
    @Binding var setRate: Float
    
    private let presets: [Float] = [0.75, 1.0, 1.25, 1.5, 2.0]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack{
                Text("播放速度:\(String(format: "%.2fx", setRate))").font(.headline)
                
                Spacer()
                
                Button(action: {
                    setRate = 1.0
                    controller.setRate(1.0)
                }){
                    Image(systemName: "arrow.counterclockwise")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            Slider(value: Binding(
                get: { Double(setRate) },
                set: { newVal in
                    setRate = Float(newVal)
                    controller.setRate(setRate)
                }),
                   in: 0.1...4.0, step: 0.1)
            
            // 常用预设
            HStack {
                ForEach(presets, id: \.self) { r in
                    Button(String(format: "%.2fx", r)) {
                        setRate = r
                        controller.setRate(r)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .onAppear { setRate = controller.rate }
    }
}

// MARK: - 折叠行（带子列表）
struct CustomDisclosureRow: View {
    @Environment(\.managedObjectContext) private var viewContext

    let title: String
    let color: Color
    let collection: Collections

    // ✅ 新增：把点击某视频的事件往上抛
    let onSelectVideo: (Videos) -> Void

    @State private var expanded = false
    @State private var showDeleteConfirm = false
    
    // ✅ 新增：文件选择 & 结果
    @State private var showFileImporter = false
    @State private var pickedVideoPaths: [String] = []   // ← 选中的所有视频路径会存这里
    @State private var showAddVideoView = false

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
                Button("导入视频到当前课程") {
                    pickedVideoPaths.removeAll()
                    showFileImporter = true
                }
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
                // ✅ 把 onSelectVideo 继续往子视图传
                VideosForCollectionView(collectionID: collection.id, onSelect: onSelectVideo)
                    .padding(.leading)
            }
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.movie, .video, .mpeg4Movie, .quickTimeMovie],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                // 统一成路径字符串，去重
                let paths = urls.map { $0.path }
                let unique = Array(Set(paths)).sorted()
                pickedVideoPaths = unique

                showAddVideoView = true

            case .failure(let err):
                print("❌ 选择文件失败：\(err.localizedDescription)")
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            // 先清空
            pickedVideoPaths.removeAll()
            let allowedUTIs: [UTType] = [.movie, .video, .mpeg4Movie, .quickTimeMovie]

            // 过滤：按扩展名推断 UTI，再与允许的类型做 conforms
            let filtered = urls.compactMap { url -> String? in
                guard let ut = UTType(filenameExtension: url.pathExtension) else { return nil }
                return allowedUTIs.contains(where: { ut.conforms(to: $0) }) ? url.path : nil
            }

            pickedVideoPaths = Array(Set(filtered)).sorted()
            showAddVideoView = true
            return !pickedVideoPaths.isEmpty
        }
        .sheet(isPresented: $showAddVideoView) {
            AddVideoView(preSelectedUUID: collection.id, prePickedVideos: pickedVideoPaths)
        }
    }
}

// MARK: - 子视图：某个 Collection 下的 Videos 实时列表
struct VideosForCollectionView: View {
    @Environment(\.managedObjectContext) private var viewContext

    // ✅ 新增：点击某行时回调
    let onSelect: (Videos) -> Void

    @FetchRequest private var videos: FetchedResults<Videos>

    @State private var showFileImporter = false
    @State private var alertMessage: String = ""
    @State private var showAlert = false

    @State private var pendingVideo: Videos?
    @State private var pendingURL: URL?

    @State private var id = UUID()
    @State private var timer: Timer?   // ✅ 定时器引用
    
    init(collectionID: UUID?, onSelect: @escaping (Videos) -> Void) {
        self.onSelect = onSelect
        if let id = collectionID {
            _videos = FetchRequest(
                entity: Videos.entity(),
                sortDescriptors: [NSSortDescriptor(keyPath: \Videos.date, ascending: false)],
                predicate: NSPredicate(format: "collection == %@", id as CVarArg),
                animation: .default
            )
        } else {
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
                    // ✅ 点击整行，触发 onSelect(video)
                    VideoRow(video: video)
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2){
                            onSelect(video)
                        }
                        .contextMenu {
                            Button("重新链接") {
                                pendingVideo = video
                                showFileImporter = true
                            }
                            .disabled(video.exist)
                            Button("删除当前视频") {
                                deleteVideo(id: video.id!, context: viewContext)
                            }
                        }
                    Divider().opacity(0.15)
                }
            }
            .id(id)
            .onAppear {
                // ✅ 启动定时器
                timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { _ in
                    id = UUID()
                }
            }
            .onDisappear {
                // ✅ 停掉定时器
                timer?.invalidate()
                timer = nil
            }
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

            // ✅ 生成 security-scoped bookmark
            do {
                let bookmark = try url.bookmarkData(
                    options: [.withSecurityScope],
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
                updateVideoFileInfo(
                    id: id,
                    newPath: url.path,
                    bookmark: bookmark,         // ✅ 传 bookmark
                    context: viewContext
                )
                self.id = UUID()
            } catch {
                presentAlert(title: "保存授权失败", message: error.localizedDescription)
            }
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
                .foregroundStyle(.blue)
            
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
                        .foregroundStyle(.secondary)
                        .font(.caption)
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

struct VideoDetailPlayer: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    let filePath: String
    let title: String
    var fileBookmark: Data? = nil
    
    @ObservedObject var controller: PlayerController
    
    // ✅ 新增：用于写回 Core Data
    let videoID: UUID
    let videoDuration: Double
    let lastPosition: Double    // ✅ 新增

    @State private var player = AVPlayer()
    @State private var scopedURL: URL?
    @State private var errorText: String?
    
    @State private var loadTicket = UUID()
    
    // ✅ 新增：KVO/通知句柄
    @State private var statusObs: NSKeyValueObservation?
    @State private var rateObs: NSKeyValueObservation?
    @State private var endObserver: Any?
    
    @State private var enforceTimer: Timer?
    
    // ✅ 新增：2 秒保存节流 & 完成标记
    @State private var lastSavedAt: Date = .distantPast
    @State private var hasMarkedFinished = false
    private let saveTick = Timer.publish(every: 2, on: .main, in: .common).autoconnect()
    @State private var jumpObserver: Any?
    @State private var itemStatusObs: NSKeyValueObservation?

    var body: some View {
        VStack(spacing: 0) {
            if let errorText {
                ZStack {
                    Color.secondary.opacity(0.08)
                    VStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill").font(.largeTitle)
                        Text(errorText).multilineTextAlignment(.center).foregroundStyle(.secondary)
                    }.padding()
                }
            } else {
                VideoPlayer(player: player)
            }
        }
        .onAppear {
            controller.attach(player)          // 让 Toolbar 能控制它
            attachObservers()                  // ✅ 监听系统控件触发的状态改变
            prepareAndPlay()
        }
        .onChange(of: filePath) { _ in prepareAndPlay() }
        .onDisappear {
            detachObservers()
            if let url = scopedURL { url.stopAccessingSecurityScopedResource(); scopedURL = nil }
        }
        .onReceive(controller.$rate) { _ in
            if controller.isPlaying { startRateGovernor() }
        }
        // ✅ 播放状态改变时立即保存一次当前位置
        .onChange(of: controller.isPlaying) { _ in
            savePositionNow()
        }

        // ✅ 正常播放时每 2 秒保存一次
        .onReceive(saveTick) { _ in
            guard controller.isPlaying else { return }
            savePositionIfNeeded()
            checkAndMarkFinishedIfNeeded()
        }

        // ✅ rate 变化时也检查完成（倍速改变会影响到达剩余 20s 的时间点）
        .onReceive(controller.$rate) { _ in
            checkAndMarkFinishedIfNeeded()
        }
    }
    
    // MARK: - 保存当前位置
    private func savePositionNow() {
        let pos = controller.currentTime
        updateLastPosition(id: videoID, lastPosition: pos, context: viewContext)
        lastSavedAt = Date()
    }

    private func savePositionIfNeeded() {
        // 节流：2s 一次
        if Date().timeIntervalSince(lastSavedAt) >= 2 {
            savePositionNow()
        }
    }

    // MARK: - 剩余 ≤ 20s 标记完成（只标一次）
    private func checkAndMarkFinishedIfNeeded() {
        guard !hasMarkedFinished else { return }
        let remain = max(videoDuration - controller.currentTime, 0)
        if remain <= 20 {
            updateIsFinished(id: videoID, isFinished: true, context: viewContext)
            hasMarkedFinished = true
        }
    }
    
    private func startRateGovernor() {
        enforceTimer?.invalidate()
        guard Date() < controller.enforceUntil else { return }

        // 立即校正一次
        player.currentItem?.audioTimePitchAlgorithm = .timeDomain
        player.rate = controller.rate

        // 之后在强制期内每 50ms 纠正一次
        enforceTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { t in
            if Date() > controller.enforceUntil || abs(self.player.rate - self.controller.rate) <= 0.01 {
                t.invalidate()
                return
            }
            self.player.rate = self.controller.rate
        }
    }
    
    // MARK: - 监听/同步
    private func attachObservers() {
        // 1) timeControlStatus（暂停/播放/缓冲）
        statusObs = player.observe(\.timeControlStatus, options: [.initial, .new]) { p, _ in
            DispatchQueue.main.async {
                let playing = (p.timeControlStatus == .playing) ||
                              (p.timeControlStatus == .waitingToPlayAtSpecifiedRate && p.rate > 0)
                controller.isPlaying = playing
                if playing { startRateGovernor() }
            }
        }
        // 2) rate（有些系统控件会直接改 rate）
        rateObs = player.observe(\.rate, options: [.new]) { p, _ in
            DispatchQueue.main.async {
                controller.isPlaying = p.rate > 0
                if p.rate > 0 {               // 仅播放中才认为是“有效倍速”
                    controller.syncFromPlayer(rate: p.rate)
                }
            }
        }
        // 3) 播放结束通知
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: nil, queue: .main
        ) { [weak controller] _ in
            controller?.isPlaying = false
        }
        // ✅ 进度条跳变：立即保存当前位置 & 检查完成
        jumpObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemTimeJumped,
            object: nil, queue: .main
        ) { _ in
            savePositionNow()
            checkAndMarkFinishedIfNeeded()
        }
    }

    private func detachObservers() {
        statusObs?.invalidate(); statusObs = nil
        rateObs?.invalidate();   rateObs   = nil
        itemStatusObs?.invalidate(); itemStatusObs = nil   // ✅
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        if let jumpObserver { NotificationCenter.default.removeObserver(jumpObserver) }
        endObserver = nil
        jumpObserver = nil
    }

    private func preparedURL() -> URL? {
        // 1) 优先用 bookmark 解锁
        if let data = fileBookmark {
            var stale = false
            do {
                let url = try URL(resolvingBookmarkData: data,
                                  options: [.withSecurityScope],
                                  relativeTo: nil,
                                  bookmarkDataIsStale: &stale)
                if url.startAccessingSecurityScopedResource() {
                    scopedURL = url
                    return url
                } else {
                    print("❌ 无法进入安全作用域")
                }
            } catch { print("❌ 解析书签失败:", error.localizedDescription) }
        }
        // 2) 回退用路径（若无权限可能仍失败）
        return URL(fileURLWithPath: filePath)
    }

    private func prepareAndPlay() {
        controller.itemReady = false      // 切源先置 false
        
        errorText = nil
        loadTicket = UUID()                 // 👈 新工单号
        hasMarkedFinished = false           // 重置完成标记
        controller.currentTime = 0          // 切源先把当前时间清零（避免把旧时间带入计算）

        guard let url = preparedURL() else { errorText = "无法构造视频 URL。"; return }
        let ticket = loadTicket             // 👈 捕获本次 ticket

        let asset = AVURLAsset(url: url)
        let keys = ["playable", "hasProtectedContent", "tracks"]
        asset.loadValuesAsynchronously(forKeys: keys) {
            // ……校验 keys ……
            DispatchQueue.main.async {
                // 若已经切到别的视频了，丢弃这次结果
                guard ticket == self.loadTicket else { return }     // 👈 防回调串台

                let item = AVPlayerItem(asset: asset)
                self.player.replaceCurrentItem(with: item)
                self.player.currentItem?.audioTimePitchAlgorithm = .timeDomain

                // 先移除旧观察者
                self.itemStatusObs?.invalidate()

                self.itemStatusObs = item.observe(\.status, options: [.initial, .new]) { item, _ in
                    // 回调里也要核对
                    guard ticket == self.loadTicket else { return } // 👈 再次防串台

                    let plyr = self.player
                    let ctrl = self.controller
                    let desired = self.lastPosition
                    let dur = self.videoDuration

                    DispatchQueue.main.async {
                        switch item.status {
                        case .readyToPlay:
                            self.controller.itemReady = true   // 👈 ready
                            let safeLast = max(0, min(desired, max(0, dur - 0.5)))
                            if safeLast > 1 {
                                let target = CMTime(seconds: safeLast, preferredTimescale: 600)
                                plyr.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero) { _ in
                                    // 同步 controller.currentTime，避免“把旧时间带过去”
                                    self.controller.currentTime = safeLast
                                    if ctrl.isPlaying {
                                        plyr.playImmediately(atRate: ctrl.rate)
                                    }
                                }
                            } else if ctrl.isPlaying {
                                plyr.playImmediately(atRate: ctrl.rate)
                            }

                        case .failed:
                            self.errorText = "播放失败：\(item.error?.localizedDescription ?? "未知错误")"
                        case .unknown: break
                        @unknown default: break
                        }
                    }
                }
            }
        }
    }
}

final class PlayerController: ObservableObject {
    @Published var isPlaying = false
    @Published var rate: Float = 1.0
    @Published var currentTime: Double = 0   // ✅ 当前播放秒数（动态刷新）
    @Published var itemReady: Bool = false   // 👈 当前 item 是否 ready

    private weak var player: AVPlayer?
    private var programmaticRateChange = false
    fileprivate var enforceUntil: Date = .distantPast

    private var timeObserver: Any?

    func attach(_ player: AVPlayer) {
        self.player = player
        player.automaticallyWaitsToMinimizeStalling = true
        applyRateToPlayer()

        // ✅ 每 0.5 秒刷新一次 currentTime
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: 600),
            queue: .main
        ) { [weak self] t in
            self?.currentTime = t.seconds
        }
    }

    func togglePlay() {
        guard let p = player else { return }
        if p.timeControlStatus == .playing {
            p.pause()
            isPlaying = false
        } else {
            p.playImmediately(atRate: rate)
            isPlaying = true
            // 恢复播放也进入短时强制期
            enforceUntil = Date().addingTimeInterval(1.0)
        }
    }

    func restart() {
        guard let p = player else { return }
        p.seek(to: .zero)
        p.playImmediately(atRate: rate)
        isPlaying = true
        enforceUntil = Date().addingTimeInterval(1.0)
    }

    func setRate(_ newRate: Float) {
        guard abs(rate - newRate) > 0.001 else { return }
        rate = newRate
        enforceUntil = Date().addingTimeInterval(1.0) // 外层改速 -> 进入强制期
        applyRateToPlayer()
    }

    func syncFromPlayer(rate actual: Float) {
        guard !programmaticRateChange, abs(actual - rate) > 0.01 else { return }
        // 如果不是强制期，允许从系统 UI 同步进来
        if Date() > enforceUntil { rate = actual }
    }

    private func applyRateToPlayer() {
        guard let p = player else { return }
        programmaticRateChange = true
        defer { programmaticRateChange = false }

        p.currentItem?.audioTimePitchAlgorithm = .timeDomain
        if isPlaying { p.rate = rate } else { p.rate = 0 }
    }
    
    deinit {
        if let player, let timeObserver { player.removeTimeObserver(timeObserver) }
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
