import Foundation

struct HardwareInfo {
    var modelName = "Mac"
    var modelIdentifier = ""
    var chip = ""
    var totalCores = 0
    var performanceCores = 0
    var efficiencyCores = 0
    var gpuCores = 0
    var memoryGB = ""
    var memoryType = ""
    var serialNumber = ""
    var macOSName = ""
    var macOSVersion = ""
    var macOSBuild = ""
    var uptime: TimeInterval = 0
    var hostname = ""
    var isLaptop = true

    /// SF Symbol that best represents this machine.
    var symbol: String {
        let id = modelIdentifier.lowercased()
        if id.contains("macbook") { return "laptopcomputer" }
        if id.contains("macmini") || id.contains("mini") { return "macmini" }
        if id.contains("macstudio") || id.contains("studio") { return "macstudio" }
        if id.contains("macpro") { return "macpro.gen3" }
        if id.contains("imac") { return "desktopcomputer" }
        return isLaptop ? "laptopcomputer" : "desktopcomputer"
    }
}

struct BatteryInfo {
    var present = false
    var cycleCount = 0
    var designCycleCount = 0
    var healthPercent = 0.0          // max capacity vs design
    var condition = "-"
    var chargePercent = 0.0
    var isCharging = false
    var onAC = false
    var fullyCharged = false
    var temperature = 0.0            // °C
    var voltage = 0.0                // V
    var amperage = 0.0               // A
    var designCapacity = 0           // mAh
    var maxCapacity = 0              // mAh (current full-charge capacity)
    var currentCapacity = 0          // mAh
    var timeRemaining = 0            // minutes, -1 = calculating
    var serial = ""

    var conditionColorName: String {
        switch condition.lowercased() {
        case let c where c.contains("normal") || c.contains("good"): return "green"
        case let c where c.contains("fair"): return "yellow"
        case let c where c.contains("service") || c.contains("replace") || c.contains("poor"): return "red"
        default: return "secondary"
        }
    }
}

struct VolumeInfo: Identifiable {
    let id = UUID()
    var name = ""
    var mountPoint = ""
    var fileSystem = ""
    var totalBytes: Int64 = 0
    var freeBytes: Int64 = 0
    var isInternal = true
    var isBoot = false
    var usedBytes: Int64 { max(0, totalBytes - freeBytes) }
    var usedFraction: Double { totalBytes > 0 ? Double(usedBytes) / Double(totalBytes) : 0 }
}

struct DisplayInfo: Identifiable {
    let id = UUID()
    var name = ""
    var resolution = ""
    var uiResolution = ""
    var isMain = false
    var isBuiltIn = false
    var connectionType = ""
    var refreshRate = ""
}

struct GraphicsInfo: Identifiable {
    let id = UUID()
    var name = ""
    var vendor = ""
    var cores = ""
    var metalSupport = ""
}

/// Live, frequently-updated metrics.
struct LiveMetrics {
    var cpuUserPct = 0.0
    var cpuSystemPct = 0.0
    var cpuIdlePct = 100.0
    var perCore: [Double] = []           // 0...1 busy per logical core
    var memUsedBytes: Int64 = 0
    var memTotalBytes: Int64 = 0
    var memAppBytes: Int64 = 0
    var memWiredBytes: Int64 = 0
    var memCompressedBytes: Int64 = 0
    var memCachedBytes: Int64 = 0
    var swapUsedBytes: Int64 = 0
    var memPressure = 0.0                 // 0...1
    var uptime: TimeInterval = 0

    var cpuBusyPct: Double { cpuUserPct + cpuSystemPct }
    var memUsedFraction: Double { memTotalBytes > 0 ? Double(memUsedBytes) / Double(memTotalBytes) : 0 }
}
