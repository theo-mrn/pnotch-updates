//
//  SystemMetricsReader.swift
//  PNotch
//
//  Created by Theo Morin on 17/10/2026.
//

import Darwin
import Foundation
import IOKit
import IOKit.ps

/// Reads the machine's metrics with public APIs (Mach, sysctl, IOKit). Each read takes microseconds
/// to a couple of milliseconds; they still run off the main actor.
nonisolated enum SystemMetricsReader {
    private static let host = mach_host_self()

    static func sample() -> SystemSample {
        SystemSample(
            date: .now,
            cpuTicks: cpuTicks(),
            memory: memory(),
            network: networkCounters(),
            storage: storage(),
            gpuUtilization: gpuUtilization(),
            battery: battery(),
            thermalState: ProcessInfo.processInfo.thermalState,
            uptime: ProcessInfo.processInfo.systemUptime
        )
    }

    // MARK: CPU

    static func cpuTicks() -> CPUTicks? {
        var info = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(host, HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        // Order of `cpu_ticks`: CPU_STATE_USER, CPU_STATE_SYSTEM, CPU_STATE_IDLE, CPU_STATE_NICE.
        return CPUTicks(user: info.cpu_ticks.0, system: info.cpu_ticks.1, idle: info.cpu_ticks.2, nice: info.cpu_ticks.3)
    }

    // MARK: Memory

    static func memory() -> MemoryUsage? {
        var statistics = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &statistics) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(host, HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }

        let pageSize = UInt64(getpagesize())
        let appPages = UInt64(statistics.internal_page_count) - min(UInt64(statistics.purgeable_count), UInt64(statistics.internal_page_count))
        let usedPages = appPages + UInt64(statistics.wire_count) + UInt64(statistics.compressor_page_count)
        return MemoryUsage(
            usedBytes: usedPages * pageSize,
            totalBytes: ProcessInfo.processInfo.physicalMemory,
            pressure: memoryPressure()
        )
    }

    private static func memoryPressure() -> MemoryPressure {
        var level: Int32 = 0
        var size = MemoryLayout<Int32>.size
        guard sysctlbyname("kern.memorystatus_vm_pressure_level", &level, &size, nil, 0) == 0 else { return .normal }
        switch level {
        case 4: return .critical
        case 2: return .warning
        default: return .normal
        }
    }

    // MARK: Network

    /// Sums the 64-bit counters of the Ethernet and Wi-Fi interfaces (`en*`). Virtual interfaces
    /// (VPN tunnels, bridges) are left out so their traffic isn't counted twice.
    static func networkCounters() -> NetworkCounters? {
        var mib: [Int32] = [CTL_NET, PF_ROUTE, 0, 0, NET_RT_IFLIST2, 0]
        var length = 0
        guard sysctl(&mib, u_int(mib.count), nil, &length, nil, 0) == 0, length > 0 else { return nil }

        var buffer = [UInt8](repeating: 0, count: length)
        guard sysctl(&mib, u_int(mib.count), &buffer, &length, nil, 0) == 0 else { return nil }

        var counters = NetworkCounters(received: 0, sent: 0)
        buffer.withUnsafeBytes { raw in
            var offset = 0
            while offset + MemoryLayout<if_msghdr>.size <= length {
                let header = raw.loadUnaligned(fromByteOffset: offset, as: if_msghdr.self)
                guard header.ifm_msglen > 0 else { break }

                if Int32(header.ifm_type) == RTM_IFINFO2, offset + MemoryLayout<if_msghdr2>.size <= length {
                    let message = raw.loadUnaligned(fromByteOffset: offset, as: if_msghdr2.self)
                    if interfaceName(at: UInt32(message.ifm_index)).hasPrefix("en") {
                        counters.received += message.ifm_data.ifi_ibytes
                        counters.sent += message.ifm_data.ifi_obytes
                    }
                }
                offset += Int(header.ifm_msglen)
            }
        }
        return counters
    }

    private static func interfaceName(at index: UInt32) -> String {
        var name = [CChar](repeating: 0, count: Int(IF_NAMESIZE))
        guard if_indextoname(index, &name) != nil else { return "" }
        return String(decoding: name.prefix { $0 != 0 }.map(UInt8.init(bitPattern:)), as: UTF8.self)
    }

    // MARK: Storage

    static func storage() -> StorageUsage? {
        let keys: Set<URLResourceKey> = [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey]
        guard let values = try? URL(fileURLWithPath: "/").resourceValues(forKeys: keys),
              let total = values.volumeTotalCapacity,
              let available = values.volumeAvailableCapacityForImportantUsage
        else { return nil }
        return StorageUsage(availableBytes: available, totalBytes: Int64(total))
    }

    // MARK: GPU

    /// Utilization reported by the graphics driver in the IORegistry, 0...1.
    static func gpuUtilization() -> Double? {
        var iterator = io_iterator_t()
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOAccelerator"), &iterator) == KERN_SUCCESS else {
            return nil
        }
        defer { IOObjectRelease(iterator) }

        var service = IOIteratorNext(iterator)
        while service != 0 {
            defer {
                IOObjectRelease(service)
                service = IOIteratorNext(iterator)
            }
            let property = IORegistryEntryCreateCFProperty(service, "PerformanceStatistics" as CFString, kCFAllocatorDefault, 0)
            if let statistics = property?.takeRetainedValue() as? [String: Any],
               let utilization = statistics["Device Utilization %"] as? Int {
                return min(max(Double(utilization) / 100, 0), 1)
            }
        }
        return nil
    }

    // MARK: Battery

    /// Whether this Mac has a battery. It doesn't change while the app runs.
    static let hasBattery = battery() != nil

    /// `nil` on Macs without a battery.
    static func battery() -> BatteryStatus? {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef]
        else { return nil }

        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
                  description[kIOPSTypeKey] as? String == kIOPSInternalBatteryType,
                  let current = description[kIOPSCurrentCapacityKey] as? Int,
                  let maximum = description[kIOPSMaxCapacityKey] as? Int, maximum > 0
            else { continue }

            let isCharging = description[kIOPSIsChargingKey] as? Bool ?? false
            let remainingKey = isCharging ? kIOPSTimeToFullChargeKey : kIOPSTimeToEmptyKey
            let minutes = description[remainingKey] as? Int
            return BatteryStatus(
                level: min(Double(current) / Double(maximum), 1),
                isCharging: isCharging,
                isPluggedIn: description[kIOPSPowerSourceStateKey] as? String == kIOPSACPowerValue,
                minutesRemaining: minutes.flatMap { $0 > 0 ? $0 : nil }
            )
        }
        return nil
    }
}
