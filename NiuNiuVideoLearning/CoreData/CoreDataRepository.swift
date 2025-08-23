//
//  CoreDataRepository.swift
//  NiuNiuVideoLearning
//
//  Created by Chengzhi 张 on 2025/8/23.
//

import Foundation
import CoreData
import CryptoKit

//添加一条视频集
func addCollection(
    name: String,
    note: String? = nil,
    tag: Int64,
    lastVideo: UUID? = nil,
    in context: NSManagedObjectContext
) {
    let newCollection = Collections(context: context)
    newCollection.id = UUID()
    newCollection.date = Date()
    newCollection.name = name
    newCollection.note = note
    newCollection.tag = tag
    newCollection.lastVideo = lastVideo

    do {
        try context.save()
    } catch {
        print("❌ 保存 Collection 失败: \(error.localizedDescription)")
    }
}

//添加一条视频
func addVideo(
    context: NSManagedObjectContext,
    collection: UUID?,
    date: Date = Date(),
    duration: Double,
    exist: Bool = true,
    fileHash: String?,
    filePosition: String?,
    fileSize: Int64,
    name: String,
    tag: String? = nil
) {
    let video = Videos(context: context)
    video.id = UUID()                 // 新的唯一 ID
    video.collection = collection     // 关联的课程集 UUID
    video.date = date                 // 创建日期
    video.duration = duration
    video.exist = exist
    video.fileHash = fileHash
    video.filePosition = filePosition
    video.fileSize = fileSize
    video.name = name
    video.tag = tag
    
    // 默认值
    video.isFinished = false
    video.lastPosition = 0.0
    video.playCount = 0
    
    do {
        try context.save()
    } catch {
        print("保存视频失败: \(error.localizedDescription)")
    }
}

//设置视频存在状态
func setVideoExist(id: UUID, exist: Bool, context: NSManagedObjectContext) {
    let fetchRequest: NSFetchRequest<Videos> = Videos.fetchRequest()
    fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
    fetchRequest.fetchLimit = 1
    
    do {
        if let video = try context.fetch(fetchRequest).first {
            video.exist = exist
            try context.save()
            print("✅ 已更新 video \(id) 的 exist = \(exist)")
        } else {
            print("⚠️ 未找到对应 id 的视频 \(id)")
        }
    } catch {
        print("❌ 更新失败: \(error.localizedDescription)")
    }
}

// MARK: - 1. 更新 lastPosition
/// 更新特定 id 的 video 的 lastPosition
func updateLastPosition(id: UUID, lastPosition: Double, context: NSManagedObjectContext) {
    let request: NSFetchRequest<Videos> = Videos.fetchRequest()
    request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
    request.fetchLimit = 1
    do {
        if let video = try context.fetch(request).first {
            video.lastPosition = lastPosition
            try context.save()
            print("✅ 更新 lastPosition 成功: \(lastPosition)")
        } else {
            print("⚠️ 未找到视频 \(id)")
        }
    } catch {
        print("❌ 更新 lastPosition 失败: \(error)")
    }
}

// MARK: - 2. 更新 filePosition, fileHash, fileSize
/// 更新特定 id 的 video 的 filePosition、fileHash、fileSize
/// fileHash 使用 SHA256 计算，fileSize 使用文件属性获取
func updateVideoFileInfo(id: UUID, newPath: String, context: NSManagedObjectContext) {
    let request: NSFetchRequest<Videos> = Videos.fetchRequest()
    request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
    request.fetchLimit = 1
    do {
        if let video = try context.fetch(request).first {
            let url = URL(fileURLWithPath: newPath)
            video.filePosition = newPath
            
            // 获取文件大小
            if let attr = try? FileManager.default.attributesOfItem(atPath: newPath),
               let size = attr[.size] as? NSNumber {
                video.fileSize = size.int64Value
            } else {
                video.fileSize = 0
            }
            
            // 计算文件 hash（SHA256）
            if let data = try? Data(contentsOf: url) {
                let digest = SHA256.hash(data: data)
                video.fileHash = digest.compactMap { String(format: "%02x", $0) }.joined()
            } else {
                video.fileHash = nil
            }
            
            try context.save()
            print("✅ 更新文件信息成功: \(newPath)")
        } else {
            print("⚠️ 未找到视频 \(id)")
        }
    } catch {
        print("❌ 更新文件信息失败: \(error)")
    }
}

