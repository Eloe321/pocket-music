import Foundation

@main
struct ArtworkSourceTest {
    static func main() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let cover = directory.appendingPathComponent("album cover.jpg")
        let bytes = Data([0xFF, 0xD8, 0xFF, 0xD9])
        try bytes.write(to: cover)

        let fileURL = ArtworkSource.url(path: cover.path, type: "file")
        assert(fileURL?.isFileURL == true)
        let loaded = try Data(contentsOf: fileURL!)
        assert(loaded == bytes)
        assert(ArtworkSource.url(path: "https://example.com/cover.jpg", type: "network")?.scheme == "https")
        assert(ArtworkSource.url(path: cover.path, type: "network") == nil)
        assert(ArtworkSource.url(path: cover.path, type: "asset") == nil)
        print("ArtworkSource tests passed")
    }
}
