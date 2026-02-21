//
//  PrivacyShieldApp.swift
//  PrivacyShield
//
//  Created by siluna on 2026-02-21.
//

import SwiftUI

@main
struct PrivacyShieldApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        Settings {
            EmptyView()
        }
    }
}
