import 'dart:io';
import 'dart:typed_data';

import 'package:finamp/hive_registrar.g.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/models/locale_adapter.dart';
import 'package:finamp/models/theme_mode_adapter.dart';
import 'package:hive_ce_flutter/adapters.dart';

FinampSettings artistOrderSettings() => FinampSettings(
  downloadLocations: [],
  downloadLocationsMap: {},
  tabSortBy: {},
  tabSortOrder: {},
  homeScreenConfiguration: const FinampHomeScreenConfiguration(actions: [], sections: []),
  gridImageSize: 160,
  homeScreenImageSize: 160,
  deviceId: 'artist-order-test-device',
  showArtistChipImage: false,
);

Future<Directory> setUpArtistOrderSettings({bool inMemory = false}) async {
  final directory = await Directory.systemTemp.createTemp('finamp-artist-order-');
  Hive.init(directory.path);
  if (!Hive.isAdapterRegistered(28)) {
    Hive.registerAdapters();
    Hive.registerAdapter(ThemeModeAdapter());
    Hive.registerAdapter(ColorAdapter());
    Hive.registerAdapter(LocaleAdapter());
  }
  final box = await Hive.openBox<FinampSettings>('FinampSettings', bytes: inMemory ? Uint8List(0) : null);
  await box.put('FinampSettings', artistOrderSettings());
  return directory;
}

Future<void> tearDownArtistOrderSettings(Directory directory) async {
  await Hive.close();
  await directory.delete(recursive: true);
}
