import SwiftUI
import UIKit // For Haptics

protocol DexDetailCard: View, Identifiable {
    var id: Int { get }
    var accentColor: Color { get }
}

extension DexDetailCard {
    // Default accent color if not provided
    var accentColor: Color {
        Theme.Colors.secondary
    }
}

enum DragDirection {
    case left, right, none
}

struct DexCardPager: View {
    let cards: [AnyDexDetailCard]
    @State private var currentIndex: Int = 0
    @State private var dragOffset: CGFloat = 0
    @State private var dragDirection: DragDirection = .none
    
    // Animation parameters
    private let dragThreshold: CGFloat = 0.25
    private let rotationAngle: Double = 8
    private let scaleMinimum: Double = 0.94
    private let peekOffset: CGFloat = 60
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Cards
                ForEach(cards) { card in
                    if shouldShowCard(card) {
                        card
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .rotation3DEffect(
                                .degrees(rotationForCard(card, width: geometry.size.width)),
                                axis: (x: 0, y: 1, z: 0),
                                anchor: dragDirection == .left ? .leading : .trailing
                            )
                            .offset(x: offsetForCard(card))
                            .zIndex(zIndexForCard(card))
                            .scaleEffect(scaleForCard(card, width: geometry.size.width))
                            .shadow(color: .black.opacity(0.1), radius: 4, y: 4)
                    }
                }
            }
            .contentShape(Rectangle())
            .highPriorityGesture(
                DragGesture(minimumDistance: 10, coordinateSpace: .local)
                    .onChanged { value in
                        dragOffset = value.translation.width
                        dragDirection = dragOffset > 0 ? .right : .left
                    }
                    .onEnded { value in
                        handleDragEnd(cardWidth: geometry.size.width)
                    }
            )
        }
        .overlay(alignment: .bottom) {
            // Modern page indicator
            ModernPageIndicator(count: cards.count, currentIndex: currentIndex)
                .padding(.bottom, 8)
        }
        .accessibilityElement(children: .contain)
        .accessibilityAction(named: "Next Card") {
            if currentIndex < cards.count - 1 {
                withAnimation(.interactiveSpring(response: 0.45, dampingFraction: 0.85)) {
                    currentIndex += 1
                }
            }
        }
        .accessibilityAction(named: "Previous Card") {
            if currentIndex > 0 {
                withAnimation(.interactiveSpring(response: 0.45, dampingFraction: 0.85)) {
                    currentIndex -= 1
                }
            }
        }
    }
    
    // MARK: - Helper functions
    
    // Only show the current card and the ones immediately before and after
    private func shouldShowCard(_ card: AnyDexDetailCard) -> Bool {
        let cardIndex = cards.firstIndex(where: { $0.id == card.id }) ?? 0
        return cardIndex >= currentIndex - 1 && cardIndex <= currentIndex + 1
    }
    
    // Calculate the rotation based on drag amount
    private func rotationForCard(_ card: AnyDexDetailCard, width: CGFloat) -> Double {
        let cardIndex = cards.firstIndex(where: { $0.id == card.id }) ?? 0
        if cardIndex == currentIndex {
            // Current card rotates as it's dragged
            let dragRatio = min(max(-1, dragOffset / width), 1)
            return Double(dragRatio) * rotationAngle
        }
        return 0
    }
    
    // Calculate the horizontal offset for each card
    private func offsetForCard(_ card: AnyDexDetailCard) -> CGFloat {
        let cardIndex = cards.firstIndex(where: { $0.id == card.id }) ?? 0
        if cardIndex == currentIndex {
            // Current card moves with drag
            return dragOffset
        } else if cardIndex == currentIndex - 1 {
            // Previous card sits slightly to the left when idle, moves with drag
            return -peekOffset + (dragOffset > 0 ? dragOffset : 0)
        } else if cardIndex == currentIndex + 1 {
            // Next card sits slightly to the right when idle, moves with drag
            return peekOffset + (dragOffset < 0 ? dragOffset : 0)
        }
        return 0
    }
    
    // Set z-index to ensure the proper card stacking
    private func zIndexForCard(_ card: AnyDexDetailCard) -> Double {
        let cardIndex = cards.firstIndex(where: { $0.id == card.id }) ?? 0
        if cardIndex == currentIndex {
            return 10
        } else if cardIndex == currentIndex - 1 && dragOffset > 0 {
            return 5
        } else if cardIndex == currentIndex + 1 && dragOffset < 0 {
            return 5
        }
        return 1
    }
    
    // Scale the cards to create depth effect
    private func scaleForCard(_ card: AnyDexDetailCard, width: CGFloat) -> Double {
        let cardIndex = cards.firstIndex(where: { $0.id == card.id }) ?? 0
        if cardIndex == currentIndex {
            return 1.0
        } else {
            // Scale up as drag progresses
            let dragRatio = min(max(0, abs(dragOffset) / width), 1)
            let direction = (cardIndex < currentIndex && dragOffset > 0) || 
                           (cardIndex > currentIndex && dragOffset < 0)
            
            return direction ? scaleMinimum + (1.0 - scaleMinimum) * Double(dragRatio) : scaleMinimum
        }
    }
    
    private func handleDragEnd(cardWidth: CGFloat) {
        let oldIndex = currentIndex
        withAnimation(.interactiveSpring(response: 0.45, dampingFraction: 0.85)) {
            if abs(dragOffset) > cardWidth * dragThreshold {
                // Advance or go back
                if dragOffset > 0 && currentIndex > 0 {
                    currentIndex -= 1
                } else if dragOffset < 0 && currentIndex < cards.count - 1 {
                    currentIndex += 1
                }
                dragOffset = 0
            } else {
                // Snap back to current card
                dragOffset = 0
            }
            dragDirection = .none
            
            if oldIndex != currentIndex { // Card settled on a new index
                if AppSettings.shared.hapticsLevel != .off {
                    let hapticGenerator = UIImpactFeedbackGenerator(style: .soft)
                    hapticGenerator.prepare()
                    hapticGenerator.impactOccurred()
                }
                SoundManager.shared.playSound(.tapWood)
            }
        }
    }
}

// PixelPageDots removed - replaced with ModernPageIndicator

#Preview {
    // Sample cards for preview
    struct PreviewCard: DexDetailCard {
        var id: Int
        var accentColor: Color = .blue
        var title: String
        
        var body: some View {
            VStack {
                Text(title)
                    .font(.largeTitle)
                    .padding()
                
                RoundedRectangle(cornerRadius: 20)
                    .fill(accentColor.opacity(0.2))
                    .overlay(
                        Text("Card \(id)")
                            .font(.title)
                            .foregroundColor(accentColor)
                    )
            }
            .padding()
            .background(Color.white)
            .cornerRadius(20)
            .padding()
        }
    }
    
    let rawCards = [
        PreviewCard(id: 0, accentColor: .blue, title: "Overview"),
        PreviewCard(id: 1, accentColor: .green, title: "Care"),
        PreviewCard(id: 2, accentColor: .orange, title: "Growth")
    ]
    
    let cards = rawCards.map { AnyDexDetailCard($0) }
    
    return DexCardPager(cards: cards)
        .frame(height: 500)
} 