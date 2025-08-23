//
//  Collections+CoreDataProperties.swift
//  NiuNiuVideoLearning
//
//  Created by Chengzhi 张 on 2025/8/22.
//
//

import Foundation
import CoreData


extension Collections {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Collections> {
        return NSFetchRequest<Collections>(entityName: "Collections")
    }

    @NSManaged public var date: Date?
    @NSManaged public var id: UUID?
    @NSManaged public var lastVideo: UUID?
    @NSManaged public var name: String?
    @NSManaged public var note: String?
    @NSManaged public var tag: Int64

}

extension Collections : Identifiable {

}
