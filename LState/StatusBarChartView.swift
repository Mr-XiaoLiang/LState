//
//  StatusBarChartView.swift
//  LState
//
//  Created by Lollipop on 2026/5/3.
//

import SwiftUI

struct StatusBarChartView: View {
    let cpuHistory: [Double]
    let memoryHistory: [Double]
    let gpuHistory: [Double]
    
    private let chartWidth: CGFloat = 44
    private let chartHeight: CGFloat = 22
    
    var body: some View {
        Canvas { context, size in
            guard cpuHistory.count >= 2 else { return }
            
            let stepX = chartWidth / CGFloat(cpuHistory.count - 1)
            
            // 绘制 CPU（红色）
            drawLine(context: context, data: cpuHistory, color: .red, stepX: stepX)
            
            // 绘制 内存（黄色）
            drawLine(context: context, data: memoryHistory, color: .yellow, stepX: stepX)
            
            // 绘制 GPU（绿色）
            drawLine(context: context, data: gpuHistory, color: .green, stepX: stepX)
        }
        .frame(width: chartWidth, height: chartHeight)
    }
    
    private func drawLine(
        context: GraphicsContext,
        data: [Double],
        color: Color,
        stepX: CGFloat
    ) {
        guard data.count >= 2 else { return }
        
        var path = Path()
        let firstValue = data[0] / 100.0
        let firstY = chartHeight - (CGFloat(firstValue) * chartHeight)
        path.move(to: CGPoint(x: 0, y: firstY))
        
        for (index, value) in data.enumerated() {
            let normalizedValue = value / 100.0
            let x = CGFloat(index) * stepX
            let y = chartHeight - (CGFloat(normalizedValue) * chartHeight)
            path.addLine(to: CGPoint(x: x, y: y))
        }
        
        context.stroke(path, with: .color(color), lineWidth: 1)
    }
}

struct NetworkSpeedView: View {
    let uploadSpeed: Double
    let downloadSpeed: Double
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 0) {
            // 上行（上方）
            HStack(spacing: 2) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 6))
                Text(formatSpeed(uploadSpeed))
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
            }
            .foregroundColor(.primary)
            .frame(height: 11)
            
            // 下行（下方）
            HStack(spacing: 2) {
                Image(systemName: "arrow.down")
                    .font(.system(size: 6))
                Text(formatSpeed(downloadSpeed))
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
            }
            .foregroundColor(.primary)
            .frame(height: 11)
        }
        .frame(height: 22)
    }
    
    private func formatSpeed(_ bytesPerSecond: Double) -> String {
        let kb = bytesPerSecond / 1024
        let mb = kb / 1024
        let gb = mb / 1024
        
        if gb >= 1 {
            return String(format: "%.1fG", gb)
        } else if mb >= 1 {
            return String(format: "%.1fM", mb)
        } else if kb >= 1 {
            return String(format: "%.1fK", kb)
        } else {
            return String(format: "%.0fB", bytesPerSecond)
        }
    }
}

struct StatusBarIconView: View {
    let monitor: SystemMonitor
    
    var body: some View {
        HStack(spacing: 4) {
            StatusBarChartView(
                cpuHistory: monitor.cpuHistory,
                memoryHistory: monitor.memoryHistory,
                gpuHistory: monitor.gpuHistory
            )
            
            NetworkSpeedView(
                uploadSpeed: monitor.metrics.uploadSpeed,
                downloadSpeed: monitor.metrics.downloadSpeed
            )
        }
        .padding(.horizontal, 4)
    }
}

#Preview {
    let monitor = SystemMonitor()
    monitor.cpuHistory = (0..<60).map { _ in Double.random(in: 20...80) }
    monitor.memoryHistory = (0..<60).map { _ in Double.random(in: 30...70) }
    monitor.gpuHistory = (0..<60).map { _ in Double.random(in: 10...50) }
    
    return StatusBarIconView(monitor: monitor)
}
