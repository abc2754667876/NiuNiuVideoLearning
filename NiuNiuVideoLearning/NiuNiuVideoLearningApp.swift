//
//  NiuNiuVideoLearningApp.swift
//  NiuNiuVideoLearning
//
//  Created by Chengzhi 张 on 2025/8/22.
//

import SwiftUI

@main
struct NiuNiuVideoLearningApp: App {
    let persistenceController = PersistenceController.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
