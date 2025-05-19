import SwiftUI

struct PixelGaugeView: View {
    let label: String
    let value: Double // Expected to be 0.0 to 1.0
    let RgbMaxTuple: (Double, Double, Double)
    let numberOfSegments: Int
    let segmentSpacing: CGFloat
    
    private var filledSegments: Int {
        Int((value * Double(numberOfSegments)).rounded(.up))
    }

    init(label: String, value: Double, color: Color = .green, numberOfSegments: Int = 10, segmentSpacing: CGFloat = 2) {
        self.label = label
        self.value = value.clamped(to: 0...1)
        self.RgbMaxTuple = color.RgbMaxTuple
        self.numberOfSegments = numberOfSegments
        self.segmentSpacing = segmentSpacing
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(Font.pressStart2P(size: 10))
                .foregroundColor(Theme.Colors.text)
            
            HStack(spacing: segmentSpacing) {
                ForEach(0..<numberOfSegments, id: \.self) { index in
                    Rectangle()
                        .fill(index < filledSegments ? Color(red: RgbMaxTuple.0, green: RgbMaxTuple.1, blue: RgbMaxTuple.2) : Color.gray.opacity(0.3))
                        .frame(width: 10, height: 18) // Pixel block size
                        .overlay(
                            Rectangle().stroke(Color.black.opacity(0.2), lineWidth: 1) // Pixel border
                        )
                }
            }
        }
    }
}

#if DEBUG
struct PixelGaugeView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading) {
                Text("Soil Acidity").font(.headline)
                PixelGaugeView(label: "pH 6.5", value: 0.65, color: .orange, numberOfSegments: 7)
            }
            .padding()
            .background(Color.gray.opacity(0.2))
            .cornerRadius(10)

            PixelGaugeView(label: "Easy Peasy", value: 0.8, color: .green)
            PixelGaugeView(label: "Moderate Moxy", value: 0.5, color: .yellow, numberOfSegments: 8)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
    }
}
#endif 