import Foundation
#if canImport(Darwin)
import Darwin.Mach
import os
#endif

/// Cheap, async-safe probes for system metrics that Forge displays alongside
/// whatever the `ForgeProvider` reports.
enum ForgeMetricsProbe {
    /// Process memory in megabytes, reported using `phys_footprint` —
    /// the exact metric iOS / macOS use for memory pressure decisions
    /// (jetsam, the Xcode memory gauge, `os_proc_available_memory`).
    /// Resident size, which we used to return here, includes shared pages
    /// and doesn't correspond to what the OS thinks the process is
    /// "using"; phys_footprint is the canonical answer.
    static func memoryUsageMB() -> Double {
        #if canImport(Darwin)
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size
        )

        let kr = withUnsafeMutablePointer(to: &info) { ptr -> kern_return_t in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rebound in
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), rebound, &count)
            }
        }

        if kr == KERN_SUCCESS {
            return Double(info.phys_footprint) / 1024.0 / 1024.0
        }

        // Fallback to resident_size if TASK_VM_INFO is unavailable (very old OS).
        var basic = mach_task_basic_info()
        var basicCount = mach_msg_type_number_t(
            MemoryLayout<mach_task_basic_info>.size / MemoryLayout<integer_t>.size
        )
        let basicKr = withUnsafeMutablePointer(to: &basic) { ptr -> kern_return_t in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(basicCount)) { rebound in
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), rebound, &basicCount)
            }
        }
        guard basicKr == KERN_SUCCESS else { return 0 }
        return Double(basic.resident_size) / 1024.0 / 1024.0
        #else
        return 0
        #endif
    }

    /// The process's memory budget in megabytes — i.e. how much memory
    /// the OS will let us use before terminating us. Computed as
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
