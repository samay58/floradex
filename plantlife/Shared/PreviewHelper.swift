import Foundation
import SwiftData
import SwiftUI // For UIImage if we want to provide sample images

// Ensure this matches your actual app module name if different
// @testable import plantlife 

struct PreviewHelper {
    @MainActor
    static var sampleDexEntry: DexEntry {
        let entry = DexEntry(
            id: 1,
            createdAt: Date().addingTimeInterval(-86400 * 5), // 5 days ago
            latinName: "Monstera deliciosa",
            // snapshot: sampleSnapshotData(), // Optional: provide a sample image data
            // sprite: sampleSpriteData(),     // Optional: provide a sample sprite data
            tags: ["Easy Care", "Indoor", "Climbing"],
            notes: "A beautiful and iconic houseplant. Easy to care for, loves bright indirect light.",
            spriteGenerationFailed: false
        )
        return entry
    }
    
    @MainActor
    static var sampleDexEntryWithoutSprite: DexEntry {
        let entry = DexEntry(
            id: 2,
            createdAt: Date().addingTimeInterval(-86400 * 2), // 2 days ago
            latinName: "Ficus lyrata",
            tags: ["Bright Light", "Indoor", "Tree"],
            notes: "Fiddle-leaf fig. Can be a bit finicky.",
            spriteGenerationFailed: false
        )
        return entry
    }
    
    @MainActor
    static var sampleDexEntrySpriteFailed: DexEntry {
        let entry = DexEntry(
            id: 3,
            createdAt: Date().addingTimeInterval(-86400 * 1), // 1 day ago
            latinName: "Calathea ornata",
            tags: ["High Water", "Low Light", "Foliage"],
            notes: "Pinstripe Calathea. Needs high humidity.",
            spriteGenerationFailed: true
        )
        return entry
    }

    @MainActor
    static var sampleDexEntries: [DexEntry] {
        [
            sampleDexEntry, 
            sampleDexEntryWithoutSprite, 
            sampleDexEntrySpriteFailed,
            DexEntry(id: 4, latinName: "Pilea peperomioides", tags: ["Easy Care", "Medium Light", "Chinese Money Plant"], notes: "Chinese Money Plant."),
            DexEntry(id: 5, latinName: "Sansevieria trifasciata", tags: ["Low Water", "Low Light", "Snake Plant"], notes: "Snake Plant. Very hardy.")
        ]
    }

    @MainActor
    static var sampleSpeciesDetails: SpeciesDetails {
        SpeciesDetails(
            latinName: "Monstera deliciosa", // Must match a sampleDexEntry.latinName for preview to work
            commonName: "Swiss Cheese Plant",
            summary: "A popular and easy-to-care-for houseplant known for its large, fenestrated leaves. It prefers bright, indirect light and moderate watering.",
            growthHabit: "Climbing vine, can grow very large",
            sunlight: "Bright, indirect light. Tolerates medium light.",
            water: "Water thoroughly when top 2 inches of soil are dry. Avoid overwatering.",
            soil: "Well-draining potting mix, rich in organic matter.",
            temperature: "18°C - 27°C (65°F - 80°F)",
            bloomTime: "Rarely blooms indoors, but can produce spathe-like flowers.",
            funFacts: [
                "Its fruit is edible and tastes like a mix of pineapple and banana.",
                "The holes in its leaves are called fenestrations and help it withstand strong winds in its native habitat.",
                "Can be easily propagated from stem cuttings."
            ],
            lastUpdated: Date()
        )
    }

    // Optional: Helper to create sample UIImage data if needed for previews
    // static func sampleSnapshotData() -> Data? {
    //     return UIImage(systemName: "photo")?.jpegData(compressionQuality: 0.8)
    // }
    // 
    // static func sampleSpriteData() -> Data? {
    //     // Create a small 64x64 placeholder image for sprite
    //     let renderer = UIGraphicsImageRenderer(size: CGSize(width: 64, height: 64))
    //     let img = renderer.image { ctx in
    //         ctx.cgContext.setFillColor(UIColor.systemGreen.cgColor)
    //         ctx.cgContext.fill(CGRect(x: 0, y: 0, width: 64, height: 64))
    //         
    //         let attrs = [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 10), NSAttributedString.Key.foregroundColor: UIColor.white]
    //         NSString(string: "Sprite").draw(with: CGRect(x: 10, y: 25, width: 44, height: 14), options: .usesLineFragmentOrigin, attributes: attrs, context: nil)
    //     }
    //     return img.pngData()
    // }

    // To use these in previews with an in-memory SwiftData container:
    /*
    #if DEBUG
    @MainActor
    let previewContainer: ModelContainer = {
        do {
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            let container = try ModelContainer(for: DexEntry.self, configurations: config)
            // Optionally add sample data
            Task { // Use Task for async context if needed by data generation
                for entry in PreviewHelper.sampleDexEntries {
                    container.mainContext.insert(entry)
                }
                // Add SpeciesDetails if your previews need them
            }
            return container
        } catch {
            fatalError("Failed to create model container for preview: \(error)")
        }
    }()
    #endif
    */
}

// Example of how to extend your preview provider to use the helper
/*
 #if DEBUG
 extension PreviewProvider {
    @MainActor static var sampleDexEntry: DexEntry { PreviewHelper.sampleDexEntry }
    @MainActor static var sampleDexEntries: [DexEntry] { PreviewHelper.sampleDexEntries }
    
    // If you set up the previewContainer in PreviewHelper:
    // static var previewModelContainer: ModelContainer { PreviewHelper.previewContainer }
 }
 #endif
 */ 