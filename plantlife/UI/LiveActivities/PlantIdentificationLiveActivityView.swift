import SwiftUI
import WidgetKit
import ActivityKit

// Ensure PlantIdentificationActivityAttributes is accessible here.
// If it's in the main app target, you might need to ensure this widget target can access it,
// possibly by moving PlantIdentificationActivityAttributes to a shared framework or ensuring
// it's included in this target if Live Activities are in a separate Widget Extension.
// For now, assuming it's accessible.

struct PlantIdentificationLiveActivityView: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PlantIdentificationActivityAttributes.self) { context in
            // Lock screen/banner UI
            LockScreenLiveActivityView(context: context)
                .widgetURL(URL(string: "plantlife://identification/\(context.attributes.initialPlaceholderMessage.toSlug())")) // Example URL
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI (when user long-presses)
                DynamicIslandExpandedRegion(.leading) {
                    LiveActivityImageView(spritePNGData: context.state.spritePNGData, size: 40)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    LiveActivityConfidenceView(confidence: context.state.confidence)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    LiveActivityStatusView(phase: context.state.phase, message: context.state.currentStatusMessage, commonName: context.state.commonName, scientificName: context.state.scientificName)
                }
            } compactLeading: {
                LiveActivityImageView(spritePNGData: context.state.spritePNGData, size: 20)
            } compactTrailing: {
                LiveActivityCompactStatus(phase: context.state.phase, confidence: context.state.confidence)
            } minimal: {
                LiveActivityImageView(spritePNGData: context.state.spritePNGData, size: 20) // Minimal just shows a small sprite or status
            }
            .widgetURL(URL(string: "plantlife://identification/\(context.attributes.initialPlaceholderMessage.toSlug())")) // Example URL
        }
    }
}

// MARK: - Supporting Views

struct LockScreenLiveActivityView: View {
    let context: ActivityViewContext<PlantIdentificationActivityAttributes>

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                LiveActivityImageView(spritePNGData: context.state.spritePNGData, size: 50)
                VStack(alignment: .leading) {
                    Text(context.state.commonName ?? context.state.scientificName ?? context.attributes.initialPlaceholderMessage)
                        .font(.headline)
                    Text(context.state.currentStatusMessage)
                        .font(.subheadline)
                }
                Spacer()
                LiveActivityConfidenceView(confidence: context.state.confidence, showPercentageSign: true)
            }
            ProgressView(value: phaseToProgress(context.state.phase))
                .progressViewStyle(.linear)
        }
        .padding()
        .activityBackgroundTint(Color.black.opacity(0.3))
        .activitySystemActionForegroundColor(Color.white)
    }
    
    private func phaseToProgress(_ phase: IdentificationPhase) -> Double {
        switch phase {
        case .searching: return 0.1
        case .analyzing: return 0.4
        case .processing: return 0.7
        case .almostDone: return 0.9
        case .done: return 1.0
        case .failed: return 1.0 // Or 0.0 if you want to show it stalled
        }
    }
}

struct LiveActivityImageView: View {
    let spritePNGData: Data?
    let size: CGFloat

    var body: some View {
        if let data = spritePNGData, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else {
            // Placeholder: Radar sweep or generic icon
            Image(systemName: "leaf.circle") // Placeholder
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .foregroundColor(.green)
        }
    }
}

struct LiveActivityConfidenceView: View {
    let confidence: Double?
    var showPercentageSign: Bool = false

    var body: some View {
        if let conf = confidence {
            Text("\(String(format: "%.0f", conf * 100))\(showPercentageSign ? "%" : "")")
                .font(.caption.bold())
                .foregroundColor(confidenceColor(conf))
        } else {
            EmptyView()
        }
    }
    
    private func confidenceColor(_ conf: Double) -> Color {
        if conf > 0.75 { return .green }
        if conf > 0.5 { return .yellow }
        return .red
    }
}

struct LiveActivityStatusView: View {
    let phase: IdentificationPhase
    let message: String
    let commonName: String?
    let scientificName: String?

