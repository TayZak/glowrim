import Foundation

enum LightMode: String, CaseIterable, Codable, Identifiable {
    case constant = "constant"
    case pulsating = "pulsating"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .constant: return "Constante"
        case .pulsating: return "Pulsante"
        }
    }

    var englishName: String {
        switch self {
        case .constant: return "Constant"
        case .pulsating: return "Pulsating"
        }
    }

    var iconName: String {
        switch self {
        case .constant: return "sun.max.fill"
        case .pulsating: return "waveform.path"
        }
    }

    var description: String {
        switch self {
        case .constant:
            return "Intensité fixe, idéal pour les visioconférences"
        case .pulsating:
            return "Oscillation douce anti burn-in"
        }
    }

    var isSafeForBurnIn: Bool {
        switch self {
        case .constant: return false
        case .pulsating: return true
        }
    }
}
