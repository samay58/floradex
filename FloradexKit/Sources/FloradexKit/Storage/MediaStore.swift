import Foundation

/// On-disk layout for entry media. Images never live in the database;
/// the store persists paths derived here.
///
/// Layout: `photos/{entry-uuid}/original.heic` and
/// `sprites/{entry-uuid}/sprite-v{N}.png`. Sprites are versioned so a
/// corrupted or superseded file never takes down an entry; readers fall back
/// to the newest version that loads.
public struct MediaPathPolicy: Hashable, Sendable {
    public var root: URL

    public init(root: URL) {
        self.root = root
    }

    public func photoDirectory(for id: EntryID) -> URL {
        root.appending(components: "photos", id.rawValue.uuidString, directoryHint: .isDirectory)
    }

    public func spriteDirectory(for id: EntryID) -> URL {
        root.appending(components: "sprites", id.rawValue.uuidString, directoryHint: .isDirectory)
    }

    public func originalPhotoURL(for id: EntryID) -> URL {
        photoDirectory(for: id).appending(component: "original.heic")
    }

    public func spriteURL(for id: EntryID, version: Int) -> URL {
        spriteDirectory(for: id).appending(component: "sprite-v\(version).png")
    }

    public func spriteVersion(from url: URL) -> Int? {
        let name = url.deletingPathExtension().lastPathComponent
        guard name.hasPrefix("sprite-v"), let version = Int(name.dropFirst("sprite-v".count)) else {
            return nil
        }
        return version
    }
}

public actor FileMediaStore {
    public let paths: MediaPathPolicy
    private let fileManager = FileManager.default

    public init(root: URL) {
        self.paths = MediaPathPolicy(root: root)
    }

    @discardableResult
    public func writeOriginalPhoto(_ data: Data, for id: EntryID) throws -> URL {
        let url = paths.originalPhotoURL(for: id)
        try fileManager.createDirectory(at: paths.photoDirectory(for: id), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
        return url
    }

    public func readOriginalPhoto(for id: EntryID) -> Data? {
        try? Data(contentsOf: paths.originalPhotoURL(for: id))
    }

    @discardableResult
    public func writeSprite(_ data: Data, for id: EntryID, version: Int) throws -> URL {
        let url = paths.spriteURL(for: id, version: version)
        try fileManager.createDirectory(at: paths.spriteDirectory(for: id), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
        return url
    }

    /// Newest sprite version whose file actually loads; empty or unreadable
    /// versions are skipped rather than surfaced as errors.
    public func latestSprite(for id: EntryID) -> (version: Int, data: Data)? {
        let directory = paths.spriteDirectory(for: id)
        guard let files = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else {
            return nil
        }
        let versions = files
            .compactMap { url in paths.spriteVersion(from: url).map { ($0, url) } }
            .sorted { $0.0 > $1.0 }
        for (version, url) in versions {
            if let data = try? Data(contentsOf: url), !data.isEmpty {
                return (version, data)
            }
        }
        return nil
    }

    public func deleteMedia(for id: EntryID) throws {
        for directory in [paths.photoDirectory(for: id), paths.spriteDirectory(for: id)] {
            if fileManager.fileExists(atPath: directory.path) {
                try fileManager.removeItem(at: directory)
            }
        }
    }
}
