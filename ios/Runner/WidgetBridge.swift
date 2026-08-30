import Flutter
import Foundation
import ImageIO
import UniformTypeIdentifiers
import WidgetKit

extension AppDelegate {
    func setupWidgetChannel() {
        let channel = FlutterMethodChannel(
            name: "finamp/ios_widget",
            binaryMessenger: flutterEngine.binaryMessenger
        )
        let actionState = FinampWidgetActionState()

        FinampWidgetActionDispatcher.handler = { action, rating in
            actionState.begin()
            defer { actionState.end() }

            let arguments: [String: Any] = [
                "action": action.rawValue,
                "rating": rating as Any
            ]

            try await withCheckedThrowingContinuation {
                (continuation: CheckedContinuation<Void, Error>) in

                channel.invokeMethod(
                    "performAction",
                    arguments: arguments
                ) { result in
                    if let error = result as? FlutterError {
                        continuation.resume(
                            throwing: NSError(
                                domain: "FinampWidget",
                                code: 1,
                                userInfo: [
                                    NSLocalizedDescriptionKey:
                                        error.message ?? error.code
                                ]
                            )
                        )
                        return
                    }

                    guard let state = result as? [String: Any] else {
                        continuation.resume(
                            throwing: NSError(
                                domain: "FinampWidget",
                                code: 4,
                                userInfo: [
                                    NSLocalizedDescriptionKey:
                                        "Widget action did not return a state snapshot"
                                ]
                            )
                        )
                        return
                    }

                    do {
                        try FinampWidgetStateWriter.writeState(
                            state,
                            reload: false
                        )
                        continuation.resume()
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }

        channel.setMethodCallHandler { call, result in
            switch call.method {
            case "updateState":
                guard let arguments = call.arguments as? [String: Any] else {
                    result(FlutterError(
                        code: "INVALID_ARGS",
                        message: "Widget state must be a dictionary",
                        details: nil
                    ))
                    return
                }

                do {
                    let reload =
                        (arguments["reload"] as? Bool ?? true) &&
                        !actionState.isActive
                    try FinampWidgetStateWriter.writeState(
                        arguments,
                        reload: reload
                    )
                    result(nil)
                } catch {
                    result(FlutterError(
                        code: "WIDGET_STATE_WRITE_FAILED",
                        message: error.localizedDescription,
                        details: nil
                    ))
                }

            case "updateArtwork":
                guard
                    let arguments = call.arguments as? [String: Any],
                    let itemID = arguments["itemID"] as? String,
                    let typedData = arguments["bytes"] as? FlutterStandardTypedData
                else {
                    result(FlutterError(
                        code: "INVALID_ARTWORK_ARGS",
                        message: "Widget artwork requires itemID and bytes",
                        details: nil
                    ))
                    return
                }

                do {
                    let reload =
                        (arguments["reload"] as? Bool ?? true) &&
                        !actionState.isActive
                    try FinampWidgetStateWriter.writeArtwork(
                        typedData.data,
                        itemID: itemID,
                        reload: reload
                    )
                    result(nil)
                } catch {
                    result(FlutterError(
                        code: "WIDGET_ARTWORK_WRITE_FAILED",
                        message: error.localizedDescription,
                        details: nil
                    ))
                }

            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }
}

private final class FinampWidgetActionState: @unchecked Sendable {
    private let lock = NSLock()
    private var depth = 0

    var isActive: Bool {
        lock.lock()
        defer { lock.unlock() }
        return depth > 0
    }

    func begin() {
        lock.lock()
        depth += 1
        lock.unlock()
    }

    func end() {
        lock.lock()
        depth = max(0, depth - 1)
        lock.unlock()
    }
}

private enum FinampWidgetStateWriter {
    private static let maxCoverPixelSize = 1280
    private static let jpegCompressionQuality = 0.9

    private static var appGroup: String {
        "group.\(Bundle.main.bundleIdentifier ?? "com.unicornsonlsd.finamp-ios").widget"
    }

    private static var containerURL: URL? {
        FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroup
        )
    }

    private static var stateURL: URL? {
        containerURL?.appendingPathComponent(FinampWidgetShared.stateFileName)
    }

    static func writeState(
        _ arguments: [String: Any],
        reload: Bool
    ) throws {
        let oldState = loadState()

        var state = oldState
        state.itemID = arguments["itemID"] as? String
        state.title = arguments["title"] as? String ?? "Finamp"
        state.artist = arguments["artist"] as? String ?? ""
        state.album = arguments["album"] as? String ?? ""
        state.isPlaying = arguments["isPlaying"] as? Bool ?? false
        state.showStarRatings = arguments["showStarRatings"] as? Bool ?? false
        state.isFavorite = arguments["isFavorite"] as? Bool ?? false
        state.starRating = (arguments["starRating"] as? NSNumber)?.doubleValue

        if state == oldState {
            return
        }

        if oldState.itemID != state.itemID, let oldID = oldState.itemID {
            removeCover(itemID: oldID)
        }

        try save(state)
        if reload {
            reloadWidget()
        }
    }

    static func writeArtwork(
        _ data: Data,
        itemID: String,
        reload: Bool
    ) throws {
        var state = loadState()
        guard state.itemID == itemID else {
            return
        }

        guard let destination = coverURL(itemID: itemID) else {
            throw NSError(
                domain: "FinampWidget",
                code: 11,
                userInfo: [
                    NSLocalizedDescriptionKey:
                        "Unable to resolve widget artwork destination"
                ]
            )
        }

        let normalizedData = try normalizeCoverData(data)

        if let existingData = try? Data(contentsOf: destination),
           existingData == normalizedData {
            return
        }

        try normalizedData.write(to: destination, options: .atomic)
        state.coverRevision &+= 1
        try save(state)
        if reload {
            reloadWidget()
        }
    }

    private static func loadState() -> FinampWidgetState {
        guard
            let stateURL,
            let data = try? Data(contentsOf: stateURL),
            let state = try? JSONDecoder().decode(
                FinampWidgetState.self,
                from: data
            )
        else {
            return .empty
        }
        return state
    }

    private static func save(_ state: FinampWidgetState) throws {
        guard let stateURL else {
            throw NSError(
                domain: "FinampWidget",
                code: 10,
                userInfo: [
                    NSLocalizedDescriptionKey:
                        "Unable to resolve widget state destination"
                ]
            )
        }

        let data = try JSONEncoder().encode(state)
        try data.write(to: stateURL, options: .atomic)
    }

    private static func normalizeCoverData(_ data: Data) throws -> Data {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            throw NSError(
                domain: "FinampWidget",
                code: 12,
                userInfo: [
                    NSLocalizedDescriptionKey:
                        "Unable to decode widget artwork"
                ]
            )
        }

        let thumbnailOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxCoverPixelSize,
            kCGImageSourceShouldCacheImmediately: true
        ]

        guard let image = CGImageSourceCreateThumbnailAtIndex(
            source,
            0,
            thumbnailOptions as CFDictionary
        ) else {
            throw NSError(
                domain: "FinampWidget",
                code: 13,
                userInfo: [
                    NSLocalizedDescriptionKey:
                        "Unable to downsample widget artwork"
                ]
            )
        }

        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            output,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            throw NSError(
                domain: "FinampWidget",
                code: 14,
                userInfo: [
                    NSLocalizedDescriptionKey:
                        "Unable to create widget artwork encoder"
                ]
            )
        }

        let properties: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: jpegCompressionQuality
        ]
        CGImageDestinationAddImage(
            destination,
            image,
            properties as CFDictionary
        )

        guard CGImageDestinationFinalize(destination) else {
            throw NSError(
                domain: "FinampWidget",
                code: 15,
                userInfo: [
                    NSLocalizedDescriptionKey:
                        "Unable to encode widget artwork"
                ]
            )
        }

        return output as Data
    }

    private static func reloadWidget() {
        WidgetCenter.shared.reloadTimelines(ofKind: FinampWidgetShared.kind)
    }

    private static func coverURL(itemID: String) -> URL? {
        containerURL?
            .appendingPathComponent(
                "\(FinampWidgetShared.coverFileName)-\(itemID)"
            )
            .appendingPathExtension("jpg")
    }

    private static func removeCover(itemID: String) {
        guard let url = coverURL(itemID: itemID) else { return }
        try? FileManager.default.removeItem(at: url)
    }
}
