import CryptoKit
import SwiftUI

/// Caches covers from Jellyfin, with batched phone requests as a fallback.
/// Cache keys include the image tag and pixel size to distinguish replacements and sizes.
final class ArtworkStore {
    static let shared = ArtworkStore()

    private static let batchLimit = 10
    /// Bounds memory and disk use during long scrolls.
    private static let memoryCountLimit = 120
    private static let diskLimitBytes = 40 * 1024 * 1024
    private static let diskTrimTargetBytes = 30 * 1024 * 1024

    private struct Request {
        let key: String
        let id: String
        let size: Int
    }

    private let memory: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = memoryCountLimit
        return cache
    }()
    private var inFlight: [String: Task<UIImage?, Never>] = [:]
    /// One phone request per key: `image(for:size:)` already joins callers of the same key.
    private var waiting: [String: CheckedContinuation<UIImage?, Never>] = [:]
    private var writesSinceTrim = 0
    private var queue: [Request] = []
    private var isSending = false
    private let directory: URL = {
        let url = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appending(path: "artwork")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()

    private init() {
        trimDiskCache()
    }

    func removeAll() {
        memory.removeAllObjects()
        try? FileManager.default.removeItem(at: directory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    /// Trims oldest files down to diskTrimTargetBytes after exceeding diskLimitBytes.
    private func trimDiskCache() {
        let keys: [URLResourceKey] = [.fileSizeKey, .contentModificationDateKey]
        guard let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: keys)
        else { return }
        let entries = files.compactMap { url -> (url: URL, size: Int, date: Date)? in
            guard let values = try? url.resourceValues(forKeys: Set(keys)) else { return nil }
            return (url, values.fileSize ?? 0, values.contentModificationDate ?? .distantPast)
        }
        var total = entries.reduce(0) { $0 + $1.size }
        guard total > Self.diskLimitBytes else { return }
        for entry in entries.sorted(by: { $0.date < $1.date }) where total > Self.diskTrimTargetBytes {
            try? FileManager.default.removeItem(at: entry.url)
            total -= entry.size
        }
    }

    func image(for item: LibraryItem, size: Int) async -> UIImage? {
        let key = "\(item.artworkKey)-\(size)"
        if let image = memory.object(forKey: key as NSString) { return image }

        if let data = try? Data(contentsOf: file(for: key)), let image = UIImage(data: data) {
            memory.setObject(image, forKey: key as NSString)
            return image
        }

        if let task = inFlight[key] { return await task.value }
        let task = Task { await load(item, size: size, key: key) }
        inFlight[key] = task
        let image = await task.value
        inFlight[key] = nil
        return image
    }

    /// Pauses direct requests after a connection failure so every cover need not time out.
    private var directPausedUntil: Date?
    private static let directPause: TimeInterval = 5 * 60

    private func load(_ item: LibraryItem, size: Int, key: String) async -> UIImage? {
        if directPausedUntil.map({ Date() >= $0 }) ?? true {
            switch await download(item.artworkURL, size: size) {
            case .image(let data):
                if let image = UIImage(data: data) {
                    store(image, data: data, key: key)
                    return image
                }
            case .unreachable:
                directPausedUntil = Date().addingTimeInterval(Self.directPause)
            case .none:
                break
            }
        }
        return await viaPhone(item, size: size, key: key)
    }

    private enum Download {
        case image(Data)
        /// No cover or address, including HTTP errors.
        case none
        /// Connection failed; pause direct requests.
        case unreachable
    }

    /// Downloads a cover with its longer side capped at `size` pixels.
    private func download(_ address: String, size: Int) async -> Download {
        guard !address.isEmpty, var components = URLComponents(string: address) else { return .none }
        components.queryItems = (components.queryItems ?? []) + [
            URLQueryItem(name: "MaxWidth", value: String(size)),
            URLQueryItem(name: "MaxHeight", value: String(size)),
        ]
        guard let url = components.url else { return .none }
        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        guard let (data, response) = try? await URLSession.shared.data(for: request) else { return .unreachable }
        return (response as? HTTPURLResponse)?.statusCode == 200 ? .image(data) : .none
    }

    private func viaPhone(_ item: LibraryItem, size: Int, key: String) async -> UIImage? {
        await withCheckedContinuation { continuation in
            waiting[key] = continuation
            queue.append(Request(key: key, id: item.id, size: size))
            sendNextBatch()
        }
    }

    private func file(for key: String) -> URL {
        directory.appending(path: SHA256.hash(data: Data(key.utf8)).map { String(format: "%02x", $0) }.joined() + ".jpg")
    }

    private func sendNextBatch() {
        guard !isSending, !queue.isEmpty else { return }
        isSending = true
        Task {
            // Let rows that appear together join one batch.
            try? await Task.sleep(for: .milliseconds(30))
            let batch = Array(queue.prefix(Self.batchLimit))
            queue.removeFirst(batch.count)

            do {
                let reply = try await PhoneConnection.shared.artworks(batch.map { ($0.id, $0.size) })
                var deferred: [Request] = []
                for request in batch {
                    let replyKey = "\(request.id)-\(request.size)"
                    if let data = reply.covers[replyKey], let image = UIImage(data: data) {
                        store(image, data: data, key: request.key)
                        resolve(request.key, with: image)
                    } else if reply.missing.contains(replyKey) {
                        resolve(request.key, with: nil)
                    } else {
                        deferred.append(request)  // didn't fit this reply's byte budget
                    }
                }
                queue.insert(contentsOf: deferred, at: 0)
            } catch {
                for request in batch { resolve(request.key, with: nil) }
            }

            isSending = false
            sendNextBatch()
        }
    }

    private func resolve(_ key: String, with image: UIImage?) {
        waiting.removeValue(forKey: key)?.resume(returning: image)
    }

    /// Caches a cover in memory and on disk, trimming the disk cache every 50 writes, not only at launch.
    private func store(_ image: UIImage, data: Data, key: String) {
        try? data.write(to: file(for: key))
        memory.setObject(image, forKey: key as NSString)
        writesSinceTrim += 1
        if writesSinceTrim >= 50 {
            writesSinceTrim = 0
            trimDiskCache()
        }
    }
}

/// A cached cover or placeholder, optionally circular.
struct CoverView: View {
    let item: LibraryItem
    let placeholderSymbol: String
    var circular = false
    @State private var image: UIImage?
    /// Rounds pixel sizes to multiples of 20 so similar slots share cached covers.
    @State private var pixelSize = 0
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        Rectangle()
            .fill(.finampGradient)
            .overlay {
                if let image {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    Image(systemName: placeholderSymbol)
                        .font(.title2)
                        .foregroundStyle(.white)
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .clipShape(circular ? AnyShape(Circle()) : AnyShape(RoundedRectangle(cornerRadius: 8)))
            .onGeometryChange(for: Int.self) { proxy in
                Int((proxy.size.width * displayScale / 20).rounded(.up)) * 20
            } action: { pixelSize = $0 }
            .task(id: "\(item.artworkKey)-\(pixelSize)") {
                if item.artworkKey.isEmpty { image = nil }
                guard pixelSize > 0, !item.artworkKey.isEmpty else { return }
                image = await ArtworkStore.shared.image(for: item, size: pixelSize)
            }
    }
}
