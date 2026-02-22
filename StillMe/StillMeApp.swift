//
//  StillMeApp.swift
//  StillMe
//
//  Created by K on 2026/02/01.
//

import SwiftUI

@main
struct StillMeApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
