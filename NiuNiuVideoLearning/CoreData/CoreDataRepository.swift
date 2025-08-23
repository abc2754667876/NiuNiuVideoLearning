//
//  CoreDataRepository.swift
//  NiuNiuVideoLearning
//
//  Created by Chengzhi 张 on 2025/8/23.
//

import Foundation
import CoreData

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
