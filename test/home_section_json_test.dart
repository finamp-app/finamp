import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('home section types retain their JSON representation', () {
    expect(QueuesHomeSection().toJson(), isEmpty);
    expect(TabsHomeSection(libraryId: const LibraryId('library'), contentType: ContentType.tracks).toJson(), {
      'libraryId': 'library',
      'contentType': 'tracks',
    });
    expect(
      CollectionHomeSection(
        itemId: const BaseItemId('item'),
        libraryId: const LibraryId('library'),
        contentType: ContentType.albums,
      ).toJson(),
      {'itemId': 'item', 'libraryId': 'library', 'contentType': 'albums'},
    );
  });
}
