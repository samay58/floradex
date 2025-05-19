import SwiftUI

enum PlantInfo {
    struct InfoRow: View {
        let label: String
        let value: String?
        let accentColor: Color

        private var valueText: String {
            guard let val = value, !val.isEmpty, val.lowercased() != "unknown" else {
                return "N/A"
            }
            return val
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: Theme.Metrics.Padding.small) {
                    Image(systemName: iconName(for: label))
                        .foregroundColor(accentColor)
                        .frame(width: 25, alignment: .center)
                    
                    Text(label)
                        .font(.headline)
                        .fixedSize(horizontal: true, vertical: false)

                    Text(valueText)
                        .font(.body)
                        .foregroundColor(valueText == "N/A" ? Theme.Colors.textDisabled : Theme.Colors.text)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Divider()
                    .padding(.top, Theme.Metrics.Padding.small)
                    .padding(.leading, 25 + Theme.Metrics.Padding.small)
            }
        }
        
        private func iconName(for label: String) -> String {
            switch label.lowercased() {
            case "sunlight": return "sun.max.fill"
            case "water": return "drop.fill"
            case "soil": return "mountain.2.fill"
            case "details": return "doc.text.magnifyingglass"
            case "temperature": return "thermometer.medium"
            case "growth habit": return "arrow.up.right.circle.fill"
            case "bloom time": return "camera.macro"
            case "care difficulty": return "figure.mind.and.body"
            case "level": return "chart.bar.xaxis"
            default: return "circle.fill"
            }
        }
    }
}

#if DEBUG
struct InfoRow_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 10) {
            PlantInfo.InfoRow(label: "Sunlight", value: "Bright, indirect light", accentColor: .orange)
            PlantInfo.InfoRow(label: "Water", value: "Moderate", accentColor: .blue)
            PlantInfo.InfoRow(label: "Soil", value: nil, accentColor: .brown)
            PlantInfo.InfoRow(label: "Temperature", value: "Unknown", accentColor: .red)
            PlantInfo.InfoRow(label: "Growth Habit", value: "Climbing vine that can grow very large if given enough support and space", accentColor: .green)
        }
        .padding()
    }
}
#endif 