//
//  LStateApp.swift
//  LState
//
//  Created by Lollipop on 2026/5/3.
//

import SwiftUI

@main
struct LStateApp: App {
    @State private var monitor = SystemMonitor()
    
    var body: some Scene {
        MenuBarExtra {
            InfoPopoverView(monitor: monitor)
                .padding()
                .onAppear {
                    monitor.startMonitoring()
                }
                .onDisappear {
                    monitor.stopMonitoring()
                }
        } label: {
            StatusBarIconView(monitor: monitor)
        }
        .menuBarExtraStyle(.window)
    }
}
