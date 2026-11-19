import SwiftUI

// Shares favourite state and optimistic changes across screens.
@Observable
final class FavoriteOverrides {
    static let shared = FavoriteOverrides()

    private var values: [String: Bool] = [:]
    // Avoid overwriting pending edits with an older phone reply.
    private var pending: Set<String> = []

    func value(for item: LibraryItem) -> Bool { values[item.id] ?? item.favorite }

    func removeAll() {
        values = [:]
    }

    func phoneReported(_ id: String, _ favorite: Bool) {
        guard !id.isEmpty, !pending.contains(id), values[id] != favorite else { return }
        values[id] = favorite
    }

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

@Observable
final class PhoneMessage {
    static let shared = PhoneMessage()
    var text: String?
}

// The small status under the clock (`phoneActivityIndicator`): waiting while a request you made has gone
// `ActivityStatus.showAfter` without an answer; failed when one couldn't reach the phone (not when the phone answered
// with an error of its own). A failure shows for `ActivityStatus.failedFor`, or until the phone answers anything.
@Observable
final class PhoneActivity {
    static let shared = PhoneActivity()
    enum State { case idle, waiting, failed }
    enum Outcome {
        // The phone replied, with a result or an error of its own: the connection works.
        case answered
        // Nothing got through, or no answer came.
        case connectionFailed
        // Cancelled, or stopped for a reason that says nothing about the connection.
        case neutral
    }
    private(set) var state = State.idle
    @ObservationIgnored private var running: Set<Int> = []
    @ObservationIgnored private var slow: Set<Int> = []
    @ObservationIgnored private var failedUntil: ContinuousClock.Instant?
    @ObservationIgnored private var next = 0

    func begin() -> Int {
        next += 1
        let token = next
        running.insert(token)
        Task {
            try? await Task.sleep(for: ActivityStatus.showAfter)
            guard running.contains(token) else { return }
            slow.insert(token)
            update()
        }
        return token
    }

    // An answer within a longer request (one try of a volume change) ends a shown failure too.
    func answered() {
        failedUntil = nil
        update()
    }

    func end(_ token: Int, _ outcome: Outcome) {
        running.remove(token)
        slow.remove(token)
        switch outcome {
        case .answered:
            failedUntil = nil
        case .connectionFailed:
            let until = ContinuousClock.now + ActivityStatus.failedFor
            failedUntil = until
            Task {
                try? await Task.sleep(until: until, clock: .continuous)
                guard failedUntil == until else { return }
                failedUntil = nil
                update()
            }
        case .neutral:
            break
        }
        update()
    }

    // A shown failure wins over waiting until it ends.
    private func update() {
        let new: State = failedUntil != nil ? .failed : (slow.isEmpty ? .idle : .waiting)
        if new != state { state = new }
    }
}

// The download button in a page's title row, beside the heart and in the same plain style.
struct PhoneDownloadButton: View {
    let item: LibraryItem
    let initiallyDownloaded: Bool
    let lock: String?
    // "album", "playlist" or "artist", for Finamp's delete question.
    let itemType: String

    @State private var isDownloaded: Bool?
    @State private var downloadMessage: String?
    @State private var downloadQuestion: DownloadQuestion?
    @State private var downloadAnswers: [String: Any] = [:]
    @State private var showLock = false
    @State private var showDelete = false
    // Follows the title's text, as the heart beside it.
    @ScaledMetric(relativeTo: .headline) private var iconSize = PageHeader.downloadIconSize

    // Prefer a download started here over the list row's snapshot.
    private var downloaded: Bool { isDownloaded ?? initiallyDownloaded }
    private var locked: Bool { lock != nil && !downloaded }

    // As Finamp: the trash when downloaded, the lock when it is part of another download, else the download arrow.
    private var icon: String {
        if downloaded { return "trash" }
        return locked ? "lock.circle" : "arrow.down.circle"
    }

    var body: some View {
        Button {
            if downloaded {
                showDelete = true
            } else if locked {
                showLock = true
            } else {
                Task { await download() }
            }
        } label: {
            FinampIcon(systemName: icon, size: iconSize)
                .foregroundStyle(Color.fgPrimary)
                .padding(4)
                .iconTapArea(iconSize + 8)
        }
        .buttonStyle(.plain)
        .padding(-4)
        .accessibilityLabel(
            downloaded ? String(localized: "Delete from Device")
                : locked ? String(localized: "Downloaded as part of another download")
                : String(localized: "Download on iPhone")
        )
            .confirmationDialog(
                lock?.isEmpty == false ? lock! : String(localized: "Downloaded as part of another download"),
                isPresented: $showLock,
                titleVisibility: .visible
            ) {
                Button("Download") { Task { await download() } }
                Button("Cancel", role: .cancel) {}
            }
            // Finamp's own question and button (deleteFromTargetDialogText, deleteFromTargetConfirmButton).
            .confirmationDialog(deleteQuestion, isPresented: $showDelete, titleVisibility: .visible) {
                Button("Delete from Device", role: .destructive) { Task { await delete() } }
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

    private var deleteQuestion: String {
        switch itemType {
        case "album": return String(localized: "You are about to delete this album from this device.")
        case "playlist": return String(localized: "You are about to delete this playlist from this device.")
        case "artist": return String(localized: "You are about to delete this artist from this device.")
        default: return String(localized: "You are about to delete this item from this device.")
        }
    }

    private func delete() async {
        do {
            let message = try await PhoneConnection.shared.deleteDownload(item.id)
            isDownloaded = false
            if let message { downloadMessage = message }
        } catch {
            downloadMessage = error.localizedDescription
        }
    }

    // Repeat request with answers until downloading starts.
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
