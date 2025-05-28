import SwiftUI
import UIKit
import CryptoKit // Added for image hashing
// import SwiftData // No, SpeciesRepository handles SwiftData specifics

/// Observes the selected image and runs the full classification pipeline, then fetches details.
@MainActor
final class ClassificationViewModel: ObservableObject {
    // Output published to the UI
    @Published var species: String? = nil
    @Published var confidence: Double? = nil
    @Published var isLoading = false
    @Published var details: SpeciesDetails? = nil
    @Published var currentDexEntry: DexEntry? = nil // To observe the new entry

    let imageService: ImageSelectionService
    private let classifier = ClassifierService.shared
    private let speciesRepository: SpeciesRepository
    private let dexRepository: DexRepository // Added DexRepository
    private let spriteService = SpriteService.shared // Added SpriteService
    private let apiClient = APIClient.shared // Added for potential general use, though services might be called directly
    private var classificationTask: Task<Void, Never>?
    private var currentImageHash: String? = nil // Track current image to prevent duplicate processing

    // Updated initializer
    init(imageService: ImageSelectionService = .shared, 
         speciesRepository: SpeciesRepository, 
         dexRepository: DexRepository) { // Added dexRepository
        self.imageService = imageService
        self.speciesRepository = speciesRepository
        self.dexRepository = dexRepository // Initialize dexRepository
        // No longer calling bind() - processing is triggered manually
    }
    
    /// Manually process the selected image when user taps Identify
    func processSelectedImage() async {
        guard let image = imageService.selectedImage else { return }
        
        print("[ClassificationViewModel] Manual processing triggered")
        
        // Cancel any existing task first
        classificationTask?.cancel()
        
        // Generate image hash for deduplication
        let imageHash = generateImageHash(image)
        
        // Skip if we're already processing this exact image or if we're loading
        if currentImageHash == imageHash && isLoading {
            print("[ClassificationViewModel] Already processing this image, skipping...")
            return
        }
        
        // Reset state before starting new pipeline
        species = nil
        confidence = nil
        details = nil
        currentDexEntry = nil
        currentImageHash = imageHash
        
        // Start new pipeline
        await runPipeline(for: image)
    }
    
    /// Generate a hash for image content to enable deduplication
    private func generateImageHash(_ image: UIImage) -> String {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            return UUID().uuidString
        }
        let hash = SHA256.hash(data: imageData)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    /// Public method to cleanup when view is dismissed
    func cleanup() {
        print("[ClassificationViewModel] Cleaning up...")
        classificationTask?.cancel()
        classificationTask = nil
        isLoading = false
        currentImageHash = nil
        species = nil
        confidence = nil
        details = nil
        currentDexEntry = nil
    }
    
    deinit {
        // Cleanup is handled automatically when subscriptions are deallocated
        // Can't call @MainActor methods from deinit
    }

