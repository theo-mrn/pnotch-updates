//
//  SystemMonitor.swift
//  PNotch
//
//  Created by Theo Morin on 17/10/2026.
//

import Foundation
import Observation

/// Live machine metrics for the System page, sampled every second while someone is watching.
@Observable
final class SystemMonitor {
    static let historyLength = 60

    private(set) var cpu: CPUUsage?
    private(set) var gpuUtilization: Double?
    private(set) var memory: MemoryUsage?
    private(set) var network: NetworkRates?
    private(set) var storage: StorageUsage?
    private(set) var battery: BatteryStatus?
    private(set) var thermalState: ProcessInfo.ThermalState = .nominal
    private(set) var uptime: TimeInterval = 0

    private(set) var cpuHistory = MetricHistory(capacity: historyLength)
    private(set) var gpuHistory = MetricHistory(capacity: historyLength)
    private(set) var memoryHistory = MetricHistory(capacity: historyLength)
    private(set) var downloadHistory = MetricHistory(capacity: historyLength)
    private(set) var uploadHistory = MetricHistory(capacity: historyLength)

    @ObservationIgnored private let interval: Duration
    @ObservationIgnored private let sampler: @Sendable () -> SystemSample
    @ObservationIgnored private var samplingTask: Task<Void, Never>?
    @ObservationIgnored private var observerCount = 0
    @ObservationIgnored private var previousSample: SystemSample?

    init(interval: Duration = .seconds(1), sampler: @escaping @Sendable () -> SystemSample = SystemMetricsReader.sample) {
        self.interval = interval
        self.sampler = sampler
    }

    /// Starts sampling for one more observer. Every call must be balanced by `stopObserving()`.
    func startObserving() {
        observerCount += 1
        guard observerCount == 1 else { return }

        resetHistory()
        samplingTask = Task { [weak self, interval, sampler] in
            while !Task.isCancelled {
                let sample = await Task.detached(priority: .utility) { sampler() }.value
                guard let self, !Task.isCancelled else { return }
                apply(sample)
                try? await Task.sleep(for: interval)
            }
        }
    }

    func stopObserving() {
        observerCount = max(observerCount - 1, 0)
        guard observerCount == 0 else { return }
        samplingTask?.cancel()
        samplingTask = nil
    }

    // MARK: Updates

    /// Rates and CPU usage need two readings: the first sample only sets the baseline for them.
    func apply(_ sample: SystemSample) {
        if let previous = previousSample {
            if let ticks = sample.cpuTicks, let previousTicks = previous.cpuTicks, let usage = ticks.usage(since: previousTicks) {
                cpu = usage
                cpuHistory.append(usage.total)
            }
            if let counters = sample.network, let previousCounters = previous.network {
                let rates = counters.rates(since: previousCounters, interval: sample.date.timeIntervalSince(previous.date))
                network = rates
                downloadHistory.append(rates.download)
                uploadHistory.append(rates.upload)
            }
        }

        if let utilization = sample.gpuUtilization {
            gpuUtilization = utilization
            gpuHistory.append(utilization)
        }
        if let memory = sample.memory {
            self.memory = memory
            memoryHistory.append(memory.fraction)
        }
        storage = sample.storage
        battery = sample.battery
        thermalState = sample.thermalState
        uptime = sample.uptime
        previousSample = sample
    }

    private func resetHistory() {
        previousSample = nil
        cpuHistory.removeAll()
        gpuHistory.removeAll()
        memoryHistory.removeAll()
        downloadHistory.removeAll()
        uploadHistory.removeAll()
    }
}
