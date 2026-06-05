import BlinkCore

/// macOS-only SF Symbol mapping for `BreakSuggestion`. Lives in the app
/// target — BlinkCore stays glyph-agnostic so the Windows client can map
/// the same cases to its own icon system.
extension BreakSuggestion {
    var iconName: String {
        switch self {
        case .lookFarAway: return "eye"
        case .breathe:     return "wind"
        case .drinkWater:  return "drop.fill"
        case .getUp:       return "figure.stand"
        case .takeAWalk:   return "figure.walk"
        case .touchGrass:  return "leaf.fill"
        }
    }
}
