import SwiftUI
import AppKit

/// Click any value to copy it to the clipboard. Adds a pointing-hand cursor,
/// a tooltip, and a brief green checkmark as confirmation.
struct Copyable: ViewModifier {
    let value: String
    @State private var copied = false
    func body(content: Content) -> some View {
        content
            .contentShape(Rectangle())
            .onHover { inside in
                if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
            }
            .onTapGesture {
                let pb = NSPasteboard.general
                pb.clearContents()
                pb.setString(value, forType: .string)
                withAnimation(.easeOut(duration: 0.15)) { copied = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    withAnimation(.easeIn(duration: 0.3)) { copied = false }
                }
            }
            .help("Click to copy")
            .overlay(alignment: .topTrailing) {
                if copied {
                    Text("Copied!")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.black.opacity(0.82), in: Capsule())
                        .fixedSize()
                        .offset(y: -24)
                        .allowsHitTesting(false)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
    }
}

extension View {
    /// Make this view copy `value` to the clipboard when clicked.
    func copyable(_ value: String) -> some View { modifier(Copyable(value: value)) }
}

enum Theme {
    static let cardCorner: CGFloat = 16
    static let accent = Color(red: 0.39, green: 0.45, blue: 0.96)

    static func color(_ name: String) -> Color {
        switch name {
        case "green": return Color(red: 0.20, green: 0.78, blue: 0.45)
        case "yellow": return Color(red: 0.98, green: 0.74, blue: 0.18)
        case "red": return Color(red: 0.95, green: 0.30, blue: 0.30)
        case "blue": return Color(red: 0.31, green: 0.55, blue: 0.98)
        default: return .secondary
        }
    }

    /// Pick a status color from a 0...1 fraction (green → yellow → red).
    static func usageColor(_ fraction: Double) -> Color {
        switch fraction {
        case ..<0.6: return color("green")
        case ..<0.85: return color("yellow")
        default: return color("red")
        }
    }
}

/// Frosted card container.
struct Card<Content: View>: View {
    var padding: CGFloat = 18
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Theme.cardCorner, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cardCorner, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
    }
}

/// Section header used at the top of each page.
struct PageHeader: View {
    let title: String
    let subtitle: String
    let symbol: String
    var tint: Color = Theme.accent
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(tint.gradient)
                    .frame(width: 46, height: 46)
                Image(systemName: symbol)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 24, weight: .bold))
                Text(subtitle).font(.system(size: 13)).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}

/// A labeled value row inside a card.
struct InfoRow: View {
    let label: String
    let value: String
    var icon: String? = nil
    var valueColor: Color = .primary
    var body: some View {
        HStack(spacing: 10) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .frame(width: 18)
            }
            Text(label).foregroundStyle(.secondary)
            Spacer(minLength: 16)
            Text(value)
                .foregroundStyle(valueColor)
                .fontWeight(.medium)
                .multilineTextAlignment(.trailing)
        }
        .font(.system(size: 13))
        .padding(.vertical, 5)
        .copyable(value)
    }
}

/// Compact stat chip (icon + value + caption).
struct StatChip: View {
    let icon: String
    let value: String
    let caption: String
    var tint: Color = Theme.accent
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(tint)
            Text(value).font(.system(size: 17, weight: .bold)).lineLimit(1).minimumScaleFactor(0.7)
            Text(caption).font(.system(size: 11)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .copyable(value)
    }
}

/// Linear usage bar with label and value.
struct UsageBar: View {
    let label: String
    let detail: String
    let fraction: Double
    var tint: Color? = nil
    var height: CGFloat = 10
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label).font(.system(size: 13, weight: .medium))
                Spacer()
                Text(detail).font(.system(size: 12)).foregroundStyle(.secondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.08))
                    Capsule()
                        .fill((tint ?? Theme.usageColor(fraction)).gradient)
                        .frame(width: max(height, geo.size.width * min(1, max(0, fraction))))
                }
            }
            .frame(height: height)
        }
    }
}

/// Circular gauge for a 0...1 value with a big centered label.
struct RingGauge: View {
    let fraction: Double
    let title: String
    let subtitle: String
    var tint: Color = Theme.accent
    var size: CGFloat = 150
    var body: some View {
        ZStack {
            Circle().stroke(Color.primary.opacity(0.08), lineWidth: 14)
            Circle()
                .trim(from: 0, to: min(1, max(0, fraction)))
                .stroke(tint.gradient, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.5), value: fraction)
            VStack(spacing: 2) {
                Text(title).font(.system(size: size * 0.24, weight: .bold)).monospacedDigit()
                Text(subtitle).font(.system(size: 11)).foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
    }
}
