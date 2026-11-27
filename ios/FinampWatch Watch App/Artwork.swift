import CryptoKit
import SwiftUI
import WatchKit

// Covers, asked for from the phone in batches and kept in memory and on disk.
final class ArtworkStore {
    static let shared = ArtworkStore()

    private static let batchLimit = 10
    private static let memoryCountLimit = 120
    private static let diskLimitBytes = 40 * 1024 * 1024
    private static let diskTrimTargetBytes = 30 * 1024 * 1024

    private struct Request {
        let key: String
        let id: String
        let size: Int
        let generation: Int
    }

    private let memory: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = memoryCountLimit
        return cache
    }()
    private var inFlight: [String: Task<UIImage?, Never>] = [:]
    // Compare account generations before caching replies.
    private var generation = 0
    // One phone request per key: image(for:size:) joins callers of the same key.
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
        // Keep in-flight loads: a new request for the same key must join them, not replace their waiter
        generation += 1
        memory.removeAllObjects()
        try? FileManager.default.removeItem(at: directory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

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

    // The size of a cover that fills the screen (Playback, the playlist menu), rounded up to 20 pixels so they share it.
    static let screenPixels: Int = {
        let device = WKInterfaceDevice.current()
        let pixels = max(device.screenBounds.width, device.screenBounds.height) * device.screenScale
        return coverPixels(pixels)
    }()

    // Cover sizes are asked for in steps of 20 pixels, so slots of nearly the same size share one cached copy.
    static func coverPixels(_ pixels: CGFloat) -> Int { Int((pixels / 20).rounded(.up)) * 20 }

    func image(for item: LibraryItem, size: Int) async -> UIImage? {
        // Include the image tag and size so replacements and resolutions stay separate.
        let key = "\(item.artworkKey)-\(size)"
        if let image = memory.object(forKey: key as NSString) { return image }

        if let data = try? Data(contentsOf: file(for: key)), let image = UIImage(data: data) {
            memory.setObject(image, forKey: key as NSString)
            return image
        }

        if let task = inFlight[key] { return await task.value }
        let task = Task { await viaPhone(item, size: size, key: key) }
        inFlight[key] = task
        let image = await task.value
        inFlight[key] = nil
        return image
    }

    private func viaPhone(_ item: LibraryItem, size: Int, key: String) async -> UIImage? {
        await withCheckedContinuation { continuation in
            waiting[key] = continuation
            queue.append(Request(key: key, id: item.id, size: size, generation: generation))
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
            try? await Task.sleep(for: ConnectionPolicy.Cover.batchDelay)
            let batch = Array(queue.prefix(Self.batchLimit))
            queue.removeFirst(batch.count)

            do {
                let start = ContinuousClock.now
                let reply = try await PhoneConnection.shared.artworks(batch.map { ($0.id, $0.size) })
                // The phone also answers when it couldn't get a cover; the request still counts as a success, so say it here.
                let empty = batch.filter { reply.missing.contains("\($0.id)-\($0.size)") }.count
                if empty > 0 {
                    WatchLog.warning("artworks: \(empty) of \(batch.count) came back without a cover after \((ContinuousClock.now - start).ms) ms")
                }
                var deferred: [Request] = []
                for request in batch {
                    let replyKey = "\(request.id)-\(request.size)"
                    if let data = reply.covers[replyKey], let image = UIImage(data: data) {
                        if request.generation == generation { store(image, data: data, key: request.key) }
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

// Finamp's AlbumImage: the background colour while loading, Material's album icon when there is no cover.
struct CoverView: View {
    let item: LibraryItem
    var circular = false
    @State private var image: UIImage?
    @State private var missing = false
    // Round sizes to share cached covers across similar slots.
    @State private var pixelSize = 0
    @Environment(\.displayScale) private var displayScale
    // A placeholder row (redacted): the cover is a plain grey tile.
    @Environment(\.redactionReasons) private var redaction

    var body: some View {
        Rectangle()
            .fill(redaction.isEmpty ? Color.appBackground : Color.skeletonFill)
            .overlay {
                if !redaction.isEmpty {
                    EmptyView()
                } else if let image {
                    Image(uiImage: image).resizable().scaledToFill()
                } else if let blur = BlurHash.image(item.blurHash) {
                    Image(uiImage: blur).resizable().scaledToFill()
                } else if missing || item.artworkKey.isEmpty {
                    CentredIcon(asset: "material-album", share: Covers.missingIconShare)
                        .foregroundStyle(Color.fgPrimary)
                }
            }
            .animation(.easeIn(duration: Covers.fadeIn), value: image)
            .aspectRatio(1, contentMode: .fit)
            .coverClip(circular: circular)
            .onGeometryChange(for: Int.self) { proxy in
                ArtworkStore.coverPixels(proxy.size.width * displayScale)
            } action: { pixelSize = $0 }
            .task(id: "\(item.artworkKey)-\(pixelSize)") {
                if item.artworkKey.isEmpty { image = nil }
                guard pixelSize > 0, !item.artworkKey.isEmpty else { return }
                let loaded = await ArtworkStore.shared.image(for: item, size: pixelSize)
                // A cancelled load can finish after the one that replaced it, and must not undo its result.
                guard !Task.isCancelled else { return }
                image = loaded
                missing = loaded == nil
            }
    }
}
