//
//  CoreDataRepository.swift
//  NiuNiuVideoLearning
//
//  Created by Chengzhi 张 on 2025/8/23.
//

import Foundation
import CoreData

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
