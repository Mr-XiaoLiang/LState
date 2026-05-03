//
//  LStateApp.swift
//  LState
//
//  Created by Lollipop on 2026/5/3.
//

import SwiftUI

@main
struct LStateApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarController: StatusBarController?
    let monitor = SystemMonitor()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        statusBarController = StatusBarController(monitor: monitor)
    }
}
