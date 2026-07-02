import Foundation
import Testing
@testable import FloradexKit

@Suite struct MediaPathPolicyTests {
    private let policy = MediaPathPolicy(root: URL(filePath: "/tmp/floradex-media"))

    @Test func pathsAreDisjointPerEntry() {
        let first = EntryID()
        let second = EntryID()
        #expect(policy.originalPhotoURL(for: first) != policy.originalPhotoURL(for: second))
        #expect(policy.spriteDirectory(for: first) != policy.spriteDirectory(for: second))
    }

    @Test func layoutMatchesSpec() {
        let id = EntryID()
        let uuid = id.rawValue.uuidString
        #expect(policy.originalPhotoURL(for: id).path().hasSuffix("photos/\(uuid)/original.heic"))
        #expect(policy.spriteURL(for: id, version: 3).path().hasSuffix("sprites/\(uuid)/sprite-v3.png"))
    }

    @Test func spriteVersionParsesRoundTrip() {
        let id = EntryID()
        let url = policy.spriteURL(for: id, version: 12)
        #expect(policy.spriteVersion(from: url) == 12)
        #expect(policy.spriteVersion(from: policy.originalPhotoURL(for: id)) == nil)
    }
}

@Suite struct FileMediaStoreTests {
    private func makeStore() -> FileMediaStore {
        let root = FileManager.default.temporaryDirectory
            .appending(component: "floradex-tests-\(UUID().uuidString)")
        return FileMediaStore(root: root)
    }

    @Test func photoRoundTrips() async throws {
        let store = makeStore()
        let id = EntryID()
        let photo = Data("fake-heic-bytes".utf8)

        try await store.writeOriginalPhoto(photo, for: id)
        let read = await store.readOriginalPhoto(for: id)
        #expect(read == photo)
    }

    @Test func latestSpritePrefersNewestVersion() async throws {
        let store = makeStore()
        let id = EntryID()

        try await store.writeSprite(Data("v1".utf8), for: id, version: 1)
        try await store.writeSprite(Data("v2".utf8), for: id, version: 2)

        let latest = await store.latestSprite(for: id)
        #expect(latest?.version == 2)
        #expect(latest?.data == Data("v2".utf8))
    }

    /// The corrupted-sprite fixture at the storage layer: an unusable newest
    /// version must fall back to the last good one, never error out.
    @Test func corruptedNewestVersionFallsBack() async throws {
        let store = makeStore()
        let id = EntryID()

        try await store.writeSprite(Data("good".utf8), for: id, version: 1)
        try await store.writeSprite(Data(), for: id, version: 2)

        let latest = await store.latestSprite(for: id)
        #expect(latest?.version == 1)
        #expect(latest?.data == Data("good".utf8))
    }

    @Test func missingSpriteIsNilNotError() async {
        let store = makeStore()
        let latest = await store.latestSprite(for: EntryID())
        #expect(latest == nil)
    }

    @Test func deleteRemovesAllEntryMedia() async throws {
        let store = makeStore()
        let id = EntryID()
        try await store.writeOriginalPhoto(Data("photo".utf8), for: id)
        try await store.writeSprite(Data("sprite".utf8), for: id, version: 1)

        try await store.deleteMedia(for: id)

        let photo = await store.readOriginalPhoto(for: id)
        let sprite = await store.latestSprite(for: id)
        #expect(photo == nil)
        #expect(sprite == nil)
    }
}
