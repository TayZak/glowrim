import Foundation
import IOKit.ps
import Combine

@Observable
final class BatteryMonitor {
    static let shared = BatteryMonitor()

    private(set) var batteryLevel: Double = 1.0
    private(set) var isCharging: Bool = true
    private(set) var isLowBattery: Bool = false

    private var timer: Timer?
    private let lowBatteryThreshold = Constants.batteryThreshold

    var shouldPauseDueToLowBattery: Bool {
        isLowBattery && !isCharging
    }

    private init() {
        updateBatteryStatus()
        startMonitoring()
    }

    deinit {
        stopMonitoring()
    }

    private func startMonitoring() {
        // Update every 30 seconds
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.updateBatteryStatus()
        }
    }

    private func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    private func updateBatteryStatus() {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef],
              !sources.isEmpty else {
            // No battery (desktop Mac) - assume always powered
            batteryLevel = 1.0
            isCharging = true
            isLowBattery = false
            return
        }

        for source in sources {
            guard let info = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any] else {
                continue
            }

            // Get battery level
            if let capacity = info[kIOPSCurrentCapacityKey] as? Int,
               let maxCapacity = info[kIOPSMaxCapacityKey] as? Int,
               maxCapacity > 0 {
                batteryLevel = Double(capacity) / Double(maxCapacity)
            }

            // Get charging status
            if let powerSource = info[kIOPSPowerSourceStateKey] as? String {
                isCharging = powerSource == kIOPSACPowerValue
            }

            // Check if charging
            if let chargingState = info[kIOPSIsChargingKey] as? Bool {
                isCharging = isCharging || chargingState
            }
        }

        // Update low battery flag
        isLowBattery = batteryLevel < lowBatteryThreshold

        if isLowBattery && !isCharging {
            NotificationCenter.default.post(
                name: .glowrimLowBattery,
                object: nil,
                userInfo: ["level": batteryLevel]
            )
        }
    }

    /// Force refresh battery status
    func refresh() {
        updateBatteryStatus()
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let glowrimLowBattery = Notification.Name("glowrimLowBattery")
}
