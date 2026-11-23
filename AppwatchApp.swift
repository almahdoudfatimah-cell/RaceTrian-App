//
//  AppwatchApp.swift
//  Appwatch Watch App
//
//  Created on October 14, 2026.
//

import SwiftUI

@main
struct AppwatchApp: App {
    @State private var store = WatchAppStore()
    @State private var access = WatchAccessStore()

    var body: some Scene {
        WindowGroup {
            WatchEntryRootView(store: store, access: access)
                .task {
                    WatchPhoneSyncManager.shared.activate(store: store, access: access)
                    WatchNotificationManager.shared.activate(store: store)
                }
        }
    }
}
