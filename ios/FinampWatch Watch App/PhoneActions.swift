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
            PhoneMessage.show(error)
        }
    }
}

@Observable
final class PhoneMessage {
    static let shared = PhoneMessage()
    var text: String?

    // A failed action's message. A connection failure shows only the warning under the clock, never a message; errors
    // the phone answered still show.
    static func show(_ error: Error) {
        guard !(error is CancellationError), !PhoneConnection.isConnectionFailure(error) else { return }
        shared.text = error.localizedDescription
    }
}

// The small status under the clock (`phoneActivityIndicator`): waiting while a request you made has gone
// `ConnectionPolicy.Status.showAfter` without an answer; failed when one couldn't reach the phone (not when the phone
// answered with an error of its own). A failure shows for `ConnectionPolicy.Status.failedFor`, or until the phone
// answers anything. Reconnecting: the whole time the phone is in reach and not answering (`ConnectionPolicy.Health`),
// while the watch restarts its connection and keeps asking; this is not ordinary waiting, so it has its own sign.
// Reconnected: for `ConnectionPolicy.Status.reconnectedFor` once such a phone answers again; never after ordinary
// waiting or a wrist raise.
@Observable
final class PhoneActivity {
    static let shared = PhoneActivity()
    enum State { case idle, waiting, failed, reconnecting, reconnected }
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
    // The phone is in reach and answers nothing (`ConnectionPolicy.Health`): the reconnecting sign shows until it does.
    @ObservationIgnored private var notAnswering = false
    @ObservationIgnored private var reconnectedUntil: ContinuousClock.Instant?

    func setNotAnswering(_ value: Bool) {
        let answersAgain = notAnswering && !value
        notAnswering = value
        if answersAgain {
            // A request that failed during the silence must not turn the sign orange again now.
            failedUntil = nil
            let until = ContinuousClock.now + ConnectionPolicy.Status.reconnectedFor
            reconnectedUntil = until
            Task {
                try? await Task.sleep(until: until, clock: .continuous)
                guard reconnectedUntil == until else { return }
                reconnectedUntil = nil
                update()
            }
        } else if value {
            reconnectedUntil = nil
        }
        update()
    }

    func begin() -> Int {
        next += 1
        let token = next
        running.insert(token)
        Task {
            try? await Task.sleep(for: ConnectionPolicy.Status.showAfter)
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
            // Just reconnected: a request left over from the silence ends now, and says nothing new.
            guard reconnectedUntil == nil else { break }
            let until = ContinuousClock.now + ConnectionPolicy.Status.failedFor
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

    // Reconnecting wins over everything while it lasts (single requests failing or waiting meanwhile say nothing new);
    // then a shown failure wins over the reconnected sign, and that over waiting.
    private func update() {
        let new: State = notAnswering ? .reconnecting : failedUntil != nil ? .failed
            : reconnectedUntil != nil ? .reconnected : (slow.isEmpty ? .idle : .waiting)
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
