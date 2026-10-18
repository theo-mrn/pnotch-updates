//
//  SystemMetrics.swift
//  PNotch
//
//  Created by Theo Morin on 17/10/2026.
//

import Foundation

/// Cumulative CPU time counters, in scheduler ticks. Usage is the difference between two readings.
nonisolated struct CPUTicks: Equatable, Sendable {
    var user: UInt32
    var system: UInt32
    var idle: UInt32
    var nice: UInt32

    /// Share of the time spent working since `previous`, split between apps and the system.
    func usage(since previous: CPUTicks) -> CPUUsage? {
        // Counters are 32-bit and wrap on long uptimes: wrapping subtraction keeps the delta right.
        let user = Double(self.user &- previous.user) + Double(nice &- previous.nice)
        let system = Double(self.system &- previous.system)
        let idle = Double(self.idle &- previous.idle)
        let total = user + system + idle
        guard total > 0 else { return nil }
        return CPUUsage(user: user / total, system: system / total)
    }
}

nonisolated struct CPUUsage: Equatable, Sendable {
    var user: Double
    var system: Double

    var total: Double {
        min(user + system, 1)
    }
}

nonisolated enum MemoryPressure: Equatable, Sendable {
    case normal
    case warning
    case critical
}

nonisolated struct MemoryUsage: Equatable, Sendable {
    /// App memory, wired and compressed, as Activity Monitor counts "Memory Used".
    var usedBytes: UInt64
    var totalBytes: UInt64
    var pressure: MemoryPressure

    var fraction: Double {
        totalBytes > 0 ? min(Double(usedBytes) / Double(totalBytes), 1) : 0
    }
}

/// Cumulative bytes received and sent by the physical network interfaces.
nonisolated struct NetworkCounters: Equatable, Sendable {
    var received: UInt64
    var sent: UInt64

    /// Throughput since `previous`, in bytes per second. A counter that went backwards
    /// (an interface came back up) counts as no traffic.
    func rates(since previous: NetworkCounters, interval: TimeInterval) -> NetworkRates {
        guard interval > 0 else { return NetworkRates(download: 0, upload: 0) }
        let received = self.received >= previous.received ? self.received - previous.received : 0
        let sent = self.sent >= previous.sent ? self.sent - previous.sent : 0
        return NetworkRates(download: Double(received) / interval, upload: Double(sent) / interval)
    }
}

nonisolated struct NetworkRates: Equatable, Sendable {
    var download: Double
    var upload: Double
}

nonisolated struct StorageUsage: Equatable, Sendable {
    var availableBytes: Int64
    var totalBytes: Int64

    var usedFraction: Double {
        totalBytes > 0 ? min(max(Double(totalBytes - availableBytes) / Double(totalBytes), 0), 1) : 0
    }
}

nonisolated struct BatteryStatus: Equatable, Sendable {
    /// 0...1
    var level: Double
    var isCharging: Bool
    var isPluggedIn: Bool
    /// Minutes until empty (on battery) or full (charging), when macOS has an estimate.
    var minutesRemaining: Int?
}

/// One reading of every metric, taken off the main actor.
nonisolated struct SystemSample: Sendable {
    var date: Date
    var cpuTicks: CPUTicks?
    var memory: MemoryUsage?
    var network: NetworkCounters?
    var storage: StorageUsage?
    var gpuUtilization: Double?
    var battery: BatteryStatus?
    var thermalState: ProcessInfo.ThermalState
    var uptime: TimeInterval
}

/// Fixed-size history feeding the sparklines: the oldest value goes when a new one arrives.
nonisolated struct MetricHistory: Equatable, Sendable {
    let capacity: Int
    private(set) var values: [Double] = []

    init(capacity: Int) {
        self.capacity = max(1, capacity)
    }

    mutating func append(_ value: Double) {
        values.append(value)
        if values.count > capacity {
            values.removeFirst(values.count - capacity)
        }
    }

    mutating func removeAll() {
        values.removeAll()
    }
}
