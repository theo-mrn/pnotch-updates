//
//  SystemView.swift
//  PNotch
//
//  Created by Theo Morin on 17/10/2026.
//

import SwiftUI

/// The system page of the opened notch: live CPU, GPU, memory, network, storage and battery.
/// Sampling runs only while the page is on screen.
struct SystemView: View {
    @Environment(SystemMonitor.self) private var monitor

    var body: some View {
        VStack(spacing: 0) {
            NotchHeaderView()

            HStack(spacing: SystemMetricsLayout.tileSpacing) {
                CPUTile()
                GPUTile()
                MemoryTile()
                NetworkTile()
                StorageTile()
                if SystemMetricsReader.hasBattery {
                    BatteryTile()
                } else {
                    UptimeTile()
                }
            }
            .padding(.horizontal, SystemMetricsLayout.horizontalPadding)
            .frame(height: SystemMetricsLayout.bodyHeight)
        }
        .onAppear { monitor.startObserving() }
        .onDisappear { monitor.stopObserving() }
    }
}

// MARK: - Palette

enum MetricColor {
    static let cpu = Color(hex: 0x4C8DFF)
    static let gpu = Color(hex: 0xB07CFF)
    static let good = Color(hex: 0x34C77B)
    static let warning = Color(hex: 0xF5C451)
    static let critical = Color(hex: 0xFF5F57)
    static let download = Color(hex: 0x40C8E0)
    static let upload = Color(hex: 0xFF9F43)
    static let storage = Color(hex: 0x8E9BB0)
}

// MARK: - Tiles

private struct CPUTile: View {
    @Environment(SystemMonitor.self) private var monitor

    var body: some View {
        MetricTile(title: "CPU", systemImage: "cpu", tint: MetricColor.cpu, detail: detail) {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                MetricValueText(text: monitor.cpu.map { MetricFormatter.percent($0.total) } ?? "—")
                if let thermal = thermalWarning {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(thermal)
                        .help("The Mac is running hot")
                }
            }
        } footer: {
            MetricSparkline(values: monitor.cpuHistory.values, color: MetricColor.cpu)
        }
    }

    private var detail: String {
        guard let cpu = monitor.cpu else { return String(localized: "Measuring…") }
        return String(localized: "User \(MetricFormatter.percent(cpu.user)) · Sys \(MetricFormatter.percent(cpu.system))")
    }

    private var thermalWarning: Color? {
        switch monitor.thermalState {
        case .serious: MetricColor.upload
        case .critical: MetricColor.critical
        default: nil
        }
    }
}

private struct GPUTile: View {
    @Environment(SystemMonitor.self) private var monitor

    var body: some View {
        MetricTile(title: "GPU", systemImage: "square.3.layers.3d", tint: MetricColor.gpu, detail: detail) {
            MetricValueText(text: monitor.gpuUtilization.map(MetricFormatter.percent) ?? "—")
        } footer: {
            MetricSparkline(values: monitor.gpuHistory.values, color: MetricColor.gpu)
        }
    }

    private var detail: String {
        guard let peak = monitor.gpuHistory.values.max() else { return String(localized: "Unavailable") }
        return String(localized: "Peak \(MetricFormatter.percent(peak)) · 1 min")
    }
}

private struct MemoryTile: View {
    @Environment(SystemMonitor.self) private var monitor

    var body: some View {
        MetricTile(title: "Memory", systemImage: "memorychip", tint: tint, detail: detail) {
            MetricValueText(text: monitor.memory.map { MetricFormatter.percent($0.fraction) } ?? "—")
        } footer: {
            MetricSparkline(values: monitor.memoryHistory.values, color: tint)
        }
    }

    private var detail: String {
        guard let memory = monitor.memory else { return "" }
        return String(localized: "\(MetricFormatter.memory(memory.usedBytes)) of \(MetricFormatter.memory(memory.totalBytes))")
    }

    /// Colored by memory pressure, which says more than the raw percentage.
    private var tint: Color {
        switch monitor.memory?.pressure {
        case .warning: MetricColor.warning
        case .critical: MetricColor.critical
        default: MetricColor.good
        }
    }
}

private struct NetworkTile: View {
    @Environment(SystemMonitor.self) private var monitor