    var body: some View {
        VStack {
            if phase == .done, let name = commonName ?? scientificName {
                Text("Identified: \(name)")
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
            } else {
                Text(message)
                    .font(.caption)
                    .lineLimit(1)
            }
            Text("Tap to open Floradex")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

struct LiveActivityCompactStatus: View {
    let phase: IdentificationPhase
    let confidence: Double?

    var body: some View {
        Group {
            if phase == .done, let conf = confidence {
                LiveActivityConfidenceView(confidence: conf, showPercentageSign: true)
            } else if phase == .searching || phase == .analyzing {
                Image(systemName: "magnifyingglass") // Represents searching/analyzing
                    .transition(.opacity)
            } else if phase == .processing || phase == .almostDone {
                 Image(systemName: "gearshape.arrow.trianglebadge.exclamationmark") // Represents processing
                    .transition(.opacity)
            } else {
                Text(phase.rawValue.prefix(1).uppercased()) // e.g., "S", "A", "D"
                    .font(.caption.bold())
                    .transition(.opacity)
            }
        }
    }
}

// Helper for URL slug
extension String {
    func toSlug() -> String {
        return self.lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .filter { "abcdefghijklmnopqrstuvwxyz0123456789-".contains($0) }
    }
}

// It's good practice to provide previews for your Live Activity views.
// To do this, you'll need to mock ActivityAttributes and ContentState.
// This often requires these structs to be in a place accessible by your main app target AND the widget extension.

#if DEBUG
// Sample Data for Previews
extension PlantIdentificationActivityAttributes {
    static var preview: PlantIdentificationActivityAttributes {
        PlantIdentificationActivityAttributes(initialPlaceholderMessage: "Preview Plant ID")
    }
}

extension PlantIdentificationActivityAttributes.ContentState {
    static var searching: PlantIdentificationActivityAttributes.ContentState {
        .init(phase: .searching, confidence: nil, currentStatusMessage: IdentificationPhase.searching.defaultMessage, scientificName: nil, commonName: nil, spritePNGData: nil)
    }
    static var analyzing: PlantIdentificationActivityAttributes.ContentState {
        .init(phase: .analyzing, confidence: 0.35, currentStatusMessage: IdentificationPhase.analyzing.defaultMessage, scientificName: nil, commonName: nil, spritePNGData: nil)
    }
    static var processing: PlantIdentificationActivityAttributes.ContentState {
        .init(phase: .processing, confidence: 0.65, currentStatusMessage: IdentificationPhase.processing.defaultMessage, scientificName: "Malus domestica", commonName: "Apple Tree", spritePNGData: nil)
    }
    static var done: PlantIdentificationActivityAttributes.ContentState {
        // Create a small sample PNG data for preview if possible
        let sampleSprite = UIImage(systemName: "leaf.fill")?.withTintColor(.green).pngData()
        return .init(phase: .done, confidence: 0.92, currentStatusMessage: IdentificationPhase.done.defaultMessage, scientificName: "Malus domestica", commonName: "Apple Tree", spritePNGData: sampleSprite)
    }
    static var failed: PlantIdentificationActivityAttributes.ContentState {
        .init(phase: .failed, confidence: nil, currentStatusMessage: IdentificationPhase.failed.defaultMessage, scientificName: nil, commonName: nil, spritePNGData: nil)
    }
}

struct PlantIdentificationLiveActivityView_Previews: PreviewProvider {
    static let attributes = PlantIdentificationActivityAttributes.preview
    static let contentStateSearching = PlantIdentificationActivityAttributes.ContentState.searching
    static let contentStateAnalyzing = PlantIdentificationActivityAttributes.ContentState.analyzing
    static let contentStateProcessing = PlantIdentificationActivityAttributes.ContentState.processing
    static let contentStateDone = PlantIdentificationActivityAttributes.ContentState.done
    static let contentStateFailed = PlantIdentificationActivityAttributes.ContentState.failed

    static var previews: some View {
        attributes
            .previewContext(contentStateSearching, viewKind: .dynamicIsland(.compact))
            .previewDisplayName("Compact - Searching")

        attributes
            .previewContext(contentStateAnalyzing, viewKind: .dynamicIsland(.expanded))
            .previewDisplayName("Expanded - Analyzing")
        
        attributes
            .previewContext(contentStateProcessing, viewKind: .dynamicIsland(.expanded))
            .previewDisplayName("Expanded - Processing")
            
        attributes
            .previewContext(contentStateDone, viewKind: .content)
            .previewDisplayName("Lock Screen - Done with Sprite")

        attributes
            .previewContext(contentStateFailed, viewKind: .content)
            .previewDisplayName("Lock Screen - Failed")
            
        attributes
            .previewContext(contentStateSearching, viewKind: .dynamicIsland(.minimal))
            .previewDisplayName("Minimal - Searching")
    }
}
#endif 