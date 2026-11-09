import 'dart:io';

import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

import 'support/artist_order_settings.dart';

// Settings payload from before field 165 existed. IDs are the established Hive
// schema; the reader under test is the actual generated production adapter.
class PreArtistOrderSettingsAdapter extends TypeAdapter<FinampSettings> {
  @override
  int get typeId => 28;

  @override
  FinampSettings read(BinaryReader reader) => FinampSettingsAdapter().read(reader);

  @override
  void write(BinaryWriter writer, FinampSettings obj) {
    final fields = <int, dynamic>{
      0: obj.isOffline,
      2: obj.transcodeBitrate,
      3: obj.downloadLocations,
      15: obj.downloadLocationsMap,
      20: obj.tabSortBy,
      21: obj.tabSortOrder,
      146: obj.homeScreenConfiguration,
      147: obj.gridImageSize,
      150: obj.homeScreenImageSize,
      152: obj.deviceId,
      161: obj.closeToTray,
      162: obj.minimizeToTray,
      163: obj.startMinimizedToTray,
      164: obj.autoReloadQueueMaxDroppedTracksPercentage,
    };
    writer.writeByte(fields.length);
    for (final field in fields.entries) {
      writer.writeByte(field.key);
      writer.write(field.value);
    }
  }
}

void main() {
  late Directory directory;
  setUp(() async => directory = await setUpArtistOrderSettings());
  tearDown(() => tearDownArtistOrderSettings(directory));

  test('existing settings without the new field adopt the default and retain stored values', () async {
    await Hive.box<FinampSettings>('FinampSettings').close();
    Hive.registerAdapter<FinampSettings>(PreArtistOrderSettingsAdapter(), override: true);
    var box = await Hive.openBox<FinampSettings>('FinampSettings');
    final original = artistOrderSettings()
      ..isOffline = true
      ..transcodeBitrate = 192000
      ..closeToTray = true
      ..minimizeToTray = true
      ..startMinimizedToTray = true
      ..autoReloadQueueMaxDroppedTracksPercentage = 42
      ..tabSortBy = {ContentType.tracks: SortBy.dateCreated}
      ..tabSortOrder = {ContentType.tracks: SortOrder.descending};
    await box.put('FinampSettings', original);
    await box.close();
    Hive.registerAdapter<FinampSettings>(FinampSettingsAdapter(), override: true);
    box = await Hive.openBox<FinampSettings>('FinampSettings');
    final restored = box.get('FinampSettings')!;
    expect(restored.trackArtistOrder, TrackArtistOrder.albumArtistsFirst);
    expect(restored.deviceId, original.deviceId);
    expect(restored.isOffline, isTrue);
    expect(restored.transcodeBitrate, 192000);
    expect(restored.closeToTray, isTrue);
    expect(restored.minimizeToTray, isTrue);
    expect(restored.startMinimizedToTray, isTrue);
    expect(restored.autoReloadQueueMaxDroppedTracksPercentage, 42);
    expect(restored.tabSortBy, original.tabSortBy);
    expect(restored.tabSortOrder, original.tabSortOrder);
    expect(restored.gridImageSize, original.gridImageSize);
    expect(restored.homeScreenImageSize, original.homeScreenImageSize);
  });

  for (final order in TrackArtistOrder.values) {
    test('$order survives closing and reopening settings', () async {
      final settings = FinampSettingsHelper.finampSettings
        ..closeToTray = true
        ..minimizeToTray = true
        ..startMinimizedToTray = true
        ..autoReloadQueueMaxDroppedTracksPercentage = 42;
      FinampSetters.setTrackArtistOrder(order);
      await Hive.box<FinampSettings>('FinampSettings').close();
      final box = await Hive.openBox<FinampSettings>('FinampSettings');
      expect(box.get('FinampSettings')!.trackArtistOrder, order);
      expect(box.get('FinampSettings')!.deviceId, 'artist-order-test-device');
      final restored = box.get('FinampSettings')!;
      expect(restored.closeToTray, settings.closeToTray);
      expect(restored.minimizeToTray, settings.minimizeToTray);
      expect(restored.startMinimizedToTray, settings.startMinimizedToTray);
      expect(restored.autoReloadQueueMaxDroppedTracksPercentage, settings.autoReloadQueueMaxDroppedTracksPercentage);
    });
  }

  test('reset layout settings restores the artist-order default', () async {
    FinampSetters.setTrackArtistOrder(TrackArtistOrder.alphabetical);
    FinampSettingsHelper.resetLayoutSettings();
    expect(FinampSettingsHelper.finampSettings.trackArtistOrder, DefaultSettings.trackArtistOrder);
    await Hive.box<FinampSettings>('FinampSettings').close();
    final box = await Hive.openBox<FinampSettings>('FinampSettings');
    expect(box.get('FinampSettings')!.trackArtistOrder, DefaultSettings.trackArtistOrder);
  });
}