    var body: some View {
        MetricTile(title: "Network", systemImage: "network", tint: MetricColor.download) {
            VStack(alignment: .leading, spacing: 2) {
                rateRow(symbol: "arrow.down", rate: monitor.network?.download, color: MetricColor.download, size: 15)
                rateRow(symbol: "arrow.up", rate: monitor.network?.upload, color: MetricColor.upload, size: 12)
            }
        } footer: {
            MetricSparkline(
                values: monitor.downloadHistory.values,
                color: MetricColor.download,
                secondaryValues: monitor.uploadHistory.values,
                secondaryColor: MetricColor.upload,
                maxValue: nil,
                // 50 KB/s: a quiet connection draws a flat line rather than amplified noise.
                minimumScale: 50000
            )
        }
    }

    private func rateRow(symbol: String, rate: Double?, color: Color, size: CGFloat) -> some View {
        HStack(spacing: 4) {
            Image(systemName: symbol)
                .font(.system(size: size * 0.7, weight: .bold))
                .foregroundStyle(color)
            MetricValueText(text: rate.map { MetricFormatter.rate($0) } ?? "—", size: size)
        }
    }
}

private struct StorageTile: View {
    @Environment(SystemMonitor.self) private var monitor

    var body: some View {
        MetricTile(title: "Storage", systemImage: "internaldrive", tint: tint, detail: detail) {
            MetricValueText(text: monitor.storage.map { MetricFormatter.storage($0.availableBytes) } ?? "—")
        } footer: {
            MetricBar(fraction: monitor.storage?.usedFraction ?? 0, color: tint)
        }
    }

    private var detail: String {
        guard let storage = monitor.storage else { return "" }
        return String(localized: "free of \(MetricFormatter.storage(storage.totalBytes))")
    }

    /// Turns orange when the startup disk gets full, red when it's almost out of space.
    private var tint: Color {
        let used = monitor.storage?.usedFraction ?? 0
        if used >= 0.97 { return MetricColor.critical }
        if used >= 0.9 { return MetricColor.upload }
        return MetricColor.storage
    }
}

private struct BatteryTile: View {
    @Environment(SystemMonitor.self) private var monitor

    var body: some View {
        MetricTile(title: "Battery", systemImage: symbol, tint: tint, detail: detail) {
            MetricValueText(text: monitor.battery.map { MetricFormatter.percent($0.level) } ?? "—")
        } footer: {
            MetricBar(fraction: monitor.battery?.level ?? 0, color: tint)
        }
    }

    private var symbol: String {
        guard let battery = monitor.battery else { return "battery.100percent" }
        if battery.isCharging { return "battery.100percent.bolt" }
        switch battery.level {
        case ..<0.13: return "battery.0percent"
        case ..<0.38: return "battery.25percent"
        case ..<0.63: return "battery.50percent"
        case ..<0.88: return "battery.75percent"
        default: return "battery.100percent"
        }
    }

    private var detail: String {
        guard let battery = monitor.battery else { return "" }
        let remaining = battery.minutesRemaining.map(MetricFormatter.duration(minutes:))
        if battery.isCharging {
            return remaining.map { String(localized: "Full in \($0)") } ?? String(localized: "Charging")
        }
        if battery.isPluggedIn {
            return String(localized: "Plugged in")
        }
        return remaining.map { String(localized: "\($0) left") } ?? String(localized: "On battery")
    }

    private var tint: Color {
        guard let battery = monitor.battery else { return MetricColor.good }
        if battery.isCharging || battery.isPluggedIn { return MetricColor.good }
        if battery.level <= 0.1 { return MetricColor.critical }
        if battery.level <= 0.2 { return MetricColor.warning }
        return MetricColor.good
    }
}

/// Stands in for the battery on desktop Macs.
private struct UptimeTile: View {
    @Environment(SystemMonitor.self) private var monitor

    var body: some View {
        MetricTile(title: "Uptime", systemImage: "clock", tint: .white.opacity(0.7), detail: String(localized: "Since last restart")) {
            MetricValueText(text: MetricFormatter.uptime(monitor.uptime))
        } footer: {
            EmptyView()
        }
    }
}
