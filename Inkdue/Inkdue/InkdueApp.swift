//
//  InkdueApp.swift
//  Inkdue
//
//  Created by Jaehyun on 2/14/26.
//

import SwiftUI
import SwiftData

@main
struct InkdueApp: App {
    private let container = AppContainer.live
    private let router = AppRouter()

    var body: some Scene {
        WindowGroup {
            router.makeRootView()
        }
        .modelContainer(container.modelContainer)
    }
}
