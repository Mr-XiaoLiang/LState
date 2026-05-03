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
    private var currentStyle: ChartStyle {
        get { AppSettings.shared.chartStyle }
    }
    
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
    
    private var appearanceObserver: NSKeyValueObservation?
    
    private func setupAppearanceObserver() {
        // 监听系统主题变化
        DistributedNotificationCenter.default.addObserver(
            self,
            selector: #selector(appearanceChanged),
            name: NSNotification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil
        )
        
        // KVO 监听状态栏按钮外观变化
        appearanceObserver = statusItem.button?.observe(\.effectiveAppearance, options: [.new, .initial]) { [weak self] _, _ in
            self?.appearanceChanged()
        }
        
        // 监听图表样式变化
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(styleChanged),
            name: .chartStyleChanged,
            object: nil
        )
    }
    
    @objc private func styleChanged() {
        DispatchQueue.main.async { [weak self] in
            self?.updateStatusBarImage()
        }
    }
    
    @objc private func appearanceChanged() {
        DispatchQueue.main.async { [weak self] in
            self?.updateStatusBarImage()
        }
    }
    
    private func updateStatusBarImage() {
        let appearance = statusItem.button?.effectiveAppearance ?? NSAppearance.current ?? .init(named: .aqua)!
        let image = createStatusBarImage(with: appearance)
        statusItem.button?.image = image
        statusItem.button?.imagePosition = .imageOnly
        statusItem.button?.imageScaling = .scaleProportionallyDown
    }
    
    private func createStatusBarImage(with appearance: NSAppearance) -> NSImage {
        let styleConfig = StatusBarStyle.configuration(for: currentStyle, appearance: appearance)
        let colors = styleConfig.colors
        let metrics = StatusBarMetrics.self
        
        let image = NSImage(size: NSSize(width: metrics.iconWidth, height: metrics.iconHeight))
        image.lockFocus()
        
        guard let context = NSGraphicsContext.current?.cgContext else {
            image.unlockFocus()
            return image
        }
        
        // 清除背景
        context.clear(CGRect(x: 0, y: 0, width: metrics.iconWidth, height: metrics.iconHeight))
        
        // 根据样式决定是否绘制背景和边框
        switch currentStyle {
        case .lineChart:
            drawBackgroundAndBorder(context: context, colors: colors, metrics: metrics)
            drawChartLines(context: context, colors: colors, metrics: metrics)
        case .barChart:
            drawBarChart(context: context, colors: colors)
        }
        
        // 绘制网速
        drawNetworkSpeed(context: context)
        
        image.unlockFocus()
        image.isTemplate = false
        
        return image
    }
    
    private func drawBackgroundAndBorder(
        context: CGContext,
        colors: StyleColors,
        metrics: StatusBarMetrics.Type
    ) {
        let rect = CGRect(
            x: 0.5,
            y: metrics.bottomPadding - 0.5,
            width: metrics.chartWidth - 1,
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
        colors: StyleColors,
        metrics: StatusBarMetrics.Type
    ) {
        let insetHeight = metrics.chartHeight - 2 * metrics.chartInset
        let insetPadding = metrics.bottomPadding + metrics.chartInset
        let insetWidth = metrics.chartWidth - 2 * metrics.chartInset
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
    
    private func drawBarChart(
        context: CGContext,
        colors: StyleColors
    ) {
        let barHeight = BarChartMetrics.barHeight
        let spacing = BarChartMetrics.barSpacing
        let labelWidth: CGFloat = 6.0
        let inset: CGFloat = 1.0
        let maxBarWidth = StatusBarMetrics.chartWidth - labelWidth - 2 * inset
        
        // 获取当前值（取最新数据，如果没有则取0）
        let cpuValue = monitor.cpuHistory.last ?? 0
        let gpuValue = monitor.gpuHistory.last ?? 0
        let memoryValue = monitor.memoryHistory.last ?? 0
        
        // 从下往上绘制：内存(M)、GPU(G)、CPU(C)
        let items = [
            (value: memoryValue, color: colors.memory, label: "M"),
            (value: gpuValue, color: colors.gpu, label: "G"),
            (value: cpuValue, color: colors.cpu, label: "C")
        ]
        
        for (index, item) in items.enumerated() {
            let y = StatusBarMetrics.bottomPadding + CGFloat(index) * (barHeight + spacing)
            let barWidth = maxBarWidth * CGFloat(item.value / 100.0)
            
            // 绘制标签
            let labelRect = CGRect(x: inset, y: y, width: labelWidth, height: barHeight)
            drawLabel(context: context, text: item.label, rect: labelRect, color: item.color)
            
            let barX = inset + labelWidth
            
            // 绘制背景槽（30%透明度）
            let trackRect = CGRect(
                x: barX,
                y: y,
                width: maxBarWidth,
                height: barHeight
            )
            context.setFillColor(item.color.withAlphaComponent(0.3).cgColor)
            context.fill(trackRect)
            
            // 绘制实际数值条形
            let barRect = CGRect(
                x: barX,
                y: y,
                width: barWidth,
                height: barHeight
            )
            context.setFillColor(item.color.cgColor)
            context.fill(barRect)
        }
    }
    
    private func drawLabel(
        context: CGContext,
        text: String,
        rect: CGRect,
        color: NSColor
    ) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 5),
            .foregroundColor: color
        ]
        
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let line = CTLineCreateWithAttributedString(attributedString)
        
        // 计算文字尺寸以居中显示
        let bounds = CTLineGetBoundsWithOptions(line, .useOpticalBounds)
        let x = rect.midX - bounds.width / 2
        let y = rect.midY - bounds.height / 2 - bounds.origin.y
        
        context.saveGState()
        context.textPosition = CGPoint(x: x, y: y)
        CTLineDraw(line, context)
        context.restoreGState()
    }
    
    private func drawNetworkSpeed(context: CGContext) {
        let uploadText = formatSpeed(monitor.metrics.uploadSpeed)
        let downloadText = formatSpeed(monitor.metrics.downloadSpeed)
        
        let x = StatusBarMetrics.chartWidth
        let width = StatusBarMetrics.networkWidth
        let height = StatusBarMetrics.iconHeight
        
        // 上行文字位置（上半部分）
        let uploadRect = CGRect(x: x, y: height / 2, width: width, height: height / 2)
        drawNetworkText(context: context, text: uploadText, rect: uploadRect)
        
        // 下行文字位置（下半部分）
        let downloadRect = CGRect(x: x, y: 0, width: width, height: height / 2)
        drawNetworkText(context: context, text: downloadText, rect: downloadRect)
    }
    
    private func drawNetworkText(context: CGContext, text: String, rect: CGRect) {
        // 使用加粗字体
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: NetworkMetrics.fontSize, weight: .bold),
            .foregroundColor: NetworkMetrics.textColor
        ]
        
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let line = CTLineCreateWithAttributedString(attributedString)
        
        let bounds = CTLineGetBoundsWithOptions(line, .useOpticalBounds)
        let x = rect.minX + (rect.width - bounds.width) / 2
        let y = rect.midY - bounds.height / 2 - bounds.origin.y
        
        context.saveGState()
        context.textPosition = CGPoint(x: x, y: y)
        CTLineDraw(line, context)
        context.restoreGState()
    }
    
    private func formatSpeed(_ bytesPerSecond: Double) -> String {
        let units = [("K", 1024.0), ("M", 1024.0 * 1024.0), ("G", 1024.0 * 1024.0 * 1024.0)]
        let maxChars = NetworkMetrics.maxChars
        
        // 小于 1KB: " 123B/s" (6字符)
        if bytesPerSecond < 1024 {
            let value = Int(bytesPerSecond)
            return String(format: "%3dB/s", value)
        }
        
        // 找到合适的单位
        for (index, (unit, divisor)) in units.enumerated() {
            let value = bytesPerSecond / divisor
            let nextDivisor = index < units.count - 1 ? units[index + 1].1 : Double.infinity
            
            if bytesPerSecond < nextDivisor {
                // 计算格式: X.XXU/s, XX.XU/s, XXXU/s
                // 小数点和单位都算字符
                if value < 10 {
                    // 1-9.99: "1.23k/s" (7字符) 或 "1.2k/s" (6字符)
                    // 尝试两位小数，如果超长则一位小数
                    let withTwoDecimal = String(format: "%.2f%@/s", value, unit)
                    if withTwoDecimal.count <= maxChars {
                        return withTwoDecimal
                    }
                    return String(format: "%.1f%@/s", value, unit)
                } else if value < 100 {
                    // 10-99.9: "12.3k/s" (7字符) 或 "12k/s" (5字符)
                    let withOneDecimal = String(format: "%.1f%@/s", value, unit)
                    if withOneDecimal.count <= maxChars {
                        return withOneDecimal
                    }
                    return String(format: "%d%@/s", Int(value), unit)
                } else if value < 1000 {
                    // 100-999: "123k/s" (6字符)
                    return String(format: "%d%@/s", Int(value), unit)
                }
            }
        }
        
        // 超过 1TB/s（不太可能）
        return "999G/s"
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
        NotificationCenter.default.removeObserver(self)
        appearanceObserver?.invalidate()
    }
}
