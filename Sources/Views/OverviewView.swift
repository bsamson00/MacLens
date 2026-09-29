import SwiftUI

struct OverviewView: View {
    @ObservedObject var svc: SystemService

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                hero
                quickStats
                HStack(alignment: .top, spacing: 18) {
                    systemCard
                    healthCard
                }
            }
            .padding(22)
        }
    }

    private var hero: some View {
        let hw = svc.hardware
        return ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(colors: [Color(red: 0.36, green: 0.40, blue: 0.92),
                                            Color(red: 0.55, green: 0.36, blue: 0.93)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )
            HStack(spacing: 26) {
                Image(systemName: hw.symbol)
                    .font(.system(size: 84, weight: .thin))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
                VStack(alignment: .leading, spacing: 8) {
                    Text(hw.modelName)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(.white)
                    Text(hw.chip)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(.white.opacity(0.9))
                    HStack(spacing: 8) {
                        pill(hw.macOSName + " " + hw.macOSVersion)
                        if !hw.modelIdentifier.isEmpty { pill(hw.modelIdentifier) }
                    }
                    .padding(.top, 4)
                }
                Spacer()
            }
            .padding(28)
        }
        .frame(height: 200)
        .shadow(color: Color(red: 0.36, green: 0.40, blue: 0.92).opacity(0.35), radius: 18, y: 8)
    }

    private func pill(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12).padding(.vertical, 5)
            .background(.white.opacity(0.18), in: Capsule())
    }

    private var quickStats: some View {
        let hw = svc.hardware
        let cores = hw.totalCores > 0 ? "\(hw.totalCores)" : "-"
        let coreCaption = hw.performanceCores > 0
            ? "\(hw.performanceCores)P + \(hw.efficiencyCores)E" : "CPU Cores"
        return HStack(spacing: 12) {
            StatChip(icon: "memorychip", value: hw.memoryGB.isEmpty ? "-" : hw.memoryGB,
                     caption: hw.memoryType, tint: Theme.color("blue"))
            StatChip(icon: "cpu", value: cores, caption: coreCaption, tint: Theme.accent)
            StatChip(icon: "internaldrive", value: bootCapacity, caption: "Storage", tint: Theme.color("green"))
            StatChip(icon: hw.isLaptop ? "battery.100" : "bolt.fill",
                     value: batteryValue, caption: batteryCaption, tint: batteryTint)
        }
    }

    private var bootCapacity: String {
        if let boot = svc.volumes.first(where: { $0.isBoot }) ?? svc.volumes.first {
            return Fmt.bytesGB(boot.totalBytes)
        }
        return "-"
    }
    private var batteryValue: String {
        svc.battery.present ? String(format: "%.0f%%", svc.battery.healthPercent) : "AC"
    }
    private var batteryCaption: String {
        svc.battery.present ? "Battery Health" : "Power"
    }
    private var batteryTint: Color {
        guard svc.battery.present else { return Theme.color("yellow") }
        return Theme.usageColor(1 - svc.battery.healthPercent / 100)
    }

    private var systemCard: some View {
        let hw = svc.hardware
        return Card {
            VStack(alignment: .leading, spacing: 2) {
                Text("System").font(.system(size: 15, weight: .semibold)).padding(.bottom, 6)
                InfoRow(label: "Model", value: hw.modelName, icon: "desktopcomputer")
                Divider()
                InfoRow(label: "Identifier", value: hw.modelIdentifier.isEmpty ? "-" : hw.modelIdentifier, icon: "number")
                Divider()
                InfoRow(label: "Chip", value: hw.chip, icon: "cpu")
                Divider()
                InfoRow(label: "Memory", value: "\(hw.memoryGB) · \(hw.memoryType)", icon: "memorychip")
                Divider()
                InfoRow(label: "macOS", value: "\(hw.macOSName) \(hw.macOSVersion) (\(hw.macOSBuild))", icon: "apple.logo")
                Divider()
                InfoRow(label: "Serial Number", value: hw.serialNumber.isEmpty ? "-" : hw.serialNumber, icon: "barcode")
            }
        }
    }

    private var healthCard: some View {
        let hw = svc.hardware
        return Card {
            VStack(alignment: .leading, spacing: 2) {
                Text("At a Glance").font(.system(size: 15, weight: .semibold)).padding(.bottom, 6)
                InfoRow(label: "Computer Name", value: hw.hostname, icon: "person.crop.circle")
                Divider()
                InfoRow(label: "Uptime", value: Fmt.duration(svc.live.uptime), icon: "clock")
                Divider()
                InfoRow(label: "CPU Load", value: String(format: "%.0f%%", svc.live.cpuBusyPct),
                        icon: "gauge.with.dots.needle.50percent",
                        valueColor: Theme.usageColor(svc.live.cpuBusyPct / 100))
                Divider()
                InfoRow(label: "Memory Used",
                        value: "\(Fmt.bytes(svc.live.memUsedBytes)) of \(Fmt.bytes(svc.live.memTotalBytes))",
                        icon: "memorychip", valueColor: Theme.usageColor(svc.live.memUsedFraction))
                Divider()
                if svc.battery.present {
                    InfoRow(label: "Battery", value: String(format: "%.0f%% · %@", svc.battery.chargePercent,
                            svc.battery.isCharging ? "Charging" : (svc.battery.onAC ? "On AC" : "On Battery")),
                            icon: "battery.75")
                    Divider()
                    InfoRow(label: "Cycle Count", value: "\(svc.battery.cycleCount)", icon: "arrow.triangle.2.circlepath")
                } else {
                    InfoRow(label: "Power", value: "AC Power", icon: "powerplug")
                    Divider()
                    InfoRow(label: "Displays", value: "\(svc.displays.count) connected", icon: "display")
                }
            }
        }
    }
}