// MARK: - 3. 更新 isFinished
/// 更新特定 id 的 video 的 isFinished
func updateIsFinished(id: UUID, isFinished: Bool, context: NSManagedObjectContext) {
    let request: NSFetchRequest<Videos> = Videos.fetchRequest()
    request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
    request.fetchLimit = 1
    do {
        if let video = try context.fetch(request).first {
            video.isFinished = isFinished
            try context.save()
            print("✅ 更新 isFinished 成功: \(isFinished)")
        } else {
            print("⚠️ 未找到视频 \(id)")
        }
    } catch {
        print("❌ 更新 isFinished 失败: \(error)")
    }
}

// MARK: - 4. 播放计数 +1
/// 让特定 id 的 video 的 playCount 加 1
func increasePlayCount(id: UUID, context: NSManagedObjectContext) {
    let request: NSFetchRequest<Videos> = Videos.fetchRequest()
    request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
    request.fetchLimit = 1
    do {
        if let video = try context.fetch(request).first {
            video.playCount += 1
            try context.save()
            print("✅ playCount 增加到: \(video.playCount)")
        } else {
            print("⚠️ 未找到视频 \(id)")
        }
    } catch {
        print("❌ 更新 playCount 失败: \(error)")
    }
}

// MARK: - 5. 更新 tag
/// 更新特定 id 的 video 的 tag
func updateTag(id: UUID, newTag: String, context: NSManagedObjectContext) {
    let request: NSFetchRequest<Videos> = Videos.fetchRequest()
    request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
    request.fetchLimit = 1
    do {
        if let video = try context.fetch(request).first {
            video.tag = newTag
            try context.save()
            print("✅ 更新 tag 成功: \(newTag)")
        } else {
            print("⚠️ 未找到视频 \(id)")
        }
    } catch {
        print("❌ 更新 tag 失败: \(error)")
    }
}

// MARK: - 6. 删除视频
/// 删除特定 id 的 video
func deleteVideo(id: UUID, context: NSManagedObjectContext) {
    let request: NSFetchRequest<Videos> = Videos.fetchRequest()
    request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
    request.fetchLimit = 1
    do {
        if let video = try context.fetch(request).first {
            context.delete(video)
            try context.save()
            print("✅ 删除视频成功 \(id)")
        } else {
            print("⚠️ 未找到视频 \(id)")
        }
    } catch {
        print("❌ 删除失败: \(error)")
    }
}

/// 删除特定 id 的 Collection，
/// 并同时删除所有 `Videos.collection == id` 的视频。
func deleteCollectionAndVideos(id: UUID, context: NSManagedObjectContext) {
    // 1. 删除相关 Videos
    let videoRequest: NSFetchRequest<Videos> = Videos.fetchRequest()
    videoRequest.predicate = NSPredicate(format: "collection == %@", id as CVarArg)
    
    do {
        let videos = try context.fetch(videoRequest)
        for v in videos {
            context.delete(v)
        }
        
        // 2. 删除对应的 Collection
        let colRequest: NSFetchRequest<Collections> = Collections.fetchRequest()
        colRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        colRequest.fetchLimit = 1
        
        if let collection = try context.fetch(colRequest).first {
            context.delete(collection)
        } else {
            print("⚠️ 未找到 Collection \(id)")
        }
        
        // 3. 保存更改
        try context.save()
        print("✅ 已删除 Collection \(id) 及其所有相关 Videos (\(videos.count) 个)")
        
    } catch {
        print("❌ 删除失败: \(error.localizedDescription)")
    }
}
