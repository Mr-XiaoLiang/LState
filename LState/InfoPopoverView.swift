//
//  InfoPopoverView.swift
//  LState
//
//  Created by Lollipop on 2026/5/3.
//

import SwiftUI

struct InfoPopoverView: View {
    let monitor: SystemMonitor
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
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
            
            // 详细折线图
            DetailedChartView(data: history, color: color)
                .frame(height: 40)
        }
    }
}

struct DetailedChartView: View {
    let data: [Double]
    let color: Color
    
    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                guard data.count >= 2 else { return }
                
                let stepX = size.width / CGFloat(data.count - 1)
                
                // 绘制填充区域
                var fillPath = Path()
                let firstValue = data[0] / 100.0
                let firstY = size.height - (CGFloat(firstValue) * size.height)
                fillPath.move(to: CGPoint(x: 0, y: size.height))
                fillPath.addLine(to: CGPoint(x: 0, y: firstY))
                
                for (index, value) in data.enumerated() {
                    let normalizedValue = value / 100.0
                    let x = CGFloat(index) * stepX
                    let y = size.height - (CGFloat(normalizedValue) * size.height)
                    fillPath.addLine(to: CGPoint(x: x, y: y))
                }
                
                fillPath.addLine(to: CGPoint(x: size.width, y: size.height))
                fillPath.closeSubpath()
                
                context.fill(fillPath, with: .color(color.opacity(0.2)))
                
                // 绘制折线
                var linePath = Path()
                linePath.move(to: CGPoint(x: 0, y: firstY))
                
                for (index, value) in data.enumerated() {
                    let normalizedValue = value / 100.0
                    let x = CGFloat(index) * stepX
                    let y = size.height - (CGFloat(normalizedValue) * size.height)
                    linePath.addLine(to: CGPoint(x: x, y: y))
                }
                
                context.stroke(linePath, with: .color(color), lineWidth: 1.5)
            }
        }
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
