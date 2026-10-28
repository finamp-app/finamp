import SwiftUI

/// Favourite albums or artists with collection playback actions.
struct FavoritesListView: View {
    let title: String
    /// "favoriteAlbums" or "favoriteArtists".
    let type: String
    let onPlay: () -> Void
    @State private var state: ListState = .loading

    private var isArtists: Bool { type == "favoriteArtists" }
    private var kind: LibraryKind { isArtists ? .artists : .albums }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 6) {
                header
                switch state {
                case .loading:
                    SkeletonCoverRows(count: 3, coverFraction: kind.coverFraction, circular: isArtists)
                case .failed(let message):
                    RetryView(message: message) { await load() }
                case .loaded(let items) where items.isEmpty:
                    Text(isArtists ? String(localized: "No favorite artists yet") : String(localized: "No favorite albums yet"))
                        .font(.footnote)
                        .foregroundStyle(Color.fgSecondary)
                        .frame(maxWidth: .infinity)
                case .loaded(let items):
                    ForEach(items) { item in
                        CollectionLink(item: item, kind: kind)
                    }
                }
            }
        }
        .navigationTitle("")
        .task { if case .loading = state { await load() } }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                FavoritesLogo(symbol: kind.placeholderSymbol, circular: isArtists)
                    .containerRelativeFrame(.horizontal) { width, _ in width * 0.42 }
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Color.fgPrimary)
                        .lineLimit(3)
                    if case .loaded(let items) = state {
                        Text(countText(items.count))
                            .font(.caption2)
                            .foregroundStyle(Color.fgSecondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack {
                LabeledIconButton(title: "Play", systemImage: "play") { await play(shuffle: false) }
                LabeledIconButton(title: "Shuffle", systemImage: "shuffle") { await play(shuffle: true) }
            }
        }
        .padding(.bottom, 4)
    }

    private func countText(_ count: Int) -> String {
        if isArtists {
            return count == 1 ? String(localized: "1 artist") : String(localized: "\(count) artists")
        }
        return count == 1 ? String(localized: "1 album") : String(localized: "\(count) albums")
    }

    private func load() async {
        state = .loading
        do {
            state = .loaded(try await PhoneConnection.shared.list(type))
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    private func play(shuffle: Bool) async {
        do {
            try await PhoneConnection.shared.play(type, shuffle: shuffle)
            onPlay()
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}
