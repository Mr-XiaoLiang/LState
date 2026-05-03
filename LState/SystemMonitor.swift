//
//  SystemMonitor.swift
//  LState
//
//  Created by Lollipop on 2026/5/3.
//

import Foundation
import IOKit
import IOKit.ps

struct SystemMetrics {
    var cpuUsage: Double
    var memoryUsage: Double
    var gpuUsage: Double
    var uploadSpeed: Double
    var downloadSpeed: Double
    var timestamp: Date
}

@Observable
class SystemMonitor {
    private var timer: Timer?
    private var previousNetworkStats: (upload: UInt64, download: UInt64, timestamp: Date)?
    
    var metrics = SystemMetrics(
        cpuUsage: 0,
        memoryUsage: 0,
        gpuUsage: 0,
        uploadSpeed: 0,
        downloadSpeed: 0,
        timestamp: Date()
    )
    
    var cpuHistory: [Double] = Array(repeating: 0, count: 60)
    var memoryHistory: [Double] = Array(repeating: 0, count: 60)
    var gpuHistory: [Double] = Array(repeating: 0, count: 60)
    
    func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.updateMetrics()
        }
        timer?.fire()
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    private func updateMetrics() {
        let cpu = getCPUUsage()
        let memory = getMemoryUsage()
        let gpu = getGPUUsage()
        let network = getNetworkSpeed()
        
        metrics = SystemMetrics(
            cpuUsage: cpu,
            memoryUsage: memory,
            gpuUsage: gpu,
            uploadSpeed: network.upload,
            downloadSpeed: network.download,
            timestamp: Date()
        )
        
        // 更新历史数据
        cpuHistory.removeFirst()
        cpuHistory.append(cpu)
        memoryHistory.removeFirst()
        memoryHistory.append(memory)
        gpuHistory.removeFirst()
        gpuHistory.append(gpu)
    }
    
    private func getCPUUsage() -> Double {
        var cpuInfo: processor_info_array_t?
        var numCPUInfo: mach_msg_type_number_t = 0
        var numCPUs: natural_t = 0
        
        let result = host_processor_info(mach_host_self(),
                                         PROCESSOR_CPU_LOAD_INFO,
                                         &numCPUs,
                                         &cpuInfo,
                                         &numCPUInfo)
        
        guard result == KERN_SUCCESS, let info = cpuInfo else {
            return 0
        }
        
        var totalUsage: Double = 0
        for i in 0..<Int(numCPUs) {
            let user = Double(info[Int(CPU_STATE_MAX * Int32(i) + CPU_STATE_USER)])
            let system = Double(info[Int(CPU_STATE_MAX * Int32(i) + CPU_STATE_SYSTEM)])
            let idle = Double(info[Int(CPU_STATE_MAX * Int32(i) + CPU_STATE_IDLE)])
            let total = user + system + idle
            
            if total > 0 {
                totalUsage += (user + system) / total * 100
            }
        }
        
        vm_deallocate(mach_task_self_, vm_address_t(UInt(bitPattern: cpuInfo)), vm_size_t(numCPUInfo) * vm_size_t(MemoryLayout<integer_t>.size))
        
        return totalUsage / Double(numCPUs)
    }
    
    private func getMemoryUsage() -> Double {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        
        guard result == KERN_SUCCESS else {
            return 0
        }
        
        let totalMemory = Double(stats.active_count + stats.inactive_count + stats.wire_count + stats.free_count) * Double(vm_page_size)
        let usedMemory = Double(stats.active_count + stats.inactive_count + stats.wire_count) * Double(vm_page_size)
        
        return (usedMemory / totalMemory) * 100
    }
    
    private func getGPUUsage() -> Double {
        // GPU 使用率获取较为复杂，这里使用模拟值
        // 实际实现可能需要使用 IOAccelerator 框架或 Metal API
        return Double.random(in: 10...50)
    }
    
    private func getNetworkSpeed() -> (upload: Double, download: Double) {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else {
            return (0, 0)
        }
        
        var totalUpload: UInt64 = 0
        var totalDownload: UInt64 = 0
        
        var ptr = firstAddr
        while ptr.pointee.ifa_next != nil {
            let interface = ptr.pointee
            let name = String(cString: interface.ifa_name)
            
            // 只统计主要网络接口
            if name.hasPrefix("en") || name.hasPrefix("wl") {
                if let data = interface.ifa_data?.assumingMemoryBound(to: if_data.self) {
                    totalUpload += UInt64(data.pointee.ifi_obytes)
                    totalDownload += UInt64(data.pointee.ifi_ibytes)
                }
            }
            ptr = interface.ifa_next!
        }
        
        freeifaddrs(ifaddr)
        
        let now = Date()
        var uploadSpeed: Double = 0
        var downloadSpeed: Double = 0
        
        if let previous = previousNetworkStats {
            let timeInterval = now.timeIntervalSince(previous.timestamp)
            if timeInterval > 0 {
                uploadSpeed = Double(totalUpload - previous.upload) / timeInterval
                downloadSpeed = Double(totalDownload - previous.download) / timeInterval
            }
        }
        
        previousNetworkStats = (totalUpload, totalDownload, now)
        
        return (uploadSpeed, downloadSpeed)
    }
}

// MARK: - 格式化工具
extension SystemMonitor {
    static func formatSpeed(_ bytesPerSecond: Double) -> String {
        let kb = bytesPerSecond / 1024
        let mb = kb / 1024
        let gb = mb / 1024
        
        if gb >= 1 {
            return String(format: "%.1f GB/s", gb)
        } else if mb >= 1 {
            return String(format: "%.1f MB/s", mb)
        } else if kb >= 1 {
            return String(format: "%.1f KB/s", kb)
        } else {
            return String(format: "%.0f B/s", bytesPerSecond)
        }
    }
    
    static func formatPercentage(_ value: Double) -> String {
        return String(format: "%.1f%%", value)
    }
}
