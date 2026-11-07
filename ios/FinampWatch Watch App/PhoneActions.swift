import SwiftUI

/// Shares favourite state and optimistic changes across loaded screens.
@Observable
final class FavoriteOverrides {
    static let shared = FavoriteOverrides()

    private var values: [String: Bool] = [:]
    /// Pending edits must not be overwritten by an older phone reply.
    private var pending: Set<String> = []

    func value(for item: LibraryItem) -> Bool { values[item.id] ?? item.favorite }

    func removeAll() {
        values = [:]
    }

    func phoneReported(_ id: String, _ favorite: Bool) {
        guard !id.isEmpty, !pending.contains(id), values[id] != favorite else { return }
        values[id] = favorite
    }

    /// Updates optimistically and reverts if the phone cannot be reached.
    func toggle(_ item: LibraryItem) async {
        let new = !value(for: item)
        values[item.id] = new
        pending.insert(item.id)
        defer { pending.remove(item.id) }
        do {
            values[item.id] = try await PhoneConnection.shared.setFavorite(item.id, new)
        } catch {
            values[item.id] = !new
            PhoneMessage.shared.text = error.localizedDescription
        }
    }
}

/// A message to show as an alert over the pages, e.g. Finamp refusing a change while offline.
@Observable
final class PhoneMessage {
    static let shared = PhoneMessage()
    var text: String?
}

extension View {
    /// Adds a button to download the item on the phone.
    func phoneDownloadButton(for item: LibraryItem, downloaded: Bool, lock: String?, shown: Bool = true) -> some View {
        modifier(PhoneDownloadButton(item: item, initiallyDownloaded: downloaded, lock: lock, shown: shown))
    }
}

/// Downloads on the phone, presenting its download questions on the watch.
private struct PhoneDownloadButton: ViewModifier {
    let item: LibraryItem
    /// Initial state from the page, overridden by a download started here.
    let initiallyDownloaded: Bool
    /// Shows the dependency lock explanation while still allowing a separate download.
    let lock: String?
    let shown: Bool

    @State private var isDownloaded: Bool?
    @State private var downloadMessage: String?
    @State private var downloadQuestion: DownloadQuestion?
    @State private var downloadAnswers: [String: Any] = [:]
    @State private var showLock = false

    private var downloaded: Bool { isDownloaded ?? initiallyDownloaded }
    private var locked: Bool { lock != nil && !downloaded }

    private var icon: String {
        if downloaded { return "arrow.down.circle.fill" }
        return locked ? "lock.circle" : "arrow.down.circle"
    }

    func body(content: Content) -> some View {
        content
            .toolbar {
                if shown {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            if locked {
                                showLock = true
                            } else {
                                Task { await download() }
                            }
                        } label: {
                            Image(systemName: icon)
                                .foregroundStyle(downloaded ? Color.finampBlue : Color.fgPrimary)
                        }
                        .accessibilityLabel(
                            downloaded ? String(localized: "Downloaded on iPhone")
                                : locked ? String(localized: "Downloaded as part of another download")
                                : String(localized: "Download on iPhone")
                        )
                    }
                }
            }
            .confirmationDialog(
                lock?.isEmpty == false ? lock! : String(localized: "Downloaded as part of another download"),
                isPresented: $showLock,
                titleVisibility: .visible
            ) {
                Button("Download") { Task { await download() } }
                Button("Cancel", role: .cancel) {}
            }
            .alert(downloadMessage ?? "", isPresented: Binding(get: { downloadMessage != nil }, set: { if !$0 { downloadMessage = nil } })) {
                Button("OK") { downloadMessage = nil }
            }
            .confirmationDialog(
                downloadQuestionTitle,
                isPresented: Binding(get: { downloadQuestion != nil }, set: { if !$0 { downloadQuestion = nil } }),
                titleVisibility: .visible
            ) {
                switch downloadQuestion {
                case .transcode(let transcodedLabel):
                    Button("Original") { answer("transcode", false) }
                    Button(transcodedLabel) { answer("transcode", true) }
                case .location(let locations):
                    ForEach(locations, id: \.self) { location in
                        Button(location.name) { answer("locationId", location.id) }
                    }
                case .confirm:
                    Button("Download") { answer("confirmed", true) }
                case nil:
                    EmptyView()
                }
                Button("Cancel", role: .cancel) { downloadQuestion = nil }
            }
    }

    /// Repeats the request with accumulated answers until the phone starts downloading.
    private func download(answers: [String: Any] = [:]) async {
        guard !downloaded else {
            downloadMessage = String(localized: "Downloaded on your iPhone")
            return
        }
        do {
            switch try await PhoneConnection.shared.download(item.id, answers: answers) {
            case .downloading:
                isDownloaded = true
                downloadMessage = String(localized: "Downloading on your iPhone")
            case .alreadyDownloaded:
                isDownloaded = true
                downloadMessage = String(localized: "Already downloaded on your iPhone")
            case .ask(let question):
                downloadAnswers = answers
                downloadQuestion = question
            }
        } catch {
            downloadMessage = error.localizedDescription
        }
    }

    private func answer(_ key: String, _ value: Any) {
        var answers = downloadAnswers
        answers[key] = value
        downloadQuestion = nil
        Task { await download(answers: answers) }
    }

    private var downloadQuestionTitle: String {
        switch downloadQuestion {
        case .transcode: return String(localized: "Transcode?")
        case .location: return String(localized: "Download Location")
        case .confirm(let message): return message
        case nil: return ""
        }
    }
}
