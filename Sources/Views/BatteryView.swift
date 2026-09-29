import SwiftUI

struct BatteryView: View {
    @ObservedObject var svc: SystemService

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                PageHeader(title: "Battery",
                           subtitle: svc.battery.present ? "Health, cycles & charge" : "No internal battery detected",
                           symbol: "battery.100.bolt",
                           tint: Theme.color("green"))
                if svc.battery.present {
                    gauges
                    detailGrid
                } else {
                    Card { Text("This Mac runs on AC power - no battery to report.")
                        .foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(.vertical, 30) }
                }
            }
            .padding(22)
        }
    }

    private var gauges: some View {
        let b = svc.battery
        return HStack(spacing: 18) {
            Card {
                VStack(spacing: 14) {
                    RingGauge(fraction: b.healthPercent / 100,
                              title: String(format: "%.0f%%", b.healthPercent),
                              subtitle: "Maximum\nCapacity",
                              tint: Theme.usageColor(1 - b.healthPercent / 100))
                    conditionBadge
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(height: gaugeCardHeight)
            Card {
                VStack(spacing: 14) {
                    RingGauge(fraction: b.chargePercent / 100,
                              title: String(format: "%.0f%%", b.chargePercent),
                              subtitle: "Current\nCharge",
                              tint: chargeTint)
                    Label(chargeStatus, systemImage: chargeIcon)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(chargeTint)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(height: gaugeCardHeight)
            Card {
                VStack(spacing: 8) {
                    Text("\(b.cycleCount)")
                        .font(.system(size: 64, weight: .bold)).monospacedDigit()
                        .foregroundStyle(Theme.accent)
                    Text("Cycle Count").font(.system(size: 13)).foregroundStyle(.secondary)
                    if b.designCycleCount > 0 {
                        UsageBar(label: "", detail: "\(b.cycleCount) / \(b.designCycleCount) rated",
                                 fraction: Double(b.cycleCount) / Double(b.designCycleCount),
                                 tint: Theme.accent, height: 8)
                            .padding(.top, 14)
                        Text("\(max(0, b.designCycleCount - b.cycleCount)) cycles remaining (rated)")
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(height: gaugeCardHeight)
        }
    }

    private let gaugeCardHeight: CGFloat = 248

    private var conditionBadge: some View {
        let c = Theme.color(svc.battery.conditionColorName)
        return Text(svc.battery.condition)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(c)
            .padding(.horizontal, 14).padding(.vertical, 6)
            .background(c.opacity(0.15), in: Capsule())
    }

    private var detailGrid: some View {
        let b = svc.battery
        return HStack(alignment: .top, spacing: 18) {
            Card {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Capacity").font(.system(size: 15, weight: .semibold)).padding(.bottom, 6)
                    InfoRow(label: "Full Charge Capacity", value: "\(b.maxCapacity) mAh", icon: "bolt.fill")
                    Divider()
                    InfoRow(label: "Design Capacity", value: "\(b.designCapacity) mAh", icon: "bolt.badge.checkmark")
                    Divider()
                    InfoRow(label: "Current Capacity", value: "\(b.currentCapacity) mAh", icon: "bolt.circle")
                    Divider()
                    InfoRow(label: "Time Remaining",
                            value: b.timeRemaining > 0 ? Fmt.duration(Double(b.timeRemaining) * 60) :
                                   (b.onAC ? "On AC" : "Calculating…"),
                            icon: "clock")
                }
            }
            Card {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Electrical & Status").font(.system(size: 15, weight: .semibold)).padding(.bottom, 6)
                    InfoRow(label: "Temperature", value: String(format: "%.1f °C", b.temperature),
                            icon: "thermometer.medium",
                            valueColor: b.temperature > 35 ? Theme.color("yellow") : .primary)
                    Divider()
                    InfoRow(label: "Voltage", value: String(format: "%.2f V", b.voltage), icon: "waveform.path")
                    Divider()
                    InfoRow(label: "Amperage", value: String(format: "%.0f mA", b.amperage * 1000), icon: "bolt.horizontal")
                    Divider()
                    InfoRow(label: "Power Source",
                            value: b.onAC ? "Power Adapter" : "Battery",
                            icon: b.onAC ? "powerplug.fill" : "battery.75")
                    Divider()
                    InfoRow(label: "Battery Serial", value: b.serial.isEmpty ? "-" : b.serial, icon: "barcode")
                }
            }
        }
    }

    private var chargeTint: Color {
        let b = svc.battery
        if b.isCharging { return Theme.color("green") }
        return Theme.usageColor(1 - b.chargePercent / 100)
    }
    private var chargeStatus: String {
        let b = svc.battery
        if b.isCharging { return "Charging" }
        if b.fullyCharged { return "Fully Charged" }
        if b.onAC { return "On AC · Not Charging" }
        return "On Battery"
    }
    private var chargeIcon: String {
        let b = svc.battery
        if b.isCharging { return "battery.100.bolt" }
        if b.onAC { return "powerplug.fill" }
        return "battery.50"
    }
}
