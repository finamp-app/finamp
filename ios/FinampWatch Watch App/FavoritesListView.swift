import SwiftUI

struct FavoritesListView: View {
    let title: String
    let type: String
    @State private var pager: Pager

    init(title: String, type: String) {
        self.title = title
        self.type = type
        _pager = State(initialValue: Pager { offset, limit in
            try await PhoneConnection.shared.list(type, offset: offset, limit: limit)
        })
    }

    private var isArtists: Bool { type == "favoriteArtists" }
    private var kind: LibraryKind { isArtists ? .artists : .albums }

    var body: some View {
        // A List like the track pages, for watchOS's shrinking rows at the screen edges.
        List {
            Group {
                header
                // The list under a heading that separates it from the logo, as the Downloads headings do.
                HeadedSection(title: kind.title) {
                    switch pager.state {
                    case .loading:
                        SkeletonCoverRows(count: 3, coverShare: kind.coverShare, circular: isArtists)
                    case .failed(let message):
                        RetryView(message: message, inList: true) { await pager.load() }
                    case .loaded(let items) where items.isEmpty:
                        EmptyNote(
                            text: isArtists ? String(localized: "No favorite artists yet") : String(localized: "No favorite albums yet"),
                            inList: true
                        )
                    case .loaded(let items):
                        ForEach(items) { item in
                            CollectionLink(item: item, kind: kind)
                                .coverListRow()
                                .onAppear {
                                    if pager.nearsEnd(item.id, in: items) { Task { await pager.loadMore() } }
                                }
                        }
                    }
                }
            }
            .clearListRow()
        }
        .coverList()
        .navigationTitle(title)
        .accentTitle()
        .task { if case .loading = pager.state { await pager.load() } }
    }

    // The page's name is the title at the top right, as the queue's "Now Playing"; no Play/Shuffle. Logo and count sit
    // in the cover row.
    private var header: some View {
        PageCoverRow {
            FavoritesLogo(circular: isArtists)
        } info: {
            if case .loaded(let items) = pager.state, !pager.hasMore {
                // As the other pages' headers (Finamp's wording, its icon for the kind).
                if isArtists {
                    StatLine(symbol: "person", text: FinampFormat.artists(items.count))
                } else {
                    StatLine(symbol: "opticaldisc", text: FinampFormat.albums(items.count))
                }
            }
        }
    }
}
