//
//  VideoBookmarks+CoreDataProperties.swift
//  NiuNiuVideoLearning
//
//  Created by Chengzhi 张 on 2025/8/22.
//
//

import Foundation
import CoreData


extension VideoBookmarks {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<VideoBookmarks> {
        return NSFetchRequest<VideoBookmarks>(entityName: "VideoBookmarks")
    }

    @NSManaged public var colorTag: Int64
    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var timepoint: Double
    @NSManaged public var video: UUID?

}

extension VideoBookmarks : Identifiable {

}
