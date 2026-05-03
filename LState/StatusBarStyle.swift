//
//  StatusBarStyle.swift
//  LState
//
//  Created by Lollipop on 2026/5/3.
//

import AppKit

// MARK: - 尺寸配置
enum StatusBarMetrics {
    static let iconWidth: CGFloat = 44
    static let iconHeight: CGFloat = 18
    static let chartHeight: CGFloat = 16
    static let bottomPadding: CGFloat = 1
    static let cornerRadius: CGFloat = 3
    static let borderWidth: CGFloat = 1.0
    static let lineWidth: CGFloat = 1.5
    static let chartInset: CGFloat = 1
}

// MARK: - 颜色配置
struct StatusBarColors {
    let cpu: NSColor
    let memory: NSColor
    let gpu: NSColor
    let border: NSColor
    let background: NSColor
    
    static var current: StatusBarColors {
        // 根据当前状态栏文字颜色判断
        // 状态栏文字是白色 -> 使用浅色颜色
        // 状态栏文字是黑色 -> 使用深色颜色
        let isStatusBarDark = NSColor.controlTextColor.usingColorSpace(.sRGB)?.brightnessComponent ?? 0 > 0.5
        return isStatusBarDark ? lightMode : darkMode
    }
    
    // 深色边框（浅色模式状态栏）：深红、暗黄、墨绿
    static let lightMode = StatusBarColors(
        cpu: NSColor(red: 0.6, green: 0.1, blue: 0.1, alpha: 1.0),
        memory: NSColor(red: 0.6, green: 0.5, blue: 0.0, alpha: 1.0),
        gpu: NSColor(red: 0.0, green: 0.4, blue: 0.2, alpha: 1.0),
        border: NSColor.controlTextColor,
        background: NSColor.controlTextColor.withAlphaComponent(0.5)
    )

    // 浅色边框（深色模式状态栏）：浅红、浅黄、蓝绿
    static let darkMode = StatusBarColors(
        cpu: NSColor(red: 1.0, green: 0.6, blue: 0.6, alpha: 1.0),
        memory: NSColor(red: 1.0, green: 0.8, blue: 0.5, alpha: 1.0),
        gpu: NSColor(red: 0.4, green: 0.9, blue: 0.8, alpha: 1.0),
        border: NSColor.controlTextColor,
        background: NSColor.controlTextColor.withAlphaComponent(0.5)
    )
}
