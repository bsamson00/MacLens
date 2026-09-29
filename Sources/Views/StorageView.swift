import SwiftUI

struct StorageView: View {
    @ObservedObject var svc: SystemService

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                PageHeader(title: "Storage",
                           subtitle: "\(svc.volumes.count) volume\(svc.volumes.count == 1 ? "" : "s")",
                           symbol: "internaldrive.fill",
                           tint: Theme.color("green"))
                ForEach(svc.volumes) { vol in
                    volumeCard(vol)
                }
                if svc.volumes.isEmpty {
                    Card { Text("Reading volumes…").foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity).padding(.vertical, 24) }
                }
            }
            .padding(22)
        }
    }

    private func volumeCard(_ vol: VolumeInfo) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    Image(systemName: vol.isInternal ? "internaldrive.fill" : "externaldrive.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Theme.usageColor(vol.usedFraction))
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 8) {
                            Text(vol.name).font(.system(size: 16, weight: .semibold))
                            if vol.isBoot {
                                Text("Startup").font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(Theme.accent)
                                    .padding(.horizontal, 7).padding(.vertical, 2)
                                    .background(Theme.accent.opacity(0.15), in: Capsule())
                            }
                        }
                        Text("\(vol.fileSystem) · \(vol.isInternal ? "Internal" : "External") · \(vol.mountPoint)")
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(String(format: "%.0f%% used", vol.usedFraction * 100))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.usageColor(vol.usedFraction))
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.primary.opacity(0.08))
                        Capsule()
                            .fill(Theme.usageColor(vol.usedFraction).gradient)
                            .frame(width: max(12, geo.size.width * vol.usedFraction))
                    }
                }
                .frame(height: 14)

                HStack {
                    legend(color: Theme.usageColor(vol.usedFraction), label: "Used", value: Fmt.bytes(vol.usedBytes))
                    Spacer()
                    legend(color: Color.primary.opacity(0.15), label: "Free", value: Fmt.bytes(vol.freeBytes))
                    Spacer()
                    legend(color: .clear, label: "Total", value: Fmt.bytes(vol.totalBytes))
                }
            }
        }
    }

    private func legend(color: Color, label: String, value: String) -> some View {
        HStack(spacing: 6) {
            if color != .clear {
                Circle().fill(color).frame(width: 9, height: 9)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(label).font(.system(size: 10)).foregroundStyle(.secondary)
                Text(value).font(.system(size: 13, weight: .medium))
            }
        }
    }
}
