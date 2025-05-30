import Foundation
import UIKit
import SwiftUI

/// Manages image caching for efficient memory usage in collection views
@MainActor
class ImageCacheManager: ObservableObject {
    static let shared = ImageCacheManager()
    
    // Memory cache with size limit
    private let memoryCache = NSCache<NSString, UIImage>()
    
    // Disk cache directory
    private let diskCacheURL: URL
    
    // Configuration
    private let maxMemoryCost = 100 * 1024 * 1024 // 100MB
    private let maxDiskSize = 500 * 1024 * 1024 // 500MB
    
    // Prefetch queue
    private let prefetchQueue = DispatchQueue(label: "com.floradex.imagePrefetch", qos: .background, attributes: .concurrent)
    
    // Track active requests to avoid duplicates
    private var activeRequests = Set<String>()
    
    init() {
        // Configure memory cache
        memoryCache.countLimit = 100 // Max 100 images in memory
        memoryCache.totalCostLimit = maxMemoryCost
        
        // Setup disk cache directory
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        diskCacheURL = cacheDir.appendingPathComponent("FloradexImageCache")
        
        // Create directory if needed
        try? FileManager.default.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)
        
        // Listen for memory warnings
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
        
        // Clean old cache on launch
        Task {
            await cleanDiskCache()
        }
    }
    
    // MARK: - Public API
    
    /// Get image from cache or data
    func image(for entry: DexEntry) -> UIImage? {
        let cacheKey = "sprite-\(entry.id)"
        
        // Check memory cache first
        if let cached = memoryCache.object(forKey: cacheKey as NSString) {
            return cached
        }
        
        // Check disk cache
        if let diskImage = loadFromDisk(key: cacheKey) {
            // Add to memory cache
            memoryCache.setObject(diskImage, forKey: cacheKey as NSString, cost: diskImage.pngData()?.count ?? 0)
            return diskImage
        }
        
        // Load from data
        if let spriteData = entry.sprite, let image = UIImage(data: spriteData) {
            // Cache it
            cache(image: image, for: cacheKey)
            return image
        }
        
        // Try snapshot as fallback
        if let snapshotData = entry.snapshot, let image = UIImage(data: snapshotData) {
            // Don't cache snapshots as heavily
            memoryCache.setObject(image, forKey: "snapshot-\(entry.id)" as NSString, cost: snapshotData.count / 4)
            return image
        }
        
        return nil
    }
    
    /// Prefetch images for upcoming cells
    func prefetchImages(for entries: [DexEntry], startIndex: Int, count: Int) {
        let endIndex = min(startIndex + count, entries.count)
        guard startIndex < endIndex else { return }
        
        for i in startIndex..<endIndex {
            let entry = entries[i]
            let cacheKey = "sprite-\(entry.id)"
            
            // Skip if already cached or being loaded
            if memoryCache.object(forKey: cacheKey as NSString) != nil { continue }
            if activeRequests.contains(cacheKey) { continue }
            
            activeRequests.insert(cacheKey)
            
            prefetchQueue.async { [weak self] in
                guard let self = self else { return }
                
                // Load image
                if let spriteData = entry.sprite, let image = UIImage(data: spriteData) {
                    Task { @MainActor in
                        self.cache(image: image, for: cacheKey)
                        self.activeRequests.remove(cacheKey)
                    }
                }
            }
        }
    }
    
    /// Clear all caches
    func clearCache() {
        memoryCache.removeAllObjects()
        
        // Clear disk cache
        if let files = try? FileManager.default.contentsOfDirectory(at: diskCacheURL, includingPropertiesForKeys: nil) {
            for file in files {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func cache(image: UIImage, for key: String) {
        // Add to memory cache
        let cost = image.pngData()?.count ?? 0
        memoryCache.setObject(image, forKey: key as NSString, cost: cost)
        
        // Save to disk asynchronously
        Task {
            await saveToDisk(image: image, key: key)
        }
    }
    
    private func loadFromDisk(key: String) -> UIImage? {
        let fileURL = diskCacheURL.appendingPathComponent("\(key).png")
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return UIImage(data: data)
    }
    
    private func saveToDisk(image: UIImage, key: String) async {
        let fileURL = diskCacheURL.appendingPathComponent("\(key).png")
        
        // Use lower quality for disk cache to save space
        if let data = image.pngData() {
            try? data.write(to: fileURL)
        }
    }
    
    private func cleanDiskCache() async {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: diskCacheURL,
            includingPropertiesForKeys: [.contentAccessDateKey, .totalFileAllocatedSizeKey]
        ) else { return }
        
        // Calculate total size
        var totalSize = 0
        var fileInfos: [(url: URL, accessDate: Date, size: Int)] = []
        
        for file in files {
            if let attributes = try? file.resourceValues(forKeys: [.contentAccessDateKey, .totalFileAllocatedSizeKey]),
               let accessDate = attributes.contentAccessDate,
               let size = attributes.totalFileAllocatedSize {
                totalSize += size
                fileInfos.append((file, accessDate, size))
            }
        }
        
        // If under limit, we're good
        if totalSize <= maxDiskSize { return }
        
        // Sort by access date (oldest first)
        fileInfos.sort { $0.accessDate < $1.accessDate }
        
        // Remove oldest files until under limit
        var currentSize = totalSize
        for fileInfo in fileInfos {
            try? FileManager.default.removeItem(at: fileInfo.url)
            currentSize -= fileInfo.size
            if currentSize <= maxDiskSize { break }
        }
    }
    
    @objc private func handleMemoryWarning() {
        // Reduce memory cache to 50%
        memoryCache.totalCostLimit = maxMemoryCost / 2
        
        // After emergency, restore limit
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) { [weak self] in
            self?.memoryCache.totalCostLimit = self?.maxMemoryCost ?? 0
        }
    }
}

// MARK: - SwiftUI View Extension

extension View {
    func cachedImage(for entry: DexEntry) -> some View {
        self.overlay(
            CachedImageView(entry: entry)
        )
    }
}

struct CachedImageView: View {
    let entry: DexEntry
    @StateObject private var cacheManager = ImageCacheManager.shared
    @State private var image: UIImage?
    
    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .interpolation(.none) // For pixel art
            }
        }
        .onAppear {
            image = cacheManager.image(for: entry)
        }
    }
}