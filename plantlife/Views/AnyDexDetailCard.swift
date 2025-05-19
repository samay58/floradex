import SwiftUI

/// A type-erased wrapper that allows heterogeneous collections of `DexDetailCard` conforming views.
struct AnyDexDetailCard: DexDetailCard {
    let id: Int
    let accentColor: Color
    private let _view: AnyView
    
    init<C: DexDetailCard>(_ card: C) {
        self.id = card.id
        self.accentColor = card.accentColor
        self._view = AnyView(card)
    }
    
    var body: some View {
        _view
    }
} 