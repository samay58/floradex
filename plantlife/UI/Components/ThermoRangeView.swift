import SwiftUI

struct ThermoRangeView: View {
    // Input: Optimal temperature range (min, max)
    let optimalRange: ClosedRange<Double>
    // Input: Optional current temperature for an indicator
    let currentTemp: Double?
    
    // Define the visual range of the thermometer (e.g., 0°C to 40°C)
    let displayRange: ClosedRange<Double> = 0...40
    
    private let thermometerWidth: CGFloat = 18 // Slightly reduced
    private let thermometerHeight: CGFloat = 120 // Slightly reduced

    // TODO: Parse `SpeciesDetails.temperature` string (e.g., "18°C - 27°C") 
    // into optimalRange: ClosedRange<Double> and optionally currentTemp if available.

    var body: some View {
        // Removed outer VStack and title. Root is now the HStack.
        HStack(spacing: 12) { // Adjusted spacing
            ZStack(alignment: .bottom) {
                Capsule()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: thermometerWidth, height: thermometerHeight)

                let optimalMinY = DampingFunctions.normalizedPosition(value: optimalRange.lowerBound, in: displayRange) * thermometerHeight
                let optimalMaxY = DampingFunctions.normalizedPosition(value: optimalRange.upperBound, in: displayRange) * thermometerHeight
                let optimalHeight = max(0, optimalMaxY - optimalMinY)
                
                Capsule()
                    .fill(Color.green.opacity(0.6))
                    .frame(width: thermometerWidth, height: optimalHeight)
                    .offset(y: -optimalMinY)
                
                if let temp = currentTemp {
                    let currentY = DampingFunctions.normalizedPosition(value: temp, in: displayRange) * thermometerHeight
                    Capsule()
                        .fill(Color.red)
                        .frame(width: thermometerWidth, height: currentY)
                        .overlay(Capsule().stroke(Color.red.opacity(0.5), lineWidth: 1))
                } else {
                    Capsule()
                        .fill(Color.red.opacity(0.8))
                        .frame(width: thermometerWidth, height: thermometerWidth)
                }
                
                Circle()
                    .fill(Color.red)
                    .frame(width: thermometerWidth * 1.8, height: thermometerWidth * 1.8)
                    .offset(y: thermometerWidth * 0.4)
            }
            .frame(width: thermometerWidth, height: thermometerHeight) // Maintain fixed size for the thermometer itself
            .padding(.bottom, thermometerWidth * 0.5) // Ensure bulb has space
            .padding(.leading, 5) // Add a little leading padding if needed from edge of parent

            VStack(alignment: .leading, spacing: 6) { // Adjusted spacing
                Text("Optimal: \(optimalRange.lowerBound, specifier: "%.0f")° - \(optimalRange.upperBound, specifier: "%.0f")°")
                    .font(Font.pressStart2P(size: 10))
                    .foregroundColor(.green)
                if let temp = currentTemp {
                    Text("Current: \(temp, specifier: "%.1f")°")
                        .font(Font.pressStart2P(size: 10))
                        .foregroundColor(.red)
                }
                Text("(\(displayRange.lowerBound, specifier: "%.0f")°-\(displayRange.upperBound, specifier: "%.0f")° scale)") // Subtler display range
                    .font(Font.pressStart2P(size: 8))
                    .foregroundColor(.gray)
            }
            Spacer(minLength: 0) // Allow labels to take natural width, then push
        }
        // Removed outer .padding(), .background(), .cornerRadius()
        // Parent (CareCard) will provide overall padding and background.
        // .frame(height: thermometerHeight + (thermometerWidth * 0.5) + SomePadding) // If parent needs a predictable height for this component
    }
}

// Helper to calculate position in a range (can be in a shared utility file)
// struct DampingFunctions {
// static func normalizedPosition(value: Double, in range: ClosedRange<Double>) -> CGFloat {
//        guard range.upperBound > range.lowerBound else { return 0 }
//        let normalized = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
//        return CGFloat(normalized.clamped(to: 0...1)) // Ensure it's between 0 and 1
//    }
// }

#if DEBUG
struct ThermoRangeView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            VStack {
                Text("Temperature Range").font(.headline)
                ThermoRangeView(optimalRange: 18...27, currentTemp: 22.5)
            }
            .padding()
            .background(Color.gray.opacity(0.2))
            .cornerRadius(10)
            
            ThermoRangeView(optimalRange: 10...15, currentTemp: 12)
            ThermoRangeView(optimalRange: 25...35, currentTemp: nil)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
    }
}
#endif 