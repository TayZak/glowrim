import Foundation
import IOKit.ps

@Observable
final class BatteryMonitor {
    static let shared = BatteryMonitor()
    private(set) var batteryLevel: Double = 1
    private(set) var isCharging = true
    private(set) var isLowBattery = false
    @ObservationIgnored private var powerSource: CFRunLoopSource?
    var shouldPauseDueToLowBattery: Bool { isLowBattery && !isCharging }

    private init() {
        updateBatteryStatus(notify: false)
        // Event-driven battery monitoring: no polling when the app is idle.
        powerSource = IOPSNotificationCreateRunLoopSource({ context in
            guard let context else { return }
            Unmanaged<BatteryMonitor>.fromOpaque(context).takeUnretainedValue().updateBatteryStatus()
        }, Unmanaged.passUnretained(self).toOpaque())?.takeRetainedValue()
        if let powerSource { CFRunLoopAddSource(CFRunLoopGetMain(), powerSource, .commonModes) }
    }
    deinit {
        if let powerSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), powerSource, .commonModes)
            CFRunLoopSourceInvalidate(powerSource)
        }
    }
    var hasNotificationSource: Bool { powerSource.map { CFRunLoopSourceIsValid($0) } ?? false }
    private func updateBatteryStatus(notify: Bool = true) {
        var level = 1.0
        var plugged = true
        if let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
           let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] {
            for source in sources {
                guard let info = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any],
                      info[kIOPSTypeKey] as? String == kIOPSInternalBatteryType else { continue }
                if let capacity = info[kIOPSCurrentCapacityKey] as? Int,
                   let maximum = info[kIOPSMaxCapacityKey] as? Int, maximum > 0 {
                    level = max(0, min(1, Double(capacity) / Double(maximum)))
                }
                plugged = info[kIOPSPowerSourceStateKey] as? String == kIOPSACPowerValue
                break
            }
        }
        let powerChanged = plugged != isCharging
        let low = level < Constants.batteryThreshold
        let newlyLow = low && !plugged && !shouldPauseDueToLowBattery
        if batteryLevel != level { batteryLevel = level }
        if isCharging != plugged { isCharging = plugged }
        if isLowBattery != low { isLowBattery = low }
        if notify && powerChanged { NotificationCenter.default.post(name: .glowrimPowerSourceChanged, object: nil) }
        if notify && newlyLow { NotificationCenter.default.post(name: .glowrimLowBattery, object: nil) }
    }
    func refresh() { updateBatteryStatus() }
}

extension Notification.Name {
    static let glowrimLowBattery = Notification.Name("glowrimLowBattery")
    static let glowrimPowerSourceChanged = Notification.Name("glowrimPowerSourceChanged")
}
