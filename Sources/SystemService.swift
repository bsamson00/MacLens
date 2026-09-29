import Foundation
import Combine

final class SystemService: ObservableObject {
    @Published var hardware = HardwareInfo()
    @Published var battery = BatteryInfo()
    @Published var volumes: [VolumeInfo] = []
    @Published var displays: [DisplayInfo] = []
    @Published var graphics: [GraphicsInfo] = []
    @Published var live = LiveMetrics()
    @Published var loaded = false

    private var prevCPUTicks: [[UInt32]] = []
    private let queue = DispatchQueue(label: "maclens.collect", qos: .userInitiated)
    private var dynamicBusy = false

    init() {
        live.memTotalBytes = Shell.sysctlInt("hw.memsize")
        updateLive()
    }

    // MARK: - Static (heavy) collection

    func loadAll() {
        queue.async { [weak self] in
            guard let self else { return }
            let hw = self.collectHardware()
            let bat = self.collectBattery()
            let vols = self.collectVolumes()
            let (disps, gpus) = self.collectDisplays()
            DispatchQueue.main.async {
                self.hardware = hw
                self.battery = bat
                self.volumes = vols
                self.displays = disps
                self.graphics = gpus
                self.loaded = true
            }
        }
    }

    func refresh() { loadAll(); updateLive() }

    // Periodically re-collect the data that can change while the app runs
    // (battery, storage, displays). Hardware specs are immutable, so they are
    // loaded once by loadAll() and skipped here. Coalesced via dynamicBusy so
    // overlapping timer ticks can't queue up redundant work.
    func refreshDynamic() {
        if dynamicBusy { return }   // read/written only on the main thread
        dynamicBusy = true
        queue.async { [weak self] in
            guard let self else { return }
            let bat = self.collectBattery()
            let vols = self.collectVolumes()
            let (disps, gpus) = self.collectDisplays()
            DispatchQueue.main.async {
                self.battery = bat
                self.volumes = vols
                self.displays = disps
                self.graphics = gpus
                self.dynamicBusy = false
            }
        }
    }

    // MARK: - Hardware

    private func collectHardware() -> HardwareInfo {
        var hw = HardwareInfo()
        let data = Shell.runData("/usr/sbin/system_profiler", ["SPHardwareDataType", "-json"])
        if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let arr = obj["SPHardwareDataType"] as? [[String: Any]],
           let h = arr.first {
            hw.modelName = (h["machine_name"] as? String) ?? (h["machine_model"] as? String) ?? "Mac"
            hw.modelIdentifier = (h["machine_model"] as? String) ?? ""
            hw.chip = (h["chip_type"] as? String) ?? Shell.sysctlString("machdep.cpu.brand_string")
            hw.serialNumber = (h["serial_number"] as? String) ?? ""
            hw.memoryGB = (h["physical_memory"] as? String) ?? ""
            if let procs = h["number_processors"] as? String {
                // e.g. "proc 12:6:6"  or  "12"
                let nums = procs.split(whereSeparator: { !"0123456789".contains($0) }).compactMap { Int($0) }
                if nums.count >= 3 {
                    hw.totalCores = nums[0]; hw.performanceCores = nums[1]; hw.efficiencyCores = nums[2]
                } else if let first = nums.first {
                    hw.totalCores = first
                }
            }
        }
        if hw.totalCores == 0 { hw.totalCores = Int(Shell.sysctlInt("hw.ncpu")) }
        if hw.memoryGB.isEmpty {
            hw.memoryGB = Fmt.bytesGB(Shell.sysctlInt("hw.memsize"))
        }
        hw.memoryType = collectMemoryType()
        hw.modelIdentifier = hw.modelIdentifier.isEmpty ? Shell.sysctlString("hw.model") : hw.modelIdentifier
        hw.isLaptop = hw.modelIdentifier.lowercased().contains("macbook")

        let v = ProcessInfo.processInfo.operatingSystemVersion
        hw.macOSVersion = "\(v.majorVersion).\(v.minorVersion)\(v.patchVersion > 0 ? ".\(v.patchVersion)" : "")"
        hw.macOSName = Self.macOSName(major: v.majorVersion)
        hw.macOSBuild = Shell.run("/usr/bin/sw_vers", ["-buildVersion"])
        hw.uptime = ProcessInfo.processInfo.systemUptime
        hw.hostname = ProcessInfo.processInfo.hostName
        return hw
    }

