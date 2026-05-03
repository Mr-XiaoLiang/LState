//
//  InfoPopoverView.swift
//  LState
//
//  Created by Lollipop on 2026/5/3.
//

import SwiftUI

struct InfoPopoverView: View {
    let monitor: SystemMonitor
    @State private var chartStyle: ChartStyle = AppSettings.shared.chartStyle
    @State private var launchAtLogin: Bool = AppSettings.shared.launchAtLogin
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 设置区域
            VStack(spacing: 12) {
                HStack {
                    Text("图表样式")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Picker("", selection: $chartStyle) {
                        Text("折线图").tag(ChartStyle.lineChart)
                        Text("条形图").tag(ChartStyle.barChart)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 120)
                    .onChange(of: chartStyle) { _, newValue in
                        AppSettings.shared.chartStyle = newValue
                    }
                }
                
                HStack {
                    Text("开机自启动")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Toggle("", isOn: $launchAtLogin)
                        .toggleStyle(.switch)
                        .scaleEffect(0.8)
                        .onChange(of: launchAtLogin) { _, newValue in
                            AppSettings.shared.launchAtLogin = newValue
                        }
                }
            }
            
            Divider()
            
            // CPU 信息
            MetricSection(
                title: "CPU",
                value: SystemMonitor.formatPercentage(monitor.metrics.cpuUsage),
                color: .red,
                history: monitor.cpuHistory
            )
            
            Divider()
            
            // 内存信息
            MetricSection(
                title: "内存",
                value: SystemMonitor.formatPercentage(monitor.metrics.memoryUsage),
                color: .yellow,
                history: monitor.memoryHistory
            )
            
            Divider()
            
            // GPU 信息
            MetricSection(
                title: "GPU",
                value: SystemMonitor.formatPercentage(monitor.metrics.gpuUsage),
                color: .green,
                history: monitor.gpuHistory
            )
            
            Divider()
            
            // 网络信息
            NetworkSection(
                uploadSpeed: monitor.metrics.uploadSpeed,
                downloadSpeed: monitor.metrics.downloadSpeed
            )
        }
        .padding()
        .frame(width: 280)
    }
}

struct MetricSection: View {
    let title: String
    let value: String
    let color: Color
    let history: [Double]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.headline)
                    .foregroundColor(color)
                
                Spacer()
                
                Text(value)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.primary)
            }
            
            // 使用 NSViewRepresentable 替代 Canvas，避免 SwiftUI 渲染缓存
            SimpleChartView(data: history, color: color)
                .frame(height: 40)
        }
    }
}

// 使用 AppKit 直接绘制，避免 SwiftUI Canvas 的内存缓存问题
struct SimpleChartView: NSViewRepresentable {
    let data: [Double]
    let color: Color
    
    func makeNSView(context: Context) -> ChartNSView {
        let view = ChartNSView()
        view.data = data
        view.chartColor = NSColor(color)
        return view
    }
    
    func updateNSView(_ nsView: ChartNSView, context: Context) {
        nsView.data = data
        nsView.chartColor = NSColor(color)
        nsView.needsDisplay = true
    }
}

class ChartNSView: NSView {
    var data: [Double] = []
    var chartColor: NSColor = .systemRed
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard data.count >= 2 else { return }
        
        let context = NSGraphicsContext.current?.cgContext
        let width = bounds.width
        let height = bounds.height
        let stepX = width / CGFloat(data.count - 1)
        
        // 绘制填充区域
        let fillPath = CGMutablePath()
        let firstValue = data[0] / 100.0
        let firstY = height - (CGFloat(firstValue) * height)
        fillPath.move(to: CGPoint(x: 0, y: 0))
        fillPath.addLine(to: CGPoint(x: 0, y: firstY))
        
        for (index, value) in data.enumerated() {
            let normalizedValue = value / 100.0
            let x = CGFloat(index) * stepX
            let y = height - (CGFloat(normalizedValue) * height)
            fillPath.addLine(to: CGPoint(x: x, y: y))
        }
        
        fillPath.addLine(to: CGPoint(x: width, y: 0))
        fillPath.closeSubpath()
        
        context?.setFillColor(chartColor.withAlphaComponent(0.2).cgColor)
        context?.addPath(fillPath)
        context?.fillPath()
        
        // 绘制折线
        context?.setStrokeColor(chartColor.cgColor)
        context?.setLineWidth(1.5)
        
        let linePath = CGMutablePath()
        linePath.move(to: CGPoint(x: 0, y: firstY))
        
        for (index, value) in data.enumerated() {
            let normalizedValue = value / 100.0
            let x = CGFloat(index) * stepX
            let y = height - (CGFloat(normalizedValue) * height)
            linePath.addLine(to: CGPoint(x: x, y: y))
        }
        
        context?.addPath(linePath)
        context?.strokePath()
    }
}

struct NetworkSection: View {
    let uploadSpeed: Double
    let downloadSpeed: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("网络")
                .font(.headline)
                .foregroundColor(.blue)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up")
                            .font(.caption)
                            .foregroundColor(.green)
                        Text("上行")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Text(SystemMonitor.formatSpeed(uploadSpeed))
                        .font(.system(.body, design: .monospaced))
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 4) {
                        Text("下行")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Image(systemName: "arrow.down")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    Text(SystemMonitor.formatSpeed(downloadSpeed))
                        .font(.system(.body, design: .monospaced))
                }
            }
        }
    }
}

#Preview {
    let monitor = SystemMonitor()
    monitor.cpuHistory = (0..<60).map { _ in Double.random(in: 20...80) }
    monitor.memoryHistory = (0..<60).map { _ in Double.random(in: 30...70) }
    monitor.gpuHistory = (0..<60).map { _ in Double.random(in: 10...50) }
    
    return InfoPopoverView(monitor: monitor)
}
