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
    // 每个接口的上次采样数据
    private var lastInterfaceSamples: [String: (upload: UInt64, download: UInt64, timestamp: Date)] = [:]
    
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
        
        // 更新历史数据：移除最旧的，添加最新的
        cpuHistory.removeFirst()
        cpuHistory.append(cpu)
        memoryHistory.removeFirst()
        memoryHistory.append(memory)
        gpuHistory.removeFirst()
        gpuHistory.append(gpu)
        
        // 更新当前指标
        metrics = SystemMetrics(
            cpuUsage: cpu,
            memoryUsage: memory,
            gpuUsage: gpu,
            uploadSpeed: network.upload,
            downloadSpeed: network.download,
            timestamp: Date()
        )
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
        
        // 获取物理内存总量
        let totalMemory = Double(getPhysicalMemory())
        
        // 计算实际使用的内存（类似活动监视器的"已使用"）
        // active: 活跃内存
        // wire: 系统保留内存（无法被交换）
        // compressed: 压缩内存（如果可用）
        let active = Double(stats.active_count) * Double(vm_page_size)
        let wired = Double(stats.wire_count) * Double(vm_page_size)
        let compressed = Double(stats.compressor_page_count) * Double(vm_page_size)
        
        let usedMemory = active + wired + compressed
        
        return (usedMemory / totalMemory) * 100
    }
    
    private func getPhysicalMemory() -> UInt64 {
        var size: UInt64 = 0
        var sizeLen = mach_msg_type_number_t(MemoryLayout<UInt64>.size / MemoryLayout<integer_t>.size)
        
        let result = withUnsafeMutablePointer(to: &size) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(sizeLen)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &sizeLen)
            }
        }
        
        // 如果上面的方法失败，使用 sysctl 获取
        if result != KERN_SUCCESS {
            var mib: [Int32] = [CTL_HW, HW_MEMSIZE]
            var len = MemoryLayout<UInt64>.size
            sysctl(&mib, 2, &size, &len, nil, 0)
        }
        
        return size > 0 ? size : 16 * 1024 * 1024 * 1024 // 默认16GB
    }
    
    private func getGPUUsage() -> Double {
        // GPU 使用率获取较为复杂，这里使用模拟值
        // 实际实现可能需要使用 IOAccelerator 框架或 Metal API
        return Double.random(in: 10...50)
    }
    
    // 缓存活跃接口列表，每10秒更新一次
    private var activeInterfaces: [String] = []
    private var lastInterfaceRefresh = Date.distantPast
    
    private func getNetworkSpeed() -> (upload: Double, download: Double) {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else {
            return (0, 0)
        }
        
        let now = Date()
        var totalUploadSpeed: Double = 0
        var totalDownloadSpeed: Double = 0
        
        // 每10秒刷新一次活跃接口列表
        let shouldRefreshInterfaces = now.timeIntervalSince(lastInterfaceRefresh) > 10
        var newActiveInterfaces: [String]?
        if shouldRefreshInterfaces {
            newActiveInterfaces = []
        }
        
        var ptr = firstAddr
        while ptr.pointee.ifa_next != nil {
            let interface = ptr.pointee
            let name = String(cString: interface.ifa_name)
            
            // 只统计主要网络接口
            if name.hasPrefix("en") || name.hasPrefix("wl") {
                if shouldRefreshInterfaces {
                    newActiveInterfaces?.append(name)
                }
                
                // 只处理已知的活跃接口（避免每次扫描所有接口）
                guard activeInterfaces.isEmpty || activeInterfaces.contains(name) else {
                    ptr = interface.ifa_next!
                    continue
                }
                
                if let data = interface.ifa_data?.assumingMemoryBound(to: if_data.self) {
                    let upload = UInt64(data.pointee.ifi_obytes)
                    let download = UInt64(data.pointee.ifi_ibytes)
                    
                    // 计算单个接口的速度
                    if let lastSample = lastInterfaceSamples[name] {
                        let timeInterval = now.timeIntervalSince(lastSample.timestamp)
                        // 合理的时间范围：0.1秒到10秒
                        if timeInterval > 0.1 && timeInterval < 10 {
                            // 正常情况：当前值 >= 上次值
                            if upload >= lastSample.upload && download >= lastSample.download {
                                let uploadDiff = upload - lastSample.upload
                                let downloadDiff = download - lastSample.download
                                totalUploadSpeed += Double(uploadDiff) / timeInterval
                                totalDownloadSpeed += Double(downloadDiff) / timeInterval
                            }
                        }
                    }
                    
                    // 更新该接口的采样数据
                    lastInterfaceSamples[name] = (upload, download, now)
                }
            }
            ptr = interface.ifa_next!
        }
        
        freeifaddrs(ifaddr)
        
        // 更新活跃接口列表
        if shouldRefreshInterfaces, let interfaces = newActiveInterfaces {
            activeInterfaces = interfaces
            lastInterfaceRefresh = now
            
            // 清理不再活跃的接口数据
            let activeSet = Set(interfaces)
            lastInterfaceSamples = lastInterfaceSamples.filter { name, _ in
                activeSet.contains(name)
            }
        }
        
        return (totalUploadSpeed, totalDownloadSpeed)
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
