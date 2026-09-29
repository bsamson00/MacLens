import SwiftUI

struct PerformanceView: View {
    @ObservedObject var svc: SystemService

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                PageHeader(title: "Performance",
                           subtitle: "Live CPU & memory · updates every second",
                           symbol: "waveform.path.ecg",
                           tint: Theme.color("red"))
                HStack(spacing: 18) {
                    cpuGauge
                    memGauge
                }
                coresCard
                memoryBreakdown
            }
            .padding(22)
        }
    }

    private var cpuGauge: some View {
        let m = svc.live
        return Card {
            VStack(spacing: 12) {
                RingGauge(fraction: m.cpuBusyPct / 100,
                          title: String(format: "%.0f%%", m.cpuBusyPct),
                          subtitle: "CPU Load",
                          tint: Theme.usageColor(m.cpuBusyPct / 100))
                HStack(spacing: 16) {
                    miniStat("User", String(format: "%.0f%%", m.cpuUserPct), Theme.color("blue"))
                    miniStat("System", String(format: "%.0f%%", m.cpuSystemPct), Theme.color("red"))
                    miniStat("Idle", String(format: "%.0f%%", m.cpuIdlePct), .secondary)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var memGauge: some View {
        let m = svc.live
        return Card {
            VStack(spacing: 12) {
                RingGauge(fraction: m.memUsedFraction,
                          title: String(format: "%.0f%%", m.memUsedFraction * 100),
                          subtitle: "Memory Used",
                          tint: Theme.usageColor(m.memUsedFraction))
                Text("\(Fmt.bytes(m.memUsedBytes)) of \(Fmt.bytes(m.memTotalBytes))")
                    .font(.system(size: 13, weight: .medium)).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func miniStat(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(size: 15, weight: .bold)).foregroundStyle(color).monospacedDigit()
            Text(label).font(.system(size: 10)).foregroundStyle(.secondary)
        }
    }

    private var coresCard: some View {
        let cores = svc.live.perCore
        let columns = [GridItem(.adaptive(minimum: 120), spacing: 12)]
        return Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Per-Core Activity").font(.system(size: 15, weight: .semibold))
                    Spacer()
                    Text("\(cores.count) logical cores").font(.system(size: 12)).foregroundStyle(.secondary)
                }
                if cores.isEmpty {
                    Text("Sampling…").foregroundStyle(.secondary).font(.system(size: 13))
                } else {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(Array(cores.enumerated()), id: \.offset) { idx, load in
                            VStack(alignment: .leading, spacing: 5) {
                                HStack {
                                    Text("Core \(idx + 1)").font(.system(size: 11)).foregroundStyle(.secondary)
                                    Spacer()
                                    Text(String(format: "%.0f%%", load * 100))
                                        .font(.system(size: 11, weight: .semibold)).monospacedDigit()
                                        .foregroundStyle(Theme.usageColor(load))
                                }
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        Capsule().fill(Color.primary.opacity(0.08))
                                        Capsule().fill(Theme.usageColor(load).gradient)
                                            .frame(width: max(4, geo.size.width * load))
                                            .animation(.easeOut(duration: 0.4), value: load)
                                    }
                                }
                                .frame(height: 8)
                            }
                        }
                    }
                }
            }
        }
    }

    private var memoryBreakdown: some View {
        let m = svc.live
        let total = max(1, Double(m.memTotalBytes))
        return Card {
            VStack(alignment: .leading, spacing: 12) {
                Text("Memory Breakdown").font(.system(size: 15, weight: .semibold))
                UsageBar(label: "App Memory", detail: Fmt.bytes(m.memAppBytes),
                         fraction: Double(m.memAppBytes) / total, tint: Theme.color("blue"))
                UsageBar(label: "Wired", detail: Fmt.bytes(m.memWiredBytes),
                         fraction: Double(m.memWiredBytes) / total, tint: Theme.color("red"))
                UsageBar(label: "Compressed", detail: Fmt.bytes(m.memCompressedBytes),
                         fraction: Double(m.memCompressedBytes) / total, tint: Theme.accent)
                UsageBar(label: "Cached Files", detail: Fmt.bytes(m.memCachedBytes),
                         fraction: Double(m.memCachedBytes) / total, tint: Theme.color("green"))
                Divider().padding(.vertical, 2)
                InfoRow(label: "Swap Used", value: Fmt.bytes(m.swapUsedBytes), icon: "arrow.left.arrow.right",
                        valueColor: m.swapUsedBytes > 0 ? Theme.color("yellow") : .primary)
            }
        }
    }
}