    private func runPipeline(for image: UIImage) async {
        // Guard against concurrent executions
        guard !isLoading else {
            print("[ClassificationViewModel] Pipeline already running, skipping...")
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        self.species = nil
        self.confidence = nil
        self.details = nil
        self.currentDexEntry = nil

        print("[ClassificationViewModel] Starting plant identification...")

        guard let thumbnail = UIImage.ImageProcessing.resized(image, maxSide: 600) else {
            print("Failed to resize image for classification")
            return
        }
        
        let fullSnapshotImage = image
        var results: [ClassifierResult] = []
        var finalWinner: ClassifierResult?
        var finalDetails: SpeciesDetails? = nil
        var finalSpriteData: Data? = nil

        do {
            print("[ClassificationViewModel] Analyzing with local model...")
            async let localResultTask = classifier.classifyLocal(thumbnail)
            
            let local = try await localResultTask
            results.append(local)
            
            self.species = local.species
            self.confidence = local.confidence
            triggerHaptic(for: local.confidence)
            print("[ClassificationViewModel] Local model: \(local.species) (\(String(format: "%.0f%%", local.confidence * 100)))")

            if local.confidence >= 0.75 {
                finalWinner = local
            } else {
                print("[ClassificationViewModel] Seeking second opinion (PlantNet)...")
                async let plantNetResultTask = classifier.classifyPlantNet(thumbnail)
                
                if let plantNet = try? await plantNetResultTask {
                    results.append(plantNet)
                    print("[ClassificationViewModel] PlantNet: \(plantNet.species) (\(String(format: "%.0f%%", plantNet.confidence * 100)))")
                }

                let lastConfidence = results.last?.confidence ?? 0.0
                if lastConfidence < 0.6 {
                    print("[ClassificationViewModel] Consulting expert (GPT-4o)...")
                    if let gpt = try? await classifier.classifyGPT4o(thumbnail) {
                        results.append(gpt)
                        print("[ClassificationViewModel] GPT-4o: \(gpt.species) (\(String(format: "%.0f%%", gpt.confidence * 100)))")
                    }
                }
                
                if results.count > 1 {
                    print("[ClassificationViewModel] Compiling results...")
                    let ensembleOutcome = EnsembleService.vote(results)
                    finalWinner = ClassifierResult(species: ensembleOutcome.species, confidence: ensembleOutcome.confidence, source: .ensemble)
                } else {
                    finalWinner = local
                }
            }
            
            if let winner = finalWinner, !winner.species.isEmpty, !winner.species.lowercased().contains("unknown") {
                let speciesName = winner.species
                self.species = speciesName
                self.confidence = winner.confidence
                if winner.source != .local {
                    triggerHaptic(for: winner.confidence)
                }

                print("[ClassificationViewModel] Fetching details for \(speciesName)...")
                finalDetails = await fetchAndCacheSpeciesDetails(latinName: speciesName)
                self.details = finalDetails
                print("Loaded details for \(speciesName):", self.details ?? "nil")

                if let fetchedDetails = self.details {
                    print("[ClassificationViewModel] Saving to Dex: \(fetchedDetails.commonName ?? speciesName)...")
                    do {
                        // SwiftData operations already on main thread since this class is @MainActor
                        let newEntry = try await dexRepository.addEntry(
                            latinName: fetchedDetails.latinName,
                            snapshot: fullSnapshotImage,
                            tags: []
                        )
                        self.currentDexEntry = newEntry
                        print("Created DexEntry with ID: \(newEntry.id) for \(fetchedDetails.latinName)")
                        
                        // Generate sprite in background
                        Task.detached(priority: .background) {
                            print("[ClassificationViewModel] Sprite generation task starting for DexEntry ID: \(newEntry.id), Latin Name: \(fetchedDetails.latinName)")
                            do {
                                finalSpriteData = try await self.spriteService.generateSprite(
                                    forCommonName: fetchedDetails.commonName ?? fetchedDetails.latinName, 
                                    latinName: fetchedDetails.latinName
                                )
                                print("[ClassificationViewModel] Sprite data received from service for DexEntry ID: \(newEntry.id). Size: \(finalSpriteData?.count ?? 0). Attempting to update repository.")
                                
                                // Simplify sprite update on MainActor
                                if let spriteData = finalSpriteData {
                                    // All repository operations must happen on MainActor
                                    do {
                                        print("[ClassificationViewModel] Updating DexEntry ID: \(newEntry.id)")
                                        try await self.dexRepository.updateSprite(for: newEntry.id, spriteData: spriteData)
                                        print("[ClassificationViewModel] Successfully called dexRepository.updateSprite for DexEntry ID: \(newEntry.id)")
                                        
                                        // Update the local currentDexEntry to reflect the change immediately
                                        await MainActor.run {
                                            self.currentDexEntry?.sprite = spriteData
                                            self.currentDexEntry?.spriteGenerationFailed = false
                                            print("[ClassificationViewModel] Updated local currentDexEntry's sprite for ID: \(newEntry.id)")
                                        }
                                    } catch {
                                        print("[ClassificationViewModel] Error updating sprite in repository for DexEntry ID: \(newEntry.id): \(error)")
                                        // Mark as failed if the update fails
                                        try? await self.dexRepository.markSpriteGenerationFailed(for: newEntry.id)
                                        await MainActor.run {
                                            self.currentDexEntry?.spriteGenerationFailed = true
                                        }
                                    }
                                }
                            } catch {
                                print("[ClassificationViewModel] Sprite generation task failed for DexEntry ID: \(newEntry.id), Latin Name: \(fetchedDetails.latinName): \(error)")
                                // Mark sprite generation as failed - must be on MainActor
                                try? await self.dexRepository.markSpriteGenerationFailed(for: newEntry.id)
                                await MainActor.run {
                                    self.currentDexEntry?.spriteGenerationFailed = true
                                    print("[ClassificationViewModel] Marked sprite generation failed for DexEntry ID: \(newEntry.id) due to service error.")
                                }
                            }
                        }
                        print("[ClassificationViewModel] Successfully identified: \(fetchedDetails.commonName ?? speciesName)!")

                    } catch {
                        print("Failed to create DexEntry: \(error)")
                    }
                } else { // Details fetch failed
                    print("Failed to fetch details for \(speciesName).")
                }

            } else { // No definitive winner or unknown
                self.species = finalWinner?.species ?? "Identification unclear"
                self.confidence = finalWinner?.confidence ?? 0.0
                self.details = nil
                if finalWinner != nil { triggerHaptic(for: self.confidence ?? 0.0) }
                print("No valid species winner, or winner was 'unknown'.")
            }

        } catch {
            print("[ClassificationViewModel] Error in pipeline: \(error)")
            self.species = "Error during classification"
            self.confidence = 0
            self.details = nil
        }
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
        let hapticsLevel = AppSettings.shared.hapticsLevel
        guard hapticsLevel != .off else { return }
        
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        if confidence >= 0.7 {
            generator.notificationOccurred(.success)
            SoundManager.shared.playSound(.successJingle) // Play success sound
        } else if confidence > 0.0 { // Only trigger warning if there's some confidence
            // For minimal haptics, only play success, not warning.
            if hapticsLevel == .full {
                generator.notificationOccurred(.warning)
            }
        }
        // No haptic for 0 confidence or error states handled by pipeline caller
    }
} 