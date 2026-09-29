import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(LinearGradient(colors: [Color(red: 0.36, green: 0.40, blue: 0.92),
                                                  Color(red: 0.55, green: 0.36, blue: 0.93)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 88, height: 88)
                Image(systemName: "sparkle.magnifyingglass")
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .shadow(color: Theme.accent.opacity(0.4), radius: 12, y: 6)
            .padding(.top, 8)

            VStack(spacing: 3) {
                Text("MacLens").font(.system(size: 22, weight: .bold))
                Text("Version 1.5").font(.system(size: 12)).foregroundStyle(.secondary)
                Text("Know your Mac").font(.system(size: 13)).foregroundStyle(.secondary)
            }

            Divider().padding(.horizontal, 30)

            VStack(spacing: 8) {
                aboutRow(label: "Developer", value: "Brian Samson")
                Link(destination: URL(string: "mailto:brian@samson.zone")!) {
                    aboutRow(label: "Email", value: "brian@samson.zone", valueColor: Theme.accent)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 30)

            Spacer(minLength: 0)

            Text("Copyright © 2026 Samson Zone")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .padding(.bottom, 14)
        }
        .frame(width: 320, height: 360)
        .background(WindowBackground())
    }

    private func aboutRow(label: String, value: String, valueColor: Color = .primary) -> some View {
        HStack {
            Text(label).font(.system(size: 13)).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.system(size: 13, weight: .medium)).foregroundStyle(valueColor)
        }
    }
}
