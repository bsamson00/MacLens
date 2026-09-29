import SwiftUI

enum Section: String, CaseIterable, Identifiable {
    case overview, battery, storage, performance, displays
    var id: String { rawValue }
    var title: String {
        switch self {
        case .overview: return "Overview"
        case .battery: return "Battery"
        case .storage: return "Storage"
        case .performance: return "Performance"
        case .displays: return "Graphics"
        }
    }
    var symbol: String {
        switch self {
        case .overview: return "macbook"
        case .battery: return "battery.100"
        case .storage: return "internaldrive"
        case .performance: return "speedometer"
        case .displays: return "display"
        }
    }
    var tint: Color {
        switch self {
        case .overview: return Theme.accent
        case .battery: return Theme.color("green")
        case .storage: return Theme.color("green")
        case .performance: return Theme.color("red")
        case .displays: return Theme.color("blue")
        }
    }
}

enum Appearance: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var label: String {
        switch self {
        case .system: return "Auto"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
    var symbol: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

@main
struct MacLensApp: App {
    @StateObject private var svc = SystemService()
    @State private var selection: Section = .overview
    @AppStorage("appearance") private var appearanceRaw = Appearance.system.rawValue
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        WindowGroup("MacLens") {
            ContentView(svc: svc, selection: $selection)
                .frame(minWidth: 900, minHeight: 620)
                .preferredColorScheme(Appearance(rawValue: appearanceRaw)?.colorScheme)
                .onAppear { svc.loadAll() }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(replacing: .appInfo) {
                Button("About MacLens") { openWindow(id: "about") }
            }
        }

        Window("About MacLens", id: "about") {
            AboutView()
                .preferredColorScheme(Appearance(rawValue: appearanceRaw)?.colorScheme)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }
}

struct ContentView: View {
    @ObservedObject var svc: SystemService
    @Binding var selection: Section
    @AppStorage("appearance") private var appearanceRaw = Appearance.system.rawValue
    private let ticker = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()
    private let slowTicker = Timer.publish(every: 3.0, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(WindowBackground())
        }
        .onReceive(ticker) { _ in svc.updateLive() }
        .onReceive(slowTicker) { _ in svc.refreshDynamic() }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "sparkle.magnifyingglass")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                VStack(alignment: .leading, spacing: 0) {
                    Text("MacLens").font(.system(size: 16, weight: .bold))
                    Text("Know your Mac").font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 14).padding(.top, 18).padding(.bottom, 14)

            List(selection: $selection) {
                ForEach(Section.allCases) { section in
                    Label {
                        Text(section.title).font(.system(size: 13, weight: .medium))
                    } icon: {
                        Image(systemName: section.symbol).foregroundStyle(section.tint)
                    }
                    .tag(section)
                    .padding(.vertical, 2)
                }
            }
            .listStyle(.sidebar)

            Spacer(minLength: 0)

            Picker("Appearance", selection: $appearanceRaw) {
                ForEach(Appearance.allCases) { mode in
                    Label(mode.label, systemImage: mode.symbol).tag(mode.rawValue)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 14)

            Button {
                svc.refresh()
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.borderless)
            .padding(14)
        }
        .frame(minWidth: 210)
    }

    @ViewBuilder
    private var detail: some View {
        switch selection {
        case .overview: OverviewView(svc: svc)
        case .battery: BatteryView(svc: svc)
        case .storage: StorageView(svc: svc)
        case .performance: PerformanceView(svc: svc)
        case .displays: DisplaysView(svc: svc)
        }
    }
}

/// Subtle gradient backdrop behind detail pages.
struct WindowBackground: View {
    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
            LinearGradient(colors: [Theme.accent.opacity(0.06), .clear],
                           startPoint: .top, endPoint: .bottom)
        }
        .ignoresSafeArea()
    }
}