    private func collectMemoryType() -> String {
        let data = Shell.runData("/usr/sbin/system_profiler", ["SPMemoryDataType", "-json"])
        if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let arr = obj["SPMemoryDataType"] as? [[String: Any]],
           let m = arr.first {
            if let t = m["dimm_type"] as? String { return t }
            if let upgrade = m["dimm_manufacturer"] as? String, !upgrade.isEmpty { return upgrade }
            // Apple Silicon nests under "_items"
            if let items = m["_items"] as? [[String: Any]], let t = items.first?["dimm_type"] as? String {
                return t
            }
        }
        return "Unified Memory"
    }

    static func macOSName(major: Int) -> String {
        switch major {
        case 26: return "macOS Tahoe"
        case 15: return "macOS Sequoia"
        case 14: return "macOS Sonoma"
        case 13: return "macOS Ventura"
        case 12: return "macOS Monterey"
        case 11: return "macOS Big Sur"
        default: return "macOS"
        }
    }

    // MARK: - Battery

    private func collectBattery() -> BatteryInfo {
        var b = BatteryInfo()
        let data = Shell.runData("/usr/sbin/ioreg", ["-r", "-c", "AppleSmartBattery", "-a"])
        if let arr = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [[String: Any]],
           let d = arr.first {
            b.present = (d["BatteryInstalled"] as? Bool) ?? false
            b.cycleCount = intOf(d["CycleCount"])
            b.designCycleCount = intOf(d["DesignCycleCount9C"])
            b.designCapacity = intOf(d["DesignCapacity"])
            let rawMax = intOf(d["AppleRawMaxCapacity"])
            b.maxCapacity = rawMax > 0 ? rawMax : intOf(d["MaxCapacity"])
            let rawCur = intOf(d["AppleRawCurrentCapacity"])
            b.currentCapacity = rawCur > 0 ? rawCur : intOf(d["CurrentCapacity"])
            b.onAC = (d["ExternalConnected"] as? Bool) ?? false
            b.isCharging = (d["IsCharging"] as? Bool) ?? false
            b.fullyCharged = (d["FullyCharged"] as? Bool) ?? false
            b.temperature = Double(intOf(d["Temperature"])) / 100.0
            b.voltage = Double(intOf(d["Voltage"])) / 1000.0
            b.amperage = Double(intOf(d["Amperage"])) / 1000.0
            b.serial = (d["Serial"] as? String) ?? ""
            let tr = intOf(d["TimeRemaining"])
            b.timeRemaining = (tr == 65535 || tr <= 0) ? -1 : tr
            if b.designCapacity > 0 && b.maxCapacity > 0 {
                b.healthPercent = Double(b.maxCapacity) / Double(b.designCapacity) * 100.0
            }
            if b.maxCapacity > 0 && b.currentCapacity > 0 {
                b.chargePercent = min(100, Double(b.currentCapacity) / Double(b.maxCapacity) * 100.0)
            }
        }

        // Augment with system_profiler for the "official" condition + max-capacity string.
        let pdata = Shell.runData("/usr/sbin/system_profiler", ["SPPowerDataType", "-json"])
        if let obj = try? JSONSerialization.jsonObject(with: pdata) as? [String: Any],
           let arr = obj["SPPowerDataType"] as? [[String: Any]] {
            for entry in arr {
                if let health = entry["sppower_battery_health_info"] as? [String: Any] {
                    if let c = health["sppower_battery_health"] as? String { b.condition = c }
                    if b.cycleCount == 0 { b.cycleCount = intOf(health["sppower_battery_cycle_count"]) }
                    if let capStr = health["sppower_battery_health_maximum_capacity"] as? String {
                        let digits = capStr.filter { "0123456789".contains($0) }
                        if let pct = Double(digits), pct > 0 { b.healthPercent = pct }
                    }
                }
                if let charge = entry["sppower_battery_charge_info"] as? [String: Any] {
                    let soc = intOf(charge["sppower_battery_state_of_charge"])
                    if soc > 0 { b.chargePercent = Double(soc) }
                    if let fc = charge["sppower_battery_fully_charged"] as? String {
                        b.fullyCharged = (fc.uppercased() == "TRUE")
                    }
                }
            }
        }
        if b.condition == "-" && b.present { b.condition = "Normal" }
        return b
    }

    // MARK: - Storage

    private func collectVolumes() -> [VolumeInfo] {
        var out: [VolumeInfo] = []
        let data = Shell.runData("/usr/sbin/system_profiler", ["SPStorageDataType", "-json"])
        if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let arr = obj["SPStorageDataType"] as? [[String: Any]] {
            for v in arr {
                var vol = VolumeInfo()
                vol.name = (v["_name"] as? String) ?? "Volume"
                vol.mountPoint = (v["mount_point"] as? String) ?? ""
                vol.fileSystem = (v["file_system"] as? String) ?? ""
                vol.totalBytes = int64Of(v["size_in_bytes"])
                vol.freeBytes = int64Of(v["free_space_in_bytes"])
                vol.isBoot = vol.mountPoint == "/"
                if let drive = v["spstorage_physical_drive"] as? [String: Any] {
                    vol.isInternal = (drive["is_internal_disk"] as? String)?.lowercased() == "yes"
                }
                if vol.totalBytes > 0 { out.append(vol) }
            }
        }
        return out.sorted { ($0.isBoot ? 1 : 0, $0.totalBytes) > ($1.isBoot ? 1 : 0, $1.totalBytes) }
    }

    // MARK: - Displays & Graphics

    private func collectDisplays() -> ([DisplayInfo], [GraphicsInfo]) {
        var disps: [DisplayInfo] = []
        var gpus: [GraphicsInfo] = []
        let data = Shell.runData("/usr/sbin/system_profiler", ["SPDisplaysDataType", "-json"])
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let arr = obj["SPDisplaysDataType"] as? [[String: Any]] else { return (disps, gpus) }
        for g in arr {
            var gpu = GraphicsInfo()
            gpu.name = (g["_name"] as? String) ?? "GPU"
            gpu.cores = (g["sppci_cores"] as? String) ?? ""
            if let vendor = g["spdisplays_vendor"] as? String {
                gpu.vendor = vendor.replacingOccurrences(of: "sppci_vendor_", with: "")
                    .replacingOccurrences(of: "sppci_vendor", with: "")
            }
            if let metal = g["spdisplays_metalfamily"] as? String {
                gpu.metalSupport = metal.replacingOccurrences(of: "spdisplays_", with: "").capitalized
            } else if let mtl = g["spdisplays_mtlgpufamilysupport"] as? String {
                gpu.metalSupport = mtl.replacingOccurrences(of: "spdisplays_", with: "")
            }
            gpus.append(gpu)

            if let ndrvs = g["spdisplays_ndrvs"] as? [[String: Any]] {
                for d in ndrvs {
                    var disp = DisplayInfo()
                    disp.name = (d["_name"] as? String) ?? "Display"
                    disp.resolution = (d["_spdisplays_resolution"] as? String)
                        ?? (d["spdisplays_resolution"] as? String) ?? ""
                    disp.uiResolution = (d["spdisplays_resolution"] as? String) ?? ""
                    if let pix = d["_spdisplays_pixels"] as? String, !pix.isEmpty {
                        disp.resolution = pix
                    }
                    disp.isMain = (d["spdisplays_main"] as? String) == "spdisplays_yes"
                    if let type = d["spdisplays_display_type"] as? String {
                        disp.isBuiltIn = type.lowercased().contains("built-in") || type.lowercased().contains("retina")
                        disp.connectionType = type.replacingOccurrences(of: "spdisplays_", with: "")
                            .replacingOccurrences(of: "_", with: " ").capitalized
                    }
                    if let conn = d["spdisplays_connection_type"] as? String {
                        disp.connectionType = conn.replacingOccurrences(of: "spdisplays_", with: "")
                            .replacingOccurrences(of: "_", with: " ").capitalized
                    }
                    // refresh rate often embedded in resolution string "@ 120.00Hz"
                    if let r = (d["spdisplays_resolution"] as? String),
                       let range = r.range(of: "@") {
                        disp.refreshRate = String(r[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                    }
                    disps.append(disp)
                }
            }
        }
        return (disps, gpus)
    }

    // MARK: - Live metrics (CPU + memory)

    func updateLive() {
        var m = live
        m.memTotalBytes = Shell.sysctlInt("hw.memsize")
        m.uptime = ProcessInfo.processInfo.systemUptime
        readMemory(into: &m)
        readCPU(into: &m)
        DispatchQueue.main.async { self.live = m }
    }

    private func readCPU(into m: inout LiveMetrics) {
        var cpuInfo: processor_info_array_t!
        var numCPUInfo: mach_msg_type_number_t = 0
        var numCPUs: natural_t = 0
        let res = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO,
                                      &numCPUs, &cpuInfo, &numCPUInfo)
        guard res == KERN_SUCCESS else { return }
        defer {
            let size = vm_size_t(numCPUInfo) * vm_size_t(MemoryLayout<integer_t>.size)
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: cpuInfo), size)
        }
        let cpus = Int(numCPUs)
        var current: [[UInt32]] = []
        var per: [Double] = []
        var totUser = 0.0, totSys = 0.0, totIdle = 0.0
        for i in 0..<cpus {
            let base = i * Int(CPU_STATE_MAX)
            let user = UInt32(bitPattern: cpuInfo[base + Int(CPU_STATE_USER)])
            let sys  = UInt32(bitPattern: cpuInfo[base + Int(CPU_STATE_SYSTEM)])
            let idle = UInt32(bitPattern: cpuInfo[base + Int(CPU_STATE_IDLE)])
            let nice = UInt32(bitPattern: cpuInfo[base + Int(CPU_STATE_NICE)])
            current.append([user, sys, idle, nice])
            if prevCPUTicks.count == cpus {
                let p = prevCPUTicks[i]
                let dUser = Double(user &- p[0])
                let dSys  = Double(sys  &- p[1])
                let dIdle = Double(idle &- p[2])
                let dNice = Double(nice &- p[3])
                let total = dUser + dSys + dIdle + dNice
                let busy = total > 0 ? (dUser + dSys + dNice) / total : 0
                per.append(min(1.0, max(0.0, busy)))
                totUser += dUser + dNice; totSys += dSys; totIdle += dIdle
            } else {
                per.append(0)
            }
        }
        prevCPUTicks = current
        let grand = totUser + totSys + totIdle
        if grand > 0 {
            m.cpuUserPct = totUser / grand * 100
            m.cpuSystemPct = totSys / grand * 100
            m.cpuIdlePct = totIdle / grand * 100
        }
        if !per.isEmpty { m.perCore = per }
    }

    private func readMemory(into m: inout LiveMetrics) {
        var stats = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        let res = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard res == KERN_SUCCESS else { return }
        let page = Int64(vm_kernel_page_size)
        let wired = Int64(stats.wire_count) * page
        let active = Int64(stats.active_count) * page
        let inactive = Int64(stats.inactive_count) * page
        let compressed = Int64(stats.compressor_page_count) * page
        let purgeable = Int64(stats.purgeable_count) * page
        let external = Int64(stats.external_page_count) * page

        m.memWiredBytes = wired
        m.memCompressedBytes = compressed
        m.memCachedBytes = external + purgeable
        m.memAppBytes = max(0, active + inactive - external)
        // Activity-Monitor-style "Memory Used" ≈ App + Wired + Compressed
        m.memUsedBytes = m.memAppBytes + wired + compressed
        if m.memTotalBytes > 0 {
            m.memPressure = min(1.0, Double(wired + compressed) / Double(m.memTotalBytes) + Double(m.memAppBytes) / Double(m.memTotalBytes) * 0.5)
        }

        var swap = xsw_usage()
        var swSize = MemoryLayout<xsw_usage>.size
        if sysctlbyname("vm.swapusage", &swap, &swSize, nil, 0) == 0 {
            m.swapUsedBytes = Int64(swap.xsu_used)
        }
    }
}

// MARK: - Casting helpers

private func intOf(_ any: Any?) -> Int {
    if let n = any as? NSNumber { return n.intValue }
    if let i = any as? Int { return i }
    if let s = any as? String, let i = Int(s) { return i }
    return 0
}
private func int64Of(_ any: Any?) -> Int64 {
    if let n = any as? NSNumber { return n.int64Value }
    if let i = any as? Int64 { return i }
    if let i = any as? Int { return Int64(i) }
    if let s = any as? String, let i = Int64(s) { return i }
    return 0
}
