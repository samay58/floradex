import SwiftUI

enum PlantInfo {
    struct InfoRow: View {
        let label: String
        let value: String?
        let accentColor: Color

        var body: some View {
            if let value = value, !value.isEmpty, value.lowercased() != "unknown" {
                HStack(alignment: .top) {
                    Image(systemName: iconName(for: label))
                        .foregroundColor(accentColor)
                        .frame(width: 25, alignment: .center)
                    Text(label)
                        .font(.headline)
                        .frame(width: 120, alignment: .leading)
                    Text(value)
                        .font(.body)
                    Spacer()
                }
                Divider()
            }
        }
        
        private func iconName(for label: String) -> String {
            switch label.lowercased() {
            case "sunlight": return "sun.max.fill"
            case "water": return "drop.fill"
            case "soil": return "mountain.2.fill"
            case "temperature": return "thermometer.medium"
            case "growth habit": return "arrow.up.right.circle.fill"
            case "bloom time": return "camera.macro"
            case "care difficulty": return "figure.mind.and.body"
            default: return "circle.fill"
            }
        }
    }
}

#if DEBUG
struct InfoRow_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            PlantInfo.InfoRow(label: "Sunlight", value: "Bright, indirect light", accentColor: .orange)
            PlantInfo.InfoRow(label: "Water", value: "Moderate", accentColor: .blue)
            PlantInfo.InfoRow(label: "Soil", value: "Well-draining", accentColor: .brown)
            PlantInfo.InfoRow(label: "Temperature", value: "18-24°C", accentColor: .red)
        }
        .padding()
    }
}
#endif 