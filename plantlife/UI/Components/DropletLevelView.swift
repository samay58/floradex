import SwiftUI

struct DropletLevelView: View {
    // Input: Current moisture level (0.0 to 1.0)
    @Binding var currentMoisture: Double // This will be the value set by dragging
    // Input: Optimal/target moisture level for the plant (0.0 to 1.0) - for display
    let optimalMoisture: Double? // From SpeciesDetails.water (needs parsing & normalization)
    
    @State private var isDragging: Bool = false // Simplified drag state
    
    private let dropletWidth: CGFloat = 70 // Slightly reduced size
    private let dropletHeight: CGFloat = 100 // Slightly reduced size

    // TODO: Parse `SpeciesDetails.water` string (e.g., "Keep moist", "Water moderately") 
    // into a normalized optimalMoisture: Double (0.0-1.0) and perhaps a descriptive text.

    var body: some View {
        HStack(spacing: 0) { // Reduced spacing, main content is the ZStack for the droplet
            Spacer(minLength: 0) // Use spacers to center the droplet if parent doesn't
            ZStack(alignment: .bottom) {
                DropletShape()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: dropletWidth, height: dropletHeight)

                DropletShape()
                    .fill(LinearGradient(colors: [Color.blue.opacity(0.5), Color.blue], startPoint: .bottom, endPoint: .top))
                    .frame(width: dropletWidth, height: CGFloat(currentMoisture) * dropletHeight)
                    .mask(DropletShape().frame(width: dropletWidth, height: dropletHeight))
                
                if let optimal = optimalMoisture {
                    Rectangle()
                        .fill(Color.green.opacity(0.7))
                        .frame(width: dropletWidth + 4, height: 2)
                        .offset(y: -((CGFloat(optimal) * dropletHeight) - (dropletHeight / 2)))
                }
            }
            .frame(width: dropletWidth, height: dropletHeight) // Maintain droplet frame
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isDragging = true
                        let dragValue = -value.translation.height
                        // Calculate new fill height based on total drag from start of gesture on the fillable area
                        // This needs to consider the initial currentMoisture value before drag began.
                        // For simplicity, let's adjust based on proportion of drag relative to droplet height.
                        let dragProportion = dragValue / dropletHeight
                        currentMoisture = (currentMoisture + dragProportion).clamped(to: 0...1)
                        // To avoid overly fast changes, might need to store initial moisture on gesture start
                        // and calculate new moisture based on initial + delta.
                        // For now, this direct update might be jumpy if not handled carefully.
                    }
                    .onEnded { _ in
                        isDragging = false
                        if AppSettings.shared.hapticsLevel != .off {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                    }
            )
            .overlay(
                Text(String(format: "%.0f%%", currentMoisture * 100))
                    .font(Font.pressStart2P(size: 10))
                    .foregroundColor(isDragging ? Theme.Colors.accent(for: "Water") : .white)
                    .padding(6)
                    .background(isDragging ? Color.white.opacity(0.8) : Color.black.opacity(0.3))
                    .clipShape(Capsule())
                    .offset(y: isDragging ? -dropletHeight * 0.7 : -dropletHeight * 0.5) // Adjusted offset
                    .animation(.spring(), value: isDragging)
            )
            Spacer(minLength: 0)
        }
        // Removed outer .padding(), .background(), .cornerRadius()
        // The parent (CareCard) will manage padding around this component.
        // Add a fixed height for the whole component if needed by parent layout.
        // .frame(height: dropletHeight + 40) // Example: to include space for overlay text
    }
}

// Custom Droplet Shape
struct DropletShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        // Approximate droplet shape. Can be refined or replaced with SVG/Image.
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.height * 0.6), 
                          control: CGPoint(x: rect.maxX, y: rect.maxY * 0.9))
        path.addCurve(to: CGPoint(x: rect.midX, y: rect.minY), 
                      control1: CGPoint(x: rect.maxX, y: rect.height * 0.2), 
                      control2: CGPoint(x: rect.midX + rect.width * 0.2, y: rect.minY))
        path.addCurve(to: CGPoint(x: rect.minX, y: rect.height * 0.6), 
                      control1: CGPoint(x: rect.midX - rect.width * 0.2, y: rect.minY), 
                      control2: CGPoint(x: rect.minX, y: rect.height * 0.2))
        path.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.maxY), 
                          control: CGPoint(x: rect.minX, y: rect.maxY * 0.9))
        path.closeSubpath()
        return path
    }
}

#if DEBUG
struct DropletLevelView_Previews: PreviewProvider {
    @State static var moisture1: Double = 0.65
    @State static var moisture2: Double = 0.20

    static var previews: some View {
        VStack(spacing: 30) {
            VStack {
                Text("Water Needs").font(.headline)
                DropletLevelView(currentMoisture: $moisture1, optimalMoisture: 0.75)
                    .frame(height: 150) // Give it some frame for preview layout
            }
            .padding()
            .background(Color.gray.opacity(0.2))
            .cornerRadius(10)
            
            DropletLevelView(currentMoisture: $moisture2, optimalMoisture: 0.5)
                .frame(height: 150)

            Text("Drag droplets to change moisture level.")
        }
        .padding()
        .background(Color.gray.opacity(0.1))
    }
}
#endif

// Extension from DexGrid, ensure it's accessible or moved to a shared location
// extension Comparable {
//    func clamped(to limits: ClosedRange<Self>) -> Self {
//        return min(max(self, limits.lowerBound), limits.upperBound)
//    }
// } 