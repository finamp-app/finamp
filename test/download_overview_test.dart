import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final itemType in ['MusicAlbum', 'Audio']) {
    test('downloaded $itemType metadata persists updated and cleared descriptions', () {
      BaseItemDto item(String? overview) =>
          BaseItemDto(id: const BaseItemId('item'), name: 'Example', type: itemType, overview: overview);
      final type = itemType == 'Audio' ? DownloadItemType.track : DownloadItemType.collection;
      final original = DownloadStub.fromItem(type: type, item: item('Old description')).asItem(null);

      final updated = original.copyWith(item: item('New description'), forceCopy: false);
      expect(updated, isNotNull);
      expect(updated!.baseItem!.overview, 'New description');
      final cleared = updated.copyWith(item: item(null), forceCopy: false);
      expect(cleared, isNotNull);
      expect(cleared!.baseItem!.overview, isNull);
    });
  }
}
