import AppKit
import Carbon

/// Register only the requested shortcut; no keyboard interception or permissions needed.
@Observable
final class HotKeyManager {
    static let shared = HotKeyManager()
    private var hotKey: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private var onToggle: (() -> Void)?
    private(set) var isRegistered = false
    private init() {}

    func register(onToggle: @escaping () -> Void) {
        unregister()
        self.onToggle = onToggle
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let context = Unmanaged.passUnretained(self).toOpaque()
        let installed = InstallEventHandler(GetApplicationEventTarget(), { _, _, context in
            guard let context else { return OSStatus(eventNotHandledErr) }
            let manager = Unmanaged<HotKeyManager>.fromOpaque(context).takeUnretainedValue()
            manager.onToggle?()
            return noErr
        }, 1, &eventType, context, &handler)
        guard installed == noErr else { return }
        let id = EventHotKeyID(signature: 0x47524D4C, id: 1)
        isRegistered = RegisterEventHotKey(UInt32(kVK_ANSI_L), UInt32(cmdKey | optionKey), id,
            GetApplicationEventTarget(), 0, &hotKey) == noErr
    }
    func unregister() {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        if let handler { RemoveEventHandler(handler) }
        hotKey = nil; handler = nil; onToggle = nil; isRegistered = false
    }
}
