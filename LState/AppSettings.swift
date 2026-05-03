//
//  AppSettings.swift
//  LState
//
//  Created by Lollipop on 2026/5/3.
//

import Foundation
import Combine

class AppSettings: ObservableObject {
    static let shared = AppSettings()
    
    @Published var chartStyle: ChartStyle = .lineChart {
        didSet {
            UserDefaults.standard.set(chartStyle == .barChart, forKey: "useBarChart")
            NotificationCenter.default.post(name: .chartStyleChanged, object: nil)
        }
    }
    
    @Published var launchAtLogin: Bool = false {
        didSet {
            UserDefaults.standard.set(launchAtLogin, forKey: "launchAtLogin")
            setLaunchAtLogin(enabled: launchAtLogin)
        }
    }
    
    private init() {
        let useBarChart = UserDefaults.standard.bool(forKey: "useBarChart")
        chartStyle = useBarChart ? .barChart : .lineChart
        launchAtLogin = isLaunchAtLoginEnabled()
    }
    
    private var launchAgentPlistPath: String {
        let libraryDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents")
        return libraryDir.appendingPathComponent("com.lollipop.LState.plist").path
    }
    
    private func isLaunchAtLoginEnabled() -> Bool {
        FileManager.default.fileExists(atPath: launchAgentPlistPath)
    }
    
    private func setLaunchAtLogin(enabled: Bool) {
        let plistPath = launchAgentPlistPath
        
        if enabled {
            do {
                // 创建 LaunchAgents 目录
                let directory = (plistPath as NSString).deletingLastPathComponent
                try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
                
                // 获取应用路径
                let appPath = Bundle.main.bundlePath
                
                // 使用 PropertyListSerialization 创建 plist（更可靠）
                let plist: [String: Any] = [
                    "Label": "com.lollipop.LState",
                    "ProgramArguments": [appPath],
                    "RunAtLoad": true,
                    "KeepAlive": false
                ]
                
                let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
                try data.write(to: URL(fileURLWithPath: plistPath))
                
                // 加载 launch agent
                let task = Process()
                task.launchPath = "/bin/launchctl"
                task.arguments = ["load", plistPath]
                task.standardOutput = FileHandle.nullDevice
                task.standardError = FileHandle.nullDevice
                try task.run()
                task.waitUntilExit()
                
                print("开机自启动已启用: \(plistPath)")
                
            } catch {
                print("启用开机自启动失败: \(error)")
                // 回滚设置
                DispatchQueue.main.async {
                    self.launchAtLogin = false
                }
            }
        } else {
            // 卸载 launch agent
            let task = Process()
            task.launchPath = "/bin/launchctl"
            task.arguments = ["unload", plistPath]
            task.standardOutput = FileHandle.nullDevice
            task.standardError = FileHandle.nullDevice
            try? task.run()
            
            // 删除 plist 文件
            try? FileManager.default.removeItem(atPath: plistPath)
            
            print("开机自启动已禁用")
        }
    }
}

extension Notification.Name {
    static let chartStyleChanged = Notification.Name("chartStyleChanged")
}
