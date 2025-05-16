import SwiftUI
import Combine
import UIKit
// import SwiftData // No, SpeciesRepository handles SwiftData specifics

/// Observes the selected image and runs the full classification pipeline, then fetches details.
@MainActor
final class ClassificationViewModel: ObservableObject {
    // Output published to the UI
    @Published var species: String? = nil
    @Published var confidence: Double? = nil
    @Published var isLoading = false
    @Published var details: SpeciesDetails? = nil

    let imageService: ImageSelectionService
    private let classifier = ClassifierService.shared
    private let speciesRepository: SpeciesRepository
    private let apiClient = APIClient.shared // Added for potential general use, though services might be called directly
    private var subscriptions = Set<AnyCancellable>()
    private var classificationTask: Task<Void, Never>?

    // Updated initializer
    init(imageService: ImageSelectionService = .shared, speciesRepository: SpeciesRepository) {
        self.imageService = imageService
        self.speciesRepository = speciesRepository // Added
        bind()
    }

    private func bind() {
        imageService.$selectedImage
            .compactMap { $0 }
            .sink { [weak self] image in
                self?.classificationTask?.cancel()
                self?.classificationTask = Task {
                    await self?.runPipeline(for: image)
                }
            }
            .store(in: &subscriptions)
    }

    private func runPipeline(for image: UIImage) async {
        isLoading = true
        self.species = nil
        self.confidence = nil
        self.details = nil

        let thumbnail = image.resized(maxSide: 600)
        var results: [ClassifierResult] = []
        var finalWinner: ClassifierResult?

        do {
            async let localResultTask = classifier.classifyLocal(thumbnail)
            
            let local = try await localResultTask
            results.append(local)
            
            self.species = local.species
            self.confidence = local.confidence
            triggerHaptic(for: local.confidence)

            if local.confidence >= 0.75 {
                finalWinner = local
            } else {
                async let plantNetResultTask = classifier.classifyPlantNet(thumbnail)
                
                if let plantNet = try? await plantNetResultTask {
                    results.append(plantNet)
                }

                let lastConfidence = results.last?.confidence ?? 0.0
                if lastConfidence < 0.6 {
                    if let gpt = try? await classifier.classifyGPT4o(thumbnail) {
                        results.append(gpt)
                    }
                }
                
                if results.count > 1 {
                    let ensembleOutcome = EnsembleService.vote(results)
                    finalWinner = ClassifierResult(species: ensembleOutcome.species, confidence: ensembleOutcome.confidence, source: .ensemble)
                } else {
                    finalWinner = local // Fallback to local if others fail or aren't run
                }
            }
            
            if let winner = finalWinner, !winner.species.isEmpty, !winner.species.lowercased().contains("unknown") {
                let speciesName = winner.species
                self.species = speciesName
                self.confidence = winner.confidence
                if winner.source != .local { // Avoid double haptic if local was already good enough
                    triggerHaptic(for: winner.confidence)
                }
                // Fetch details using the new method
                self.details = await fetchAndCacheSpeciesDetails(latinName: speciesName)
                print("Loaded details for \(speciesName):", self.details ?? "nil")
            } else {
                // Handle case where no definitive species was identified
                self.species = finalWinner?.species ?? "Identification unclear"
                self.confidence = finalWinner?.confidence ?? 0.0
                self.details = nil
                if finalWinner != nil { // Trigger haptic for low confidence if there was some result
                    triggerHaptic(for: self.confidence ?? 0.0)
                }
                 print("No valid species winner, or winner was 'unknown'. Not fetching details.")
            }

        } catch {
            print("[ClassificationViewModel] Error in pipeline: \(error)")
            self.species = "Error during classification"
            self.confidence = 0
            self.details = nil
        }
        
        isLoading = false
    }

    private func fetchAndCacheSpeciesDetails(latinName: String) async -> SpeciesDetails? {
        // Step 1: Try to fetch from cache
        if let cachedDetails = await speciesRepository.fetchSpeciesDetails(latinName: latinName) {
            print("Found fresh cached details for \(latinName).")
            return cachedDetails
        }
        print("No cached details or details are stale for \(latinName). Fetching from GPT-4o...")

        // Step 2: Fetch complete details from GPT-4o
        do {
            let details = try await GPT4oService.shared.fetchPlantDetails(for: latinName)
            
            // Step 3: Save to cache and return
            await speciesRepository.saveSpeciesDetails(details)
            print("Saved details for \(latinName) to cache.")
            
            return details
        } catch {
            print("Failed to fetch details from GPT-4o for \(latinName): \(error)")
            return nil
        }
    }

    private func triggerHaptic(for confidence: Double) {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        if confidence >= 0.7 {
            generator.notificationOccurred(.success)
        } else if confidence > 0.0 { // Only trigger warning if there's some confidence
            generator.notificationOccurred(.warning)
        }
        // No haptic for 0 confidence or error states handled by pipeline caller
    }
} 