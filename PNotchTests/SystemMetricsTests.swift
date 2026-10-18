//
//  SystemMetricsTests.swift
//  PNotchTests
//
//  Created by Theo Morin on 17/10/2026.
//

import Foundation
import Testing
@testable import PNotch

struct SystemMetricsTests {
    @Test func cpuUsageComesFromTickDeltas() throws {
        let before = CPUTicks(user: 100, system: 50, idle: 800, nice: 50)
        let after = CPUTicks(user: 130, system: 60, idle: 860, nice: 50)

        let usage = try #require(after.usage(since: before))
        #expect(usage.user == 0.3)
        #expect(usage.system == 0.1)
        #expect(abs(usage.total - 0.4) < 0.000_001)
    }

    @Test func cpuUsageSurvivesCounterWraparound() throws {
        let before = CPUTicks(user: UInt32.max - 9, system: 0, idle: 0, nice: 0)
        let after = CPUTicks(user: 10, system: 0, idle: 20, nice: 0)

        let usage = try #require(after.usage(since: before))
        #expect(abs(usage.user - 0.5) < 0.000_001)
    }

    @Test func noElapsedTicksMeansNoReading() {
        let ticks = CPUTicks(user: 1, system: 1, idle: 1, nice: 1)
        #expect(ticks.usage(since: ticks) == nil)
    }

    @Test func networkRatesArePerSecond() {
        let before = NetworkCounters(received: 1000, sent: 500)
        let after = NetworkCounters(received: 5000, sent: 1500)

        #expect(after.rates(since: before, interval: 2) == NetworkRates(download: 2000, upload: 500))
    }

    @Test func resetCountersCountAsNoTraffic() {
        let before = NetworkCounters(received: 9000, sent: 9000)
        let after = NetworkCounters(received: 100, sent: 100)

        #expect(after.rates(since: before, interval: 1) == NetworkRates(download: 0, upload: 0))
    }

    @Test func historyKeepsTheLatestValues() {
        var history = MetricHistory(capacity: 3)
        for value in [1.0, 2, 3, 4, 5] {
            history.append(value)
        }
        #expect(history.values == [3, 4, 5])
    }

    @Test(arguments: [
        (0.0, "0 B/s"), (850, "850 B/s"), (1234, "1.2 KB/s"), (56789, "57 KB/s"), (1_450_000, "1.4 MB/s"),
    ])
    func formatsRates(bytesPerSecond: Double, expected: String) {
        #expect(MetricFormatter.rate(bytesPerSecond, locale: Locale(identifier: "en_US")) == expected)
    }

    @Test func formatsRatesWithTheLocaleDecimalSeparator() {
        #expect(MetricFormatter.rate(1_450_000, locale: Locale(identifier: "fr_FR")).hasPrefix("1,4"))
    }

    @Test func formatsDurations() {
        #expect(MetricFormatter.percent(0.344) == "34%")
        #expect(MetricFormatter.duration(minutes: 77) == "1h 17m")
        #expect(MetricFormatter.duration(minutes: 45) == "45m")
        #expect(MetricFormatter.uptime(3 * 86400 + 4 * 3600 + 120) == "3d 4h")
        #expect(MetricFormatter.uptime(5 * 3600 + 12 * 60) == "5h 12m")
    }
}

@MainActor
struct SystemMonitorTests {
    private func sample(at seconds: TimeInterval, user: UInt32, received: UInt64) -> SystemSample {
        SystemSample(
            date: Date(timeIntervalSince1970: seconds),
            // 100 idle ticks elapse every second.
            cpuTicks: CPUTicks(user: user, system: 0, idle: UInt32(seconds * 100), nice: 0),
            memory: MemoryUsage(usedBytes: 4, totalBytes: 16, pressure: .normal),
            network: NetworkCounters(received: received, sent: 0),
            storage: nil,
            gpuUtilization: 0.2,
            battery: nil,
            thermalState: .nominal,
            uptime: 60
        )
    }

    @Test func firstSampleOnlySetsTheBaseline() {
        let monitor = SystemMonitor()
        monitor.apply(sample(at: 0, user: 0, received: 0))

        #expect(monitor.cpu == nil)
        #expect(monitor.network == nil)
        #expect(monitor.memory?.fraction == 0.25)
        #expect(monitor.gpuHistory.values == [0.2])
    }

    @Test func followingSamplesProduceUsageAndRates() {
        let monitor = SystemMonitor()
        monitor.apply(sample(at: 0, user: 0, received: 0))
        monitor.apply(sample(at: 1, user: 100, received: 3000))

        #expect(monitor.cpu?.total == 0.5)
        #expect(monitor.network?.download == 3000)
        #expect(monitor.cpuHistory.values == [0.5])
        #expect(monitor.downloadHistory.values == [3000])
    }
}

/// Reads the real machine: values must exist and be plausible.
struct SystemMetricsReaderTests {
    @Test func readsThisMac() throws {
        let sample = SystemMetricsReader.sample()

        #expect(sample.cpuTicks != nil)
        let memory = try #require(sample.memory)
        #expect(memory.totalBytes == ProcessInfo.processInfo.physicalMemory)
        #expect(memory.usedBytes > 0 && memory.usedBytes <= memory.totalBytes)
        let storage = try #require(sample.storage)
        #expect(storage.totalBytes > 0 && storage.availableBytes <= storage.totalBytes)
        if let gpu = sample.gpuUtilization {
            #expect((0 ... 1).contains(gpu))
        }
        if let battery = sample.battery {
            #expect((0 ... 1).contains(battery.level))
        }
    }
}
