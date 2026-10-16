import Foundation

enum ArtworkSource {
    static func url(path: String, type: String) -> URL? {
        switch type {
        case "file":
            return URL(fileURLWithPath: path)
        case "network":
            guard let url = URL(string: path),
                  let scheme = url.scheme?.lowercased(),
                  scheme == "https" || scheme == "http" else { return nil }
            return url
        default:
            return nil
        }
    }
}
