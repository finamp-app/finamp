import AppIntents
import Foundation
import WidgetKit

enum FinampWidgetAction: String, Codable, Sendable {
    case togglePlayback
    case previous
    case next
    case toggleFavorite
    case setRating
    case clearRating
}

enum FinampWidgetActionDispatcher {
    @MainActor
    static var handler: ((FinampWidgetAction, Double?) async throws -> Void)?

    @MainActor
    static func perform(
        _ action: FinampWidgetAction,
        rating: Double? = nil
    ) async throws {
        guard let handler else {
            throw NSError(
                domain: "FinampWidget",
                code: 2,
                userInfo: [
                    NSLocalizedDescriptionKey:
                        "Widget action handler is unavailable"
                ]
            )
        }

        // The handler returns only after Finamp has completed the action and
        // persisted one final coherent shared-state snapshot. Reload exactly
        // once afterwards so WidgetKit cannot keep rendering the previous
        // timeline when no later artwork/state event happens to trigger one.
        try await handler(action, rating)
        WidgetCenter.shared.reloadTimelines(ofKind: FinampWidgetShared.kind)
    }
}

@available(iOS 17.0, *)
struct TogglePlaybackIntent: AudioPlaybackIntent {
    static let title: LocalizedStringResource = "Play or Pause"

    func perform() async throws -> some IntentResult {
        try await FinampWidgetActionDispatcher.perform(.togglePlayback)
        return .result()
    }
}

@available(iOS 17.0, *)
struct PreviousTrackIntent: AudioPlaybackIntent {
    static let title: LocalizedStringResource = "Previous Track"

    func perform() async throws -> some IntentResult {
        try await FinampWidgetActionDispatcher.perform(.previous)
        return .result()
    }
}

@available(iOS 17.0, *)
struct NextTrackIntent: AudioPlaybackIntent {
    static let title: LocalizedStringResource = "Next Track"

    func perform() async throws -> some IntentResult {
        try await FinampWidgetActionDispatcher.perform(.next)
        return .result()
    }
}

// iOS 27 introduces explicit process targeting for App Intents.
// Metadata writes stay in Finamp's main process so the widget extension never
// owns Jellyfin credentials or a second network stack.
@available(iOS 27.0, *)
struct ToggleFavoriteIntent: AppIntent {
    static let title: LocalizedStringResource = "Toggle Favorite"
#if compiler(>=6.4)
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
    static var supportedModes: IntentModes { .background }
#endif

    func perform() async throws -> some IntentResult {
        try await FinampWidgetActionDispatcher.perform(.toggleFavorite)
        return .result()
    }
}

@available(iOS 27.0, *)
struct SetStarRatingIntent: AppIntent {
    static let title: LocalizedStringResource = "Set Rating"
#if compiler(>=6.4)
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
    static var supportedModes: IntentModes { .background }
#endif

    @Parameter(title: "Stars")
    var stars: Double

    init() {}

    init(stars: Double) {
        self.stars = stars
    }

    func perform() async throws -> some IntentResult {
        guard (1...5).contains(stars) else {
            throw NSError(
                domain: "FinampWidget",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "Rating must be between 1 and 5 stars"]
            )
        }
        try await FinampWidgetActionDispatcher.perform(.setRating, rating: stars)
        return .result()
    }
}

@available(iOS 27.0, *)
struct ClearStarRatingIntent: AppIntent {
    static let title: LocalizedStringResource = "Clear Rating"
#if compiler(>=6.4)
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
    static var supportedModes: IntentModes { .background }
#endif

    func perform() async throws -> some IntentResult {
        try await FinampWidgetActionDispatcher.perform(.clearRating)
        return .result()
    }
}
