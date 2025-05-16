import SwiftUI
import SwiftData // For preview model container

struct InfoSheetView: View {
    let image: UIImage
    @ObservedObject var classifierVM: ClassificationViewModel
    @State private var showCelebration = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                PhotoCardView(image: image, species: classifierVM.species)
                InfoCardView(species: classifierVM.species,
                             confidence: classifierVM.confidence,
                             details: classifierVM.details,
                             isLoading: classifierVM.isLoading)
            }
            .padding()
        }
        .overlay(
            Group {
                if showCelebration {
                    LottieView(animationName: "confetti")
                        .frame(width: 300, height: 300)
                        .transition(.scale.combined(with: .opacity))
                        .onAppear {
                            let gen = UINotificationFeedbackGenerator()
                            gen.notificationOccurred(.success)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                                withAnimation { showCelebration = false }
                            }
                       }
                }
            }
        )
        .onChange(of: classifierVM.isLoading) { oldLoadingState, newLoadingState in
            if !newLoadingState, oldLoadingState == true, let conf = classifierVM.confidence, conf >= 0.75 {
                withAnimation { showCelebration = true }
            }
        }
    }
}

// MARK: - Sub-Views (Placeholders if not defined elsewhere)
// These are here to make InfoSheetView compilable for previews if they aren't in separate files yet.
// Ideally, these would be in their own files with their own previews.

#if DEBUG && false
struct PhotoCardView_Placeholder: View {
    var body: some View {
        VStack {
            Image(systemName: "photo")
                .resizable()
                .scaledToFit()
                .frame(height: 200)
                .cornerRadius(12)
                .overlay(alignment: .bottomLeading) {
                    VStack(alignment: .leading) {
                        Text("Identifying...")
                            .font(.title2).bold()
                    }
                    .padding()
                    .background(Color.black.opacity(0.3))
                    .foregroundColor(.white)
                    .cornerRadius(8, corners: [.bottomLeft])
                }
        }
        .redacted(reason: .placeholder)
    }
}
#endif

// Duplicate definitions are commented out to avoid redeclaration
#if DEBUG && false
struct PhotoCardView: View { }
#if DEBUG && false
struct InfoCardView_Duplicate: View { }
#endif
#endif

// MARK: - Preview Content

// Mock Data
extension SpeciesDetails {
    static var mockMonstera: SpeciesDetails {
        SpeciesDetails(latinName: "Monstera deliciosa",
                       commonName: "Swiss Cheese Plant",
                       summary: "A popular and easy-to-care-for houseplant known for its large, glossy, perforated leaves. It enjoys bright, indirect light and moderate watering.",
                       growthHabit: "Climbing vine",
                       sunlight: "Bright, indirect light",
                       water: "Water when top 2 inches of soil are dry",
                       soil: "Well-draining potting mix",
                       temperature: "18-27°C (65-80°F)",
                       bloomTime: "Rarely indoors, but can produce spadix flowers",
                       funFacts: ["Native to tropical forests of Central America.", "The holes in its leaves are called fenestrations.", "Can grow very large if given space and support."],
                       lastUpdated: Date())
    }

    static var mockPartiallyPopulated: SpeciesDetails {
        SpeciesDetails(latinName: "Planta incompleta",
                       commonName: "Mystery Shrub",
                       summary: "Found in the backyard. Not much is known yet.",
                       lastUpdated: Date())
    }
    
    static var mockEmpty: SpeciesDetails {
        SpeciesDetails.empty(latin: "Species Ignotus")
    }
}

// Preview Helper for Repository and ViewModels
struct PreviewHelpers {
    static var previewImage: UIImage {
        // Create a simple placeholder UIImage for previews
        UIGraphicsBeginImageContextWithOptions(CGSize(width: 100, height: 100), false, 0.0)
        UIColor.systemGreen.setFill()
        UIRectFill(CGRect(x: 0, y: 0, width: 100, height: 100))
        let image = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return image
    }

    @MainActor
    static func inMemoryRepository() -> SpeciesRepository {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: SpeciesDetails.self, configurations: config)
        // Optionally pre-populate with mock data:
        // container.mainContext.insert(SpeciesDetails.mockMonstera)
        return SpeciesRepository(modelContext: container.mainContext)
    }

    @MainActor
    static var mockLoadingVM: ClassificationViewModel {
        let vm = ClassificationViewModel(speciesRepository: inMemoryRepository())
        vm.isLoading = true
        vm.species = "Identifying..."
        return vm
    }

    @MainActor
    static var mockLoadedVM: ClassificationViewModel {
        let vm = ClassificationViewModel(speciesRepository: inMemoryRepository())
        vm.species = "Monstera deliciosa"
        vm.confidence = 0.92
        vm.details = .mockMonstera
        vm.isLoading = false
        return vm
    }
    
    @MainActor
    static var mockPartialDataVM: ClassificationViewModel {
        let vm = ClassificationViewModel(speciesRepository: inMemoryRepository())
        vm.species = "Planta incompleta"
        vm.confidence = 0.65
        vm.details = .mockPartiallyPopulated
        vm.isLoading = false
        return vm
    }
    
    @MainActor
    static var mockNoDetailsVM: ClassificationViewModel {
        let vm = ClassificationViewModel(speciesRepository: inMemoryRepository())
        vm.species = "Species Ignotus"
        vm.confidence = 0.40
        vm.details = .mockEmpty // Or nil if that's a state to test
        vm.isLoading = false
        return vm
    }
}

// Previews
#Preview("Loading State") {
    InfoSheetView(image: PreviewHelpers.previewImage, 
                  classifierVM: PreviewHelpers.mockLoadingVM)
        .modelContainer(try! ModelContainer(for: SpeciesDetails.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
}

#Preview("Loaded State - Monstera") {
    InfoSheetView(image: PreviewHelpers.previewImage, 
                  classifierVM: PreviewHelpers.mockLoadedVM)
        .modelContainer(try! ModelContainer(for: SpeciesDetails.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
}

#Preview("Partial Data State") {
    InfoSheetView(image: PreviewHelpers.previewImage, 
                  classifierVM: PreviewHelpers.mockPartialDataVM)
        .modelContainer(try! ModelContainer(for: SpeciesDetails.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
}

#Preview("No Details State") {
    InfoSheetView(image: PreviewHelpers.previewImage, 
                  classifierVM: PreviewHelpers.mockNoDetailsVM)
        .modelContainer(try! ModelContainer(for: SpeciesDetails.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
}