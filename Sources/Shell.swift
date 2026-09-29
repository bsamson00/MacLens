import Foundation

/// Small helpers for shelling out to system tools and parsing their output.
enum Shell {
    /// Run a command and return stdout as a trimmed string.
    static func run(_ launchPath: String, _ args: [String]) -> String {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: launchPath)
        task.arguments = args
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        do {
            try task.run()
        } catch {
            return ""
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        return String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    /// Run a command and return raw stdout Data (for plist/json parsing).
    static func runData(_ launchPath: String, _ args: [String]) -> Data {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: launchPath)
        task.arguments = args
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        do { try task.run() } catch { return Data() }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        return data
    }

    /// `sysctl` value as a string.
    static func sysctlString(_ key: String) -> String {
        var size = 0
        sysctlbyname(key, nil, &size, nil, 0)
        guard size > 0 else { return "" }
        var value = [CChar](repeating: 0, count: size)
        sysctlbyname(key, &value, &size, nil, 0)
        return String(cString: value)
    }

    static func sysctlInt(_ key: String) -> Int64 {
        var value: Int64 = 0
        var size = MemoryLayout<Int64>.size
        if sysctlbyname(key, &value, &size, nil, 0) == 0 { return value }
        return 0
    }
}

/// Format helpers.
enum Fmt {
    static func bytes(_ value: Int64) -> String {
        let f = ByteCountFormatter()
        f.countStyle = .file
        f.allowedUnits = [.useGB, .useTB, .useMB]
        return f.string(fromByteCount: value)
    }

    static func bytesGB(_ value: Int64) -> String {
        let gb = Double(value) / 1_000_000_000.0
        if gb >= 1000 {
            return String(format: "%.2f TB", gb / 1000)
        }
        return String(format: "%.0f GB", gb)
    }

    static func duration(_ seconds: TimeInterval) -> String {
        let s = Int(seconds)
        let days = s / 86400
        let hours = (s % 86400) / 3600
        let mins = (s % 3600) / 60
        if days > 0 { return "\(days)d \(hours)h \(mins)m" }
        if hours > 0 { return "\(hours)h \(mins)m" }
        return "\(mins)m"
    }
}
