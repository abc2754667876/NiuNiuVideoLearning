//
//  Videos+CoreDataProperties.swift
//  NiuNiuVideoLearning
//
//  Created by Chengzhi 张 on 2025/8/22.
//
//

import Foundation
import CoreData


extension Videos {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Videos> {
        return NSFetchRequest<Videos>(entityName: "Videos")
    }

    @NSManaged public var collection: UUID?
    @NSManaged public var date: Date?
    @NSManaged public var duration: Double
    @NSManaged public var exist: Bool
    @NSManaged public var fileHash: String?
    @NSManaged public var filePosition: String?
    @NSManaged public var fileSize: Int64
    @NSManaged public var id: UUID?
    @NSManaged public var isFinished: Bool
    @NSManaged public var lastPosition: Double
    @NSManaged public var name: String?
    @NSManaged public var playCount: Int64
    @NSManaged public var tag: String?
    @NSManaged public var fileBookmark: Data?

}

extension Videos : Identifiable {

}
