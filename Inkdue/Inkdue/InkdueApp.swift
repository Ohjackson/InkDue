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

    init() {
#if DEBUG
        PolicyInvariantChecks.runAll()
#endif
    }

    var body: some Scene {
        WindowGroup {
            router.makeRootView(
                repository: container.repository,
                syncService: container.syncService
            )
        }
        .modelContainer(container.modelContainer)
    }
}
