import Foundation
#if canImport(Darwin)
import Darwin.Mach
import os
#endif

/// Cheap, async-safe probes for system metrics that Forge displays alongside
/// whatever the `ForgeProvider` reports.
enum ForgeMetricsProbe {
    /// Resident process memory in megabytes. Returns 0 on platforms where
    /// the probe fails.
    static func memoryUsageMB() -> Double {
        #if canImport(Darwin)
        var info = mach_task_basic_info()
        let infoSize = MemoryLayout<mach_task_basic_info>.size
        let intSize = MemoryLayout<integer_t>.size
        var count = mach_msg_type_number_t(infoSize / intSize)

        let kr = withUnsafeMutablePointer(to: &info) { ptr -> kern_return_t in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rebound in
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), rebound, &count)
            }
        }
        guard kr == KERN_SUCCESS else { return 0 }
        return Double(info.resident_size) / 1024.0 / 1024.0
        #else
        return 0
        #endif
    }

    /// The process's memory budget in megabytes — i.e. how much resident
    /// memory the OS will let us use before terminating us. Computed as
    /// `currentlyUsed + os_proc_available_memory()` so the chart's Y axis
    /// always represents the *real* ceiling on this device, not a
    /// hard-coded device class.
    ///
    /// Falls back to `ProcessInfo.processInfo.physicalMemory` if the
    /// available-memory probe is unsupported.
    static func memoryBudgetMB() -> Double {
        #if os(iOS) || os(visionOS) || targetEnvironment(macCatalyst)
        let availableBytes = os_proc_available_memory()
        if availableBytes > 0 {
            let availableMB = Double(availableBytes) / 1024.0 / 1024.0
            return memoryUsageMB() + availableMB
        }
        return Double(ProcessInfo.processInfo.physicalMemory) / 1024.0 / 1024.0
        #else
        return Double(ProcessInfo.processInfo.physicalMemory) / 1024.0 / 1024.0
        #endif
    }

    static func thermalLabel() -> String {
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: return "Nominal"
        case .fair: return "Fair"
        case .serious: return "Serious"
        case .critical: return "Critical"
        @unknown default: return "Unknown"
        }
    }
}
