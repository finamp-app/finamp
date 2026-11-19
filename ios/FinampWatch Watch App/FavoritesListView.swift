import SwiftUI

struct FavoritesListView: View {
    let title: String
    let type: String
    @State private var state: ListState = .loading
    @State private var hasMore = false
    // Count received rows, including duplicates, for the next offset.
    @State private var phoneOffset = 0
    @State private var isLoadingMore = false
    private static let pageSize = 50

    private var isArtists: Bool { type == "favoriteArtists" }
    private var kind: LibraryKind { isArtists ? .artists : .albums }

    var body: some View {
        // A List like the track pages, for watchOS's shrinking rows at the screen edges.
        List {
            Group {
                header
                switch state {
                case .loading:
                    SkeletonCoverRows(count: 3, coverShare: kind.coverShare, circular: isArtists)
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
                            .coverListRow()
                            .onAppear {
                                if items.suffix(pagePrefetchRows).contains(where: { $0.id == item.id }) {
                                    Task { await loadMore() }
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
        .task { if case .loading = state { await load() } }
    }

    // The page's name is the title at the top right, as the queue's "Now Playing"; no Play/Shuffle. The logo
    // and the count share the row in halves, as on the album and artist pages.
    private var header: some View {
        VStack(alignment: .leading, spacing: PageHeader.favoritesLogoToHeading) {
            HalvesCoverRow {
                FavoritesLogo(symbol: kind.placeholderSymbol, circular: isArtists)
            } info: {
                if case .loaded(let items) = state, !hasMore {
                    Text(countText(items.count))
                        .font(.caption2)
                        .foregroundStyle(Color.fgSecondary)
                }
            }
            // Separates the logo from the list, as the Downloads headings do.
            SectionHeader(title: kind.title)
        }
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
            let first = try await PhoneConnection.shared.list(type, limit: Self.pageSize)
            hasMore = !first.isEmpty
            phoneOffset = first.count
            state = .loaded(first)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    private func loadMore() async {
        guard hasMore, !isLoadingMore, case .loaded(let current) = state else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        guard let page = try? await PhoneConnection.shared.list(type, offset: phoneOffset, limit: Self.pageSize)
        else { return }
        let known = Set(current.map(\.id))
        state = .loaded(current + page.filter { !known.contains($0.id) })
        phoneOffset += page.count
        hasMore = !page.isEmpty
    }
}
