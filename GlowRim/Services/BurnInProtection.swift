import Foundation
import Combine

@Observable
final class BurnInProtection {
    static let shared = BurnInProtection()

    private var constantModeTimer: Timer?
    private var constantModeStartTime: Date?

    private(set) var isAutoProtectionActive: Bool = false
    private(set) var timeUntilProtection: TimeInterval = Constants.burnInProtectionDelay

    private let protectionDelay = Constants.burnInProtectionDelay

    private init() {}

    /// Called when constant mode is activated
    func onConstantModeEnabled() {
        guard constantModeTimer == nil else { return }

        constantModeStartTime = Date()
        isAutoProtectionActive = false
        timeUntilProtection = protectionDelay

        // Start countdown timer
        constantModeTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateCountdown()
        }
    }

    /// Called when mode changes from constant or ring light is disabled
    func onConstantModeDisabled() {
        constantModeTimer?.invalidate()
        constantModeTimer = nil
        constantModeStartTime = nil
        isAutoProtectionActive = false
        timeUntilProtection = protectionDelay
    }

    /// Resets the protection timer (e.g., when user adjusts settings)
    func resetTimer() {
        guard constantModeTimer != nil else { return }
        constantModeStartTime = Date()
        isAutoProtectionActive = false
        timeUntilProtection = protectionDelay
    }

    private func updateCountdown() {
        guard let startTime = constantModeStartTime else { return }

        let elapsed = Date().timeIntervalSince(startTime)
        timeUntilProtection = max(0, protectionDelay - elapsed)

        if elapsed >= protectionDelay && !isAutoProtectionActive {
            activateProtection()
        }
    }

    private func activateProtection() {
        isAutoProtectionActive = true

        // Notify that auto-protection should kick in
        NotificationCenter.default.post(
            name: .glowrimBurnInProtectionActivated,
            object: nil
        )

        // Also update the settings to switch to pulsating mode
        DispatchQueue.main.async {
            LightSettings.shared.mode = .pulsating
        }
    }

    /// Returns formatted time remaining
    var formattedTimeRemaining: String {
        let minutes = Int(timeUntilProtection) / 60
        let seconds = Int(timeUntilProtection) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let glowrimBurnInProtectionActivated = Notification.Name("glowrimBurnInProtectionActivated")
}
