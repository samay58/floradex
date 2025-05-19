import SwiftUI
import Combine
import UIKit
import ActivityKit // Added for Live Activities
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
    private var subscriptions = Set<AnyCancellable>()
    private var classificationTask: Task<Void, Never>?
    private var currentActivity: Activity<PlantIdentificationActivityAttributes>? = nil // For Live Activity

    // Updated initializer
    init(imageService: ImageSelectionService = .shared, 
         speciesRepository: SpeciesRepository, 
         dexRepository: DexRepository) { // Added dexRepository
        self.imageService = imageService
        self.speciesRepository = speciesRepository
        self.dexRepository = dexRepository // Initialize dexRepository
        bind()
    }

    private func bind() {
        imageService.$selectedImage
            .compactMap { $0 }
            .sink { [weak self] image in
                self?.classificationTask?.cancel()
                // Also end any ongoing Live Activity if a new image is selected
                Task { await self?.endPlantIdentificationActivity(finalPhase: .failed, finalData: nil) }
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
        self.currentDexEntry = nil

        await startPlantIdentificationActivity() // Phase implicitly .searching by startPlantIdentificationActivity

        guard let thumbnail = UIImage.ImageProcessing.resized(image, maxSide: 600) else {
            print("Failed to resize image for classification")
            isLoading = false
            let finalData = PlantIdentificationActivityAttributes.ContentState(phase: .failed, confidence: nil, currentStatusMessage: IdentificationPhase.failed.defaultMessage, scientificName: nil, commonName: nil, spritePNGData: nil)
            await endPlantIdentificationActivity(finalPhase: .failed, finalData: finalData)
            return
        }
        
        let fullSnapshotImage = image
        var results: [ClassifierResult] = []
        var finalWinner: ClassifierResult?
        var finalDetails: SpeciesDetails? = nil
        var finalSpriteData: Data? = nil

        do {
            await updatePlantIdentificationActivity(phase: .analyzing, message: "Analyzing with local model...")
            async let localResultTask = classifier.classifyLocal(thumbnail)
            
            let local = try await localResultTask
            results.append(local)
            
            self.species = local.species
            self.confidence = local.confidence
            triggerHaptic(for: local.confidence)
            await updatePlantIdentificationActivity(phase: .analyzing, confidence: local.confidence, message: "Local model: \(local.species) (\(String(format: "%.0f%%", local.confidence * 100)))")

            if local.confidence >= 0.75 {
                finalWinner = local
            } else {
                await updatePlantIdentificationActivity(phase: .analyzing, confidence: local.confidence, message: "Seeking second opinion (PlantNet)...")
                async let plantNetResultTask = classifier.classifyPlantNet(thumbnail)
                
                if let plantNet = try? await plantNetResultTask {
                    results.append(plantNet)
                    await updatePlantIdentificationActivity(phase: .analyzing, confidence: plantNet.confidence, message: "PlantNet: \(plantNet.species) (\(String(format: "%.0f%%", plantNet.confidence * 100)))")
                }

                let lastConfidence = results.last?.confidence ?? 0.0
                if lastConfidence < 0.6 {
                    await updatePlantIdentificationActivity(phase: .analyzing, confidence: lastConfidence, message: "Consulting expert (GPT-4o)...")
                    if let gpt = try? await classifier.classifyGPT4o(thumbnail) {
                        results.append(gpt)
                         await updatePlantIdentificationActivity(phase: .analyzing, confidence: gpt.confidence, message: "GPT-4o: \(gpt.species) (\(String(format: "%.0f%%", gpt.confidence * 100)))")
                    }
                }
                
                if results.count > 1 {
                    await updatePlantIdentificationActivity(phase: .analyzing, message: "Compiling results...")
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

                await updatePlantIdentificationActivity(phase: .processing, confidence: winner.confidence, message: "Fetching details for \(speciesName)...")
                finalDetails = await fetchAndCacheSpeciesDetails(latinName: speciesName)
                self.details = finalDetails
                print("Loaded details for \(speciesName):", self.details ?? "nil")

                if let fetchedDetails = self.details {
                    await updatePlantIdentificationActivity(phase: .almostDone, confidence: winner.confidence, message: "Saving to Dex: \(fetchedDetails.commonName ?? speciesName)...")
                    do {
                        let newEntry = try await dexRepository.addEntry(
                            latinName: fetchedDetails.latinName,
                            snapshot: fullSnapshotImage,
                            tags: []
                        )
                        self.currentDexEntry = newEntry
                        print("Created DexEntry with ID: \(newEntry.id) for \(fetchedDetails.latinName)")
                        
                        Task.detached(priority: .background) {
                            print("Starting sprite generation for \(fetchedDetails.latinName)...")
                            // No Live Activity update from here as it's background and might be slow.
                            // The main flow will end the activity. If sprite is fast, could update.
                            // For now, sprite update on DexEntry is handled separately.
                            // We can pass the sprite to endPlantIdentificationActivity if ready by then.
                            do {
                                finalSpriteData = try await self.spriteService.generateSprite(
                                    forCommonName: fetchedDetails.commonName ?? fetchedDetails.latinName, 
                                    latinName: fetchedDetails.latinName
                                )
                                try await self.dexRepository.updateSprite(for: newEntry.id, spriteData: finalSpriteData!)
                                print("Successfully generated and saved sprite for DexEntry ID: \(newEntry.id)")
                                await MainActor.run {
                                    self.currentDexEntry?.sprite = finalSpriteData
                                    self.currentDexEntry?.spriteGenerationFailed = false
                                    // Potentially update live activity IF it's still active and sprite is critical for 'done' state
                                    // For simplicity, we'll pass sprite data at the end of the main pipeline
                                }
                            } catch {
                                print("Sprite generation failed for \(fetchedDetails.latinName): \(error)")
                                try await self.dexRepository.markSpriteGenerationFailed(for: newEntry.id)
                                print("Marked sprite generation failed for DexEntry ID: \(newEntry.id)")
                                await MainActor.run {
                                    self.currentDexEntry?.spriteGenerationFailed = true
                                }
                            }
                        }
                        // Successfully identified and saved
                        let finalData = PlantIdentificationActivityAttributes.ContentState(
                            phase: .done,
                            confidence: winner.confidence,
                            currentStatusMessage: "Identified: \(fetchedDetails.commonName ?? speciesName)!",
                            scientificName: fetchedDetails.latinName,
                            commonName: fetchedDetails.commonName,
                            spritePNGData: self.currentDexEntry?.sprite // Use sprite if available by now
                        )
                        await endPlantIdentificationActivity(finalPhase: .done, finalData: finalData)

                    } catch {
                        print("Failed to create DexEntry: \(error)")
                        let finalData = PlantIdentificationActivityAttributes.ContentState(phase: .failed, confidence: winner.confidence, currentStatusMessage: "Failed to save to Dex.", scientificName: winner.species, commonName: nil, spritePNGData: nil)
                        await endPlantIdentificationActivity(finalPhase: .failed, finalData: finalData)
                    }
                } else { // Details fetch failed
                    print("Failed to fetch details for \(speciesName).")
                     let finalData = PlantIdentificationActivityAttributes.ContentState(phase: .failed, confidence: winner.confidence, currentStatusMessage: "Failed to get details for \(speciesName).", scientificName: speciesName, commonName: nil, spritePNGData: nil)
                    await endPlantIdentificationActivity(finalPhase: .failed, finalData: finalData)
                }

            } else { // No definitive winner or unknown
                self.species = finalWinner?.species ?? "Identification unclear"
                self.confidence = finalWinner?.confidence ?? 0.0
                self.details = nil
                if finalWinner != nil { triggerHaptic(for: self.confidence ?? 0.0) }
                print("No valid species winner, or winner was 'unknown'.")
                let finalData = PlantIdentificationActivityAttributes.ContentState(phase: .failed, confidence: self.confidence, currentStatusMessage: self.species ?? "Identification failed.", scientificName: self.species, commonName: nil, spritePNGData: nil)
                await endPlantIdentificationActivity(finalPhase: .failed, finalData: finalData)
            }

        } catch {
            print("[ClassificationViewModel] Error in pipeline: \(error)")
            self.species = "Error during classification"
            self.confidence = 0
            self.details = nil
            let finalData = PlantIdentificationActivityAttributes.ContentState(phase: .failed, confidence: 0, currentStatusMessage: "Error during classification.", scientificName: nil, commonName: nil, spritePNGData: nil)
            await endPlantIdentificationActivity(finalPhase: .failed, finalData: finalData)
        }
        
        isLoading = false
        // Activity is ended by various paths within the do/catch block
    }

    private func startPlantIdentificationActivity() async {
        guard FeatureFlags.isEnabled(.liveActivity) else {
            print("Live Activity feature is disabled via feature flag.")
            return
        }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("Live Activities are not enabled by the user.")
            return
        }

        // Use a generic initial message for the static attribute
        let attributes = PlantIdentificationActivityAttributes(initialPlaceholderMessage: "Identifying your plant...")
        let initialPhase = IdentificationPhase.searching
        let initialState = PlantIdentificationActivityAttributes.ContentState(
            phase: initialPhase,
            confidence: nil,
            currentStatusMessage: initialPhase.defaultMessage,
            scientificName: nil, 
            commonName: nil,
            spritePNGData: nil
        )

        do {
            let activity = try Activity<PlantIdentificationActivityAttributes>.request(
                attributes: attributes,
                contentState: initialState, // Use the refined ContentState
                pushType: nil
            )
            self.currentActivity = activity
            print("Requested Live Activity: \(activity.id)")
        } catch (let error) {
            print("Error requesting Live Activity: \(error.localizedDescription)")
        }
    }

    private func updatePlantIdentificationActivity(phase: IdentificationPhase, confidence: Double? = nil, message: String? = nil, scientificName: String? = nil, commonName: String? = nil, spriteData: Data? = nil) async {
        guard FeatureFlags.isEnabled(.liveActivity) else { return } // Also guard updates
        guard let activity = currentActivity, activity.activityState == .active else { return }
        
        // Preserve existing ContentState values if not provided in update
        let currentContent = activity.contentState
        
        let newPhase = phase
        let newStatusMessage = message ?? newPhase.defaultMessage
        let updatedState = PlantIdentificationActivityAttributes.ContentState(
            phase: newPhase,
            confidence: confidence ?? currentContent.confidence,
            currentStatusMessage: newStatusMessage,
            scientificName: scientificName ?? currentContent.scientificName,
            commonName: commonName ?? currentContent.commonName,
            spritePNGData: spriteData ?? currentContent.spritePNGData
        )
        
        print("Updating Live Activity: \(activity.id) to phase \(newPhase.rawValue)")
        await activity.update(using: updatedState) // Use the refined ContentState
    }

    // Method to end the activity with final data
    private func endPlantIdentificationActivity(finalPhase: IdentificationPhase, finalData: PlantIdentificationActivityAttributes.ContentState?) async {
        guard FeatureFlags.isEnabled(.liveActivity) else { // Also guard ending
            self.currentActivity = nil // Ensure it's cleared if flag is off but somehow an activity existed
            return
        }
        guard let activity = currentActivity else { return }
        
        // If the activity is already ended or dismissed, don't try to end it again.
        guard activity.activityState == .active || activity.activityState == .stale else {
            print("Activity \(activity.id) is already \(activity.activityState), not ending again.")
            self.currentActivity = nil // Ensure it's cleared if somehow missed
            return
        }

        let finalContentStateToUse: PlantIdentificationActivityAttributes.ContentState
        if let data = finalData {
            finalContentStateToUse = data
        } else {
            // Fallback if no specific finalData provided, though this should be rare
            finalContentStateToUse = PlantIdentificationActivityAttributes.ContentState(
                phase: finalPhase,
                confidence: self.confidence, // Use VM's current confidence
                currentStatusMessage: finalPhase.defaultMessage,
                scientificName: self.species, // Use VM's current species as scientific name
                commonName: self.details?.commonName, // Use VM's current details
                spritePNGData: self.currentDexEntry?.sprite // Use VM's current sprite
            )
        }
        
        print("Ending Live Activity: \(activity.id) with phase \(finalPhase.rawValue)")
        // Dismissal policy can be .immediate or .after(date) for example
        await activity.end(using: finalContentStateToUse, dismissalPolicy: .default)
        self.currentActivity = nil
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