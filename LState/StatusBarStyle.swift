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
    
    // 根据外观获取颜色配置
    static func forAppearance(_ appearance: NSAppearance) -> StatusBarColors {
        let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        return isDark ? darkMode : lightMode
    }
    
    // 浅色模式状态栏（深色边框）：浅红、浅黄、蓝绿
    static let lightMode = StatusBarColors(
        cpu: NSColor(red: 1.0, green: 0.6, blue: 0.6, alpha: 1.0),
        memory: NSColor(red: 1.0, green: 0.8, blue: 0.5, alpha: 1.0),
        gpu: NSColor(red: 0.4, green: 0.9, blue: 0.8, alpha: 1.0),
        border: NSColor.black,
        background: NSColor.black.withAlphaComponent(0.5)
    )

    // 深色模式状态栏（浅色边框）：莫奈色系 - 暗玫瑰、暗金、暗青
    static let darkMode = StatusBarColors(
        cpu: NSColor(red: 0.55, green: 0.25, blue: 0.25, alpha: 1.0),
        memory: NSColor(red: 0.55, green: 0.45, blue: 0.20, alpha: 1.0),
        gpu: NSColor(red: 0.15, green: 0.40, blue: 0.38, alpha: 1.0),
        border: NSColor.white,
        background: NSColor.white.withAlphaComponent(0.5)
    )
}
