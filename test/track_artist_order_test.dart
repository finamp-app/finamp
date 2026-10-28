import 'package:audio_service/audio_service.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/services/track_artist_order.dart';
import 'package:flutter_test/flutter_test.dart';

NameIdPair artist(String id, String? name) => NameIdPair(id: BaseItemId(id), name: name);

BaseItemDto song() => BaseItemDto(
  id: const BaseItemId('song'),
  type: 'Audio',
  name: 'Song',
  artists: ['B Guest', 'Z Lead', 'A Guest'],
  artistItems: [artist('a', 'A Guest'), artist('z', 'Z Lead'), artist('b', 'B Guest')],
  albumArtist: 'Z Lead',
  albumArtists: [artist('z', 'Z Lead')],
);

List<String?> names(BaseItemDto item, TrackArtistOrder order) =>
    orderedTrackArtists(item, order).map((artist) => artist.name).toList();

void main() {
  test('default puts a credited album artist before alphabetically ordered guests', () {
    expect(DefaultSettings.trackArtistOrder, TrackArtistOrder.albumArtistsFirst);
    expect(names(song(), DefaultSettings.trackArtistOrder), ['Z Lead', 'A Guest', 'B Guest']);
  });

  test('metadata mode follows song credits rather than artist lookup order', () {
    expect(names(song(), TrackArtistOrder.metadata), ['B Guest', 'Z Lead', 'A Guest']);
  });

  test('alphabetical mode remains available', () {
    expect(names(song(), TrackArtistOrder.alphabetical), ['A Guest', 'B Guest', 'Z Lead']);
  });

  test('first-credited mode keeps the first song credit and sorts the others', () {
    expect(names(song(), TrackArtistOrder.firstArtistFirst), ['B Guest', 'A Guest', 'Z Lead']);
  });

  test('multiple credited album artists retain their metadata order before guests', () {
    final item = song()..albumArtists = [artist('z', 'Z Lead'), artist('b', 'B Guest')];
    expect(names(item, TrackArtistOrder.albumArtistsFirst), ['Z Lead', 'B Guest', 'A Guest']);
  });

  test('compilation artist is not inserted or treated as the track lead', () {
    final item = song()
      ..albumArtist = 'Various Artists'
      ..albumArtists = [artist('various', 'Various Artists')];
    expect(names(item, TrackArtistOrder.albumArtistsFirst), ['B Guest', 'Z Lead', 'A Guest']);
  });

  test('missing album credits preserve song metadata order', () {
    final item = song()
      ..albumArtist = null
      ..albumArtists = null;
    expect(names(item, TrackArtistOrder.albumArtistsFirst), ['B Guest', 'Z Lead', 'A Guest']);
  });

  test('scalar album-artist fallback matches names without case or whitespace sensitivity', () {
    final item = song()
      ..albumArtist = ' z LEAD '
      ..albumArtists = null;
    expect(names(item, TrackArtistOrder.albumArtistsFirst), ['Z Lead', 'A Guest', 'B Guest']);
  });

  test('matching IDs take priority over different spellings of artist names', () {
    final item = song()..albumArtists = [artist('z', 'Z Lead alias')];
    expect(names(item, TrackArtistOrder.albumArtistsFirst), ['Z Lead', 'A Guest', 'B Guest']);
  });

  test('a different artist ID with the same name does not establish a lead', () {
    final item = song()..albumArtists = [artist('other-z', 'Z Lead')];
    expect(names(item, TrackArtistOrder.albumArtistsFirst), ['B Guest', 'Z Lead', 'A Guest']);
  });

  test('name-only credits are retained and can match an album credit', () {
    final item = song()..artistItems = null;
    expect(names(item, TrackArtistOrder.albumArtistsFirst), ['Z Lead', 'A Guest', 'B Guest']);
    expect(orderedTrackArtists(item, TrackArtistOrder.metadata).every((artist) => artist.id == null), isTrue);
  });

  test('artist lookup data is a fallback when the name-only list is absent', () {
    final item = song()..artists = null;
    expect(names(item, TrackArtistOrder.metadata), ['A Guest', 'Z Lead', 'B Guest']);
    expect(names(item, TrackArtistOrder.albumArtistsFirst), ['Z Lead', 'A Guest', 'B Guest']);
  });

  test('duplicate IDs are displayed once without dropping other artists', () {
    final item = song()
      ..artists = ['Z Lead', 'Z Lead', 'A Guest']
      ..artistItems = [artist('z', 'Z Lead'), artist('z', 'Z Lead alias'), artist('a', 'A Guest')];
    expect(names(item, TrackArtistOrder.metadata), ['Z Lead', 'A Guest']);
  });

  test('unresolved repeated names are displayed once', () {
    final item = song()
      ..artists = ['Z Lead', 'z lead', 'A Guest']
      ..artistItems = null;
    expect(names(item, TrackArtistOrder.metadata), ['Z Lead', 'A Guest']);
  });

  test('distinct IDs with the same display name remain distinct', () {
    final item = song()
      ..artists = null
      ..artistItems = [artist('one', 'Alex'), artist('two', 'Alex')]
      ..albumArtists = [artist('two', 'Alex')];
    expect(orderedTrackArtists(item, TrackArtistOrder.albumArtistsFirst).map((artist) => artist.id?.raw), [
      'two',
      'one',
    ]);
  });

  test('empty names do not appear before known credits in alphabetical mode', () {
    final item = song()
      ..artists = null
      ..artistItems = [artist('unknown', null), artist('z', 'Z Lead')];
    expect(names(item, TrackArtistOrder.alphabetical), ['Z Lead', null]);
  });

  test('unmatched artist lookups do not add credits absent from the song metadata', () {
    final item = song()
      ..artists = ['Z Lead', 'A Guest']
      ..artistItems = [artist('z', 'Z Lead alias'), artist('a', 'A Guest')];
    expect(names(item, TrackArtistOrder.metadata), ['Z Lead', 'A Guest']);
    expect(orderedTrackArtists(item, TrackArtistOrder.metadata).first.id, isNull);
  });

  test('no song artists falls back to the existing scalar album credit for text', () {
    final item = song()
      ..artists = []
      ..artistItems = [];
    expect(trackArtistNames(item, TrackArtistOrder.albumArtistsFirst), 'Z Lead');
    expect(orderedTrackArtists(item, TrackArtistOrder.albumArtistsFirst), isEmpty);
  });

  test('all ordering modes preserve source metadata and list identities', () {
    final item = song();
    final metadata = item.toJson();
    final sourceArtists = item.artists;
    final sourceArtistItems = item.artistItems;
    for (final order in TrackArtistOrder.values) {
      orderedTrackArtists(item, order);
      expect(item.toJson(), metadata);
      expect(item.artists, same(sourceArtists));
      expect(item.artistItems, same(sourceArtistItems));
    }
  });

  test('offline metadata produces the same order and navigation IDs', () {
    final item = song();
    final offlineItem = BaseItemDto.fromJson(item.toJson(setOffline: true));
    final credits = orderedTrackArtists(offlineItem, TrackArtistOrder.albumArtistsFirst);
    expect(credits.map((artist) => artist.name), ['Z Lead', 'A Guest', 'B Guest']);
    expect(credits.map((artist) => artist.id?.raw), ['z', 'a', 'b']);
  });

  test('cached queue metadata changes without changing queue identity, sources or playback metadata', () {
    final item = song();
    final media = MediaItem(
      id: 'media-id',
      title: 'Song',
      artist: 'A Guest, B Guest, Z Lead',
      duration: const Duration(minutes: 3),
      artUri: Uri.parse('file:///test/cover.png'),
      extras: {'itemJson': item.toJson(), 'playSessionId': 'session', 'downloadedTrackPath': '/test/song.flac'},
    );
    final queued = FinampQueueItem(
      item: media,
      source: QueueServiceSourceFixture.source,
      type: QueueItemQueueType.currentTrack,
    );
    final id = queued.id;
    updateQueueArtistOrder([queued], TrackArtistOrder.albumArtistsFirst);
    expect(queued.item.artist, 'Z Lead, A Guest, B Guest');
    expect(queued.id, id);
    expect(queued.source, same(QueueServiceSourceFixture.source));
    expect(queued.type, QueueItemQueueType.currentTrack);
    expect(queued.item.id, media.id);
    expect(queued.item.title, media.title);
    expect(queued.item.duration, media.duration);
    expect(queued.item.artUri, media.artUri);
    expect(queued.item.extras, media.extras);
    updateQueueArtistOrder([queued], TrackArtistOrder.metadata);
    expect(queued.item.artist, 'B Guest, Z Lead, A Guest');
    expect(queued.baseItem.toJson(), item.toJson());
  });
}

class QueueServiceSourceFixture {
  static const source = QueueItemSource.rawId(
    type: QueueItemSourceType.unknown,
    name: QueueItemSourceName(type: QueueItemSourceNameType.savedQueue),
    id: 'artist-order-test',
  );
}
