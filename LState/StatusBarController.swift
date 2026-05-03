//
//  StatusBarController.swift
//  LState
//
//  Created by Lollipop on 2026/5/3.
//

import AppKit
import SwiftUI

class StatusBarController: NSObject {
    private var statusItem: NSStatusItem
    private let monitor: SystemMonitor
    private var timer: Timer?
    
    init(monitor: SystemMonitor) {
        self.monitor = monitor
        self.statusItem = NSStatusBar.system.statusItem(withLength: StatusBarMetrics.iconWidth)
        super.init()
        
        setupStatusBar()
        startUpdating()
        setupAppearanceObserver()
    }
    
    private func setupStatusBar() {
        statusItem.button?.target = self
        statusItem.button?.action = #selector(showPopover)
        updateStatusBarImage()
    }
    
    private func startUpdating() {
        monitor.startMonitoring()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.updateStatusBarImage()
        }
    }
    
    private func setupAppearanceObserver() {
        // 监听系统主题变化
        DistributedNotificationCenter.default.addObserver(
            self,
            selector: #selector(appearanceChanged),
            name: NSNotification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil
        )
        
        // 监听应用外观变化（包括状态栏色调）
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appearanceChanged),
            name: NSNotification.Name("NSApplicationDidChangeScreenParametersNotification"),
            object: nil
        )
    }
    
    @objc private func appearanceChanged() {
        // 延迟刷新以确保外观已更新
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.updateStatusBarImage()
        }
    }
    
    private func updateStatusBarImage() {
        let image = createStatusBarImage()
        statusItem.button?.image = image
        statusItem.button?.imagePosition = .imageOnly
        statusItem.button?.imageScaling = .scaleProportionallyDown
    }
    
    private func createStatusBarImage() -> NSImage {
        let colors = StatusBarColors.current
        let metrics = StatusBarMetrics.self
        
        let image = NSImage(size: NSSize(width: metrics.iconWidth, height: metrics.iconHeight))
        image.lockFocus()
        
        guard let context = NSGraphicsContext.current?.cgContext else {
            image.unlockFocus()
            return image
        }
        
        // 清除背景
        context.clear(CGRect(x: 0, y: 0, width: metrics.iconWidth, height: metrics.iconHeight))
        
        // 绘制背景和边框
        drawBackgroundAndBorder(context: context, colors: colors, metrics: metrics)
        
        // 绘制折线
        drawChartLines(context: context, colors: colors, metrics: metrics)
        
        image.unlockFocus()
        image.isTemplate = false
        
        return image
    }
    
    private func drawBackgroundAndBorder(
        context: CGContext,
        colors: StatusBarColors,
        metrics: StatusBarMetrics.Type
    ) {
        let rect = CGRect(
            x: 0.5,
            y: metrics.bottomPadding - 0.5,
            width: metrics.iconWidth - 1,
            height: metrics.chartHeight + 1
        )
        let path = CGPath(
            roundedRect: rect,
            cornerWidth: metrics.cornerRadius,
            cornerHeight: metrics.cornerRadius,
            transform: nil
        )
        
        // 填充背景
        context.setFillColor(colors.background.cgColor)
        context.addPath(path)
        context.fillPath()
        
        // 绘制边框
        context.setStrokeColor(colors.border.cgColor)
        context.setLineWidth(metrics.borderWidth)
        context.addPath(path)
        context.strokePath()
    }
    
    private func drawChartLines(
        context: CGContext,
        colors: StatusBarColors,
        metrics: StatusBarMetrics.Type
    ) {
        let insetHeight = metrics.chartHeight - 2 * metrics.chartInset
        let insetPadding = metrics.bottomPadding + metrics.chartInset
        let insetWidth = metrics.iconWidth - 2 * metrics.chartInset
        let stepX = insetWidth / CGFloat(monitor.cpuHistory.count - 1)
        
        drawLine(
            context: context,
            data: monitor.cpuHistory,
            color: colors.cpu,
            stepX: stepX,
            chartHeight: insetHeight,
            bottomPadding: insetPadding
        )
        
        drawLine(
            context: context,
            data: monitor.memoryHistory,
            color: colors.memory,
            stepX: stepX,
            chartHeight: insetHeight,
            bottomPadding: insetPadding
        )
        
        drawLine(
            context: context,
            data: monitor.gpuHistory,
            color: colors.gpu,
            stepX: stepX,
            chartHeight: insetHeight,
            bottomPadding: insetPadding
        )
    }
    
    private func drawLine(
        context: CGContext,
        data: [Double],
        color: NSColor,
        stepX: CGFloat,
        chartHeight: CGFloat,
        bottomPadding: CGFloat
    ) {
        guard data.count >= 2 else { return }
        
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(StatusBarMetrics.lineWidth)
        
        let firstY = bottomPadding + chartHeight - CGFloat(data[0] / 100.0) * chartHeight
        context.move(to: CGPoint(x: StatusBarMetrics.chartInset, y: firstY))
        
        for (index, value) in data.enumerated() {
            let x = StatusBarMetrics.chartInset + CGFloat(index) * stepX
            let y = bottomPadding + chartHeight - CGFloat(value / 100.0) * chartHeight
            context.addLine(to: CGPoint(x: x, y: y))
        }
        
        context.strokePath()
    }
    
    @objc private func showPopover() {
        guard let button = statusItem.button else { return }
        
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 280, height: 400)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: InfoPopoverView(monitor: monitor)
        )
        
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }
    
    deinit {
        timer?.invalidate()
        monitor.stopMonitoring()
        DistributedNotificationCenter.default.removeObserver(self)
    }
}
