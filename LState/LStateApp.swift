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
        // 隐藏 Dock 图标，作为纯菜单栏应用运行
        NSApp.setActivationPolicy(.accessory)
        
        statusBarController = StatusBarController(monitor: monitor)
    }
}
