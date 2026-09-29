import SwiftUI

struct DisplaysView: View {
    @ObservedObject var svc: SystemService

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                PageHeader(title: "Graphics & Displays",
                           subtitle: "\(svc.graphics.count) GPU · \(svc.displays.count) display\(svc.displays.count == 1 ? "" : "s")",
                           symbol: "display",
                           tint: Theme.color("blue"))

                ForEach(svc.graphics) { gpu in
                    Card {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 10) {
                                Image(systemName: "cpu.fill").font(.system(size: 20)).foregroundStyle(Theme.accent)
                                Text(gpu.name).font(.system(size: 16, weight: .semibold))
                                Spacer()
                                if !gpu.cores.isEmpty {
                                    Text("\(gpu.cores)-core GPU").font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.bottom, 8)
                            if !gpu.vendor.isEmpty {
                                InfoRow(label: "Vendor", value: gpu.vendor, icon: "building.2")
                                Divider()
                            }
                            if !gpu.metalSupport.isEmpty {
                                InfoRow(label: "Metal", value: gpu.metalSupport, icon: "square.stack.3d.up")
                            }
                        }
                    }
                }

                ForEach(svc.displays) { disp in
                    Card {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 10) {
                                Image(systemName: disp.isBuiltIn ? "laptopcomputer" : "display")
                                    .font(.system(size: 20)).foregroundStyle(Theme.color("blue"))
                                Text(disp.name).font(.system(size: 16, weight: .semibold))
                                if disp.isMain {
                                    Text("Main").font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(Theme.color("blue"))
                                        .padding(.horizontal, 7).padding(.vertical, 2)
                                        .background(Theme.color("blue").opacity(0.15), in: Capsule())
                                }
                                Spacer()
                            }
                            .padding(.bottom, 8)
                            InfoRow(label: "Resolution", value: disp.resolution.isEmpty ? "-" : disp.resolution,
                                    icon: "rectangle.dashed")
                            if !disp.refreshRate.isEmpty {
                                Divider()
                                InfoRow(label: "Refresh Rate", value: disp.refreshRate, icon: "timer")
                            }
                            if !disp.connectionType.isEmpty {
                                Divider()
                                InfoRow(label: "Type", value: disp.connectionType, icon: "cable.connector")
                            }
                        }
                    }
                }

                if svc.displays.isEmpty && svc.graphics.isEmpty {
                    Card { Text("Reading display info…").foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity).padding(.vertical, 24) }
                }
            }
            .padding(22)
        }
    }
}
