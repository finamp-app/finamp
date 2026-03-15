// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: deprecated_member_use_from_same_package, strict_raw_type

// dart format off


part of 'finamp_models.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class FinampUserAdapter extends TypeAdapter<FinampUser> {
  @override
  final typeId = 8;

  @override
  FinampUser read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FinampUser(
      id: fields[0] as String,
      publicAddress: fields[1] as String,
      localAddress: fields[7] == null
          ? 'http://0.0.0.0:8096'
          : fields[7] as String,
      preferLocalNetwork: fields[9] == null ? false : fields[9] as bool,
      isLocal: fields[8] == null ? false : fields[8] as bool,
      accessToken: fields[2] as String,
      serverId: fields[3] as String,
      currentViewId: fields[4] as BaseItemId?,
      views: fields[5] == null
          ? const {}
          : (fields[5] as Map).cast<BaseItemId, BaseItemDto>(),
    );
  }

  @override
  void write(BinaryWriter writer, FinampUser obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.publicAddress)
      ..writeByte(2)
      ..write(obj.accessToken)
      ..writeByte(3)
      ..write(obj.serverId)
      ..writeByte(4)
      ..write(obj.currentViewId)
      ..writeByte(5)
      ..write(obj.views)
      ..writeByte(7)
      ..write(obj.localAddress)
      ..writeByte(8)
      ..write(obj.isLocal)
      ..writeByte(9)
      ..write(obj.preferLocalNetwork);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FinampUserAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class FinampSettingsAdapter extends TypeAdapter<FinampSettings> {
  @override
  final typeId = 28;

  @override
  FinampSettings read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FinampSettings(
        isOffline: fields[0] == null ? false : fields[0] as bool,
        shouldTranscode: fields[1] == null ? false : fields[1] as bool,
        transcodeBitrate: fields[2] == null
            ? 320000
            : (fields[2] as num).toInt(),
        downloadLocations: (fields[3] as List).cast<DownloadLocation>(),
        androidStopForegroundOnPause: fields[4] == null
            ? true
            : fields[4] as bool,
        showTabs: (fields[5] as Map).cast<TabContentType, bool>(),
        onlyShowFavorites: fields[6] == null ? false : fields[6] as bool,
        sortBy: fields[7] == null ? SortBy.sortName : fields[7] as SortBy,
        sortOrder: fields[8] == null
            ? SortOrder.ascending
            : fields[8] as SortOrder,
        trackShuffleItemCount: fields[9] == null
            ? 250
            : (fields[9] as num).toInt(),
        volumeNormalizationActive: fields[29] == null
            ? true
            : fields[29] as bool,
        volumeNormalizationIOSBaseGain: fields[30] == null
            ? 6.0
            : (fields[30] as num).toDouble(),
        volumeNormalizationMode: fields[33] == null
            ? VolumeNormalizationMode.hybrid
            : fields[33] as VolumeNormalizationMode,
        contentViewType: fields[10] == null
            ? ContentViewType.list
            : fields[10] as ContentViewType,
        playbackSpeedVisibility: fields[57] == null
            ? PlaybackSpeedVisibility.automatic
            : fields[57] as PlaybackSpeedVisibility,
        contentGridViewCrossAxisCountPortrait: fields[11] == null
            ? 2
            : (fields[11] as num).toInt(),
        contentGridViewCrossAxisCountLandscape: fields[12] == null
            ? 3
            : (fields[12] as num).toInt(),
        showTextOnGridView: fields[13] == null ? false : fields[13] as bool,
        downloadLocationsMap: fields[15] == null
            ? {}
            : (fields[15] as Map).cast<String, DownloadLocation>(),
        useCoverAsBackground: fields[16] == null ? true : fields[16] as bool,
        playerScreenCoverMinimumPadding: fields[48] == null
            ? 1.5
            : (fields[48] as num).toDouble(),
        showArtistsTracksSection: fields[54] == null
            ? true
            : fields[54] as bool,
        bufferDisableSizeConstraints: fields[78] == null
            ? false
            : fields[78] as bool,
        bufferDurationSeconds: fields[18] == null
            ? 600
            : (fields[18] as num).toInt(),
        bufferSizeMegabytes: fields[79] == null
            ? 50
            : (fields[79] as num).toInt(),
        tabSortBy: fields[20] == null
            ? {}
            : (fields[20] as Map).cast<TabContentType, SortBy>(),
        tabSortOrder: fields[21] == null
            ? {}
            : (fields[21] as Map).cast<TabContentType, SortOrder>(),
        loopMode: fields[27] == null
            ? FinampLoopMode.none
            : fields[27] as FinampLoopMode,
        playbackSpeed: fields[56] == null
            ? 1.0
            : (fields[56] as num).toDouble(),
        playbackPitch: fields[118] == null
            ? 1.0
            : (fields[118] as num).toDouble(),
        syncPlaybackSpeedAndPitch: fields[119] == null
            ? false
            : fields[119] as bool,
        tabOrder: fields[22] == null
            ? [
                TabContentType.albums,
                TabContentType.artists,
                TabContentType.playlists,
                TabContentType.genres,
                TabContentType.tracks,
              ]
            : (fields[22] as List).cast<TabContentType>(),
        autoloadLastQueueOnStartup: fields[28] == null
            ? true
            : fields[28] as bool,
        hasCompletedDownloadsServiceMigration: fields[34] == null
            ? false
            : fields[34] as bool,
        requireWifiForDownloads: fields[35] == null ? true : fields[35] as bool,
        onlyShowFullyDownloaded: fields[36] == null
            ? false
            : fields[36] as bool,
        showDownloadsWithUnknownLibrary: fields[37] == null
            ? true
            : fields[37] as bool,
        maxConcurrentDownloads: fields[38] == null
            ? 5
            : (fields[38] as num).toInt(),
        downloadWorkers: fields[39] == null ? 1 : (fields[39] as num).toInt(),
        resyncOnStartup: fields[40] == null ? true : fields[40] as bool,
        preferQuickSyncs: fields[41] == null ? true : fields[41] as bool,
        hasCompletedIsarUserMigration: fields[42] == null
            ? false
            : fields[42] as bool,
        downloadTranscodingCodec: fields[43] as FinampTranscodingCodec?,
        downloadTranscodeBitrate: (fields[45] as num?)?.toInt(),
        shouldTranscodeDownloads: fields[44] == null
            ? TranscodeDownloadsSetting.ask
            : fields[44] as TranscodeDownloadsSetting,
        multichannelHandlingSetting: fields[144] == null
            ? MultichannelHandlingSetting.stereoDownmixLossy
            : fields[144] as MultichannelHandlingSetting,
        shouldRedownloadTranscodes: fields[46] == null
            ? false
            : fields[46] as bool,
        itemSwipeActionLeftToRight: fields[90] == null
            ? ItemSwipeActions.nothing
            : fields[90] as ItemSwipeActions,
        itemSwipeActionRightToLeft: fields[91] == null
            ? ItemSwipeActions.addToNextUp
            : fields[91] as ItemSwipeActions,
        useFixedSizeGridTiles: fields[59] == null ? false : fields[59] as bool,
        fixedGridTileSize: fields[60] == null
            ? 150
            : (fields[60] as num).toInt(),
        allowSplitScreen: fields[61] == null ? true : fields[61] as bool,
        splitScreenPlayerWidth: fields[62] == null
            ? 400.0
            : (fields[62] as num).toDouble(),
        enableVibration: fields[47] == null ? true : fields[47] as bool,
        prioritizeCoverFactor: fields[49] == null
            ? 8.0
            : (fields[49] as num).toDouble(),
        suppressPlayerPadding: fields[50] == null ? false : fields[50] as bool,
        hidePlayerBottomActions: fields[51] == null
            ? false
            : fields[51] as bool,
        reportQueueToServer: fields[52] == null ? false : fields[52] as bool,
        periodicPlaybackSessionUpdateFrequencySeconds: fields[53] == null
            ? 150
            : (fields[53] as num).toInt(),
        playOnStaleDelay: fields[94] == null ? 90 : (fields[94] as num).toInt(),
        playOnReconnectionDelay: fields[95] == null
            ? 5
            : (fields[95] as num).toInt(),
        enablePlayon: fields[96] == null ? true : fields[96] as bool,
        currentVolume: fields[93] == null
            ? 1.0
            : (fields[93] as num).toDouble(),
        showArtistChipImage: fields[55] == null ? true : fields[55] as bool,
        trackOfflineFavorites: fields[63] == null ? true : fields[63] as bool,
        showProgressOnNowPlayingBar: fields[64] == null
            ? true
            : fields[64] as bool,
        startInstantMixForIndividualTracks: fields[65] == null
            ? false
            : fields[65] as bool,
        showLyricsTimestamps: fields[66] == null ? true : fields[66] as bool,
        lyricsAlignment: fields[67] == null
            ? LyricsAlignment.start
            : fields[67] as LyricsAlignment,
        lyricsFontSize: fields[70] == null
            ? LyricsFontSize.medium
            : fields[70] as LyricsFontSize,
        showLyricsScreenAlbumPrelude: fields[71] == null
            ? true
            : fields[71] as bool,
        showStopButtonOnMediaNotification: fields[68] == null
            ? false
            : fields[68] as bool,
        showShuffleButtonOnMediaNotification: fields[98] == null
            ? true
            : fields[98] as bool,
        showFavoriteButtonOnMediaNotification: fields[99] == null
            ? true
            : fields[99] as bool,
        showSeekControlsOnMediaNotification: fields[69] == null
            ? true
            : fields[69] as bool,
        keepScreenOnOption: fields[72] == null
            ? KeepScreenOnOption.whileLyrics
            : fields[72] as KeepScreenOnOption,
        keepScreenOnWhilePluggedIn: fields[73] == null
            ? false
            : fields[73] as bool,
        featureChipsConfiguration: fields[76] == null
            ? DefaultSettings.featureChipsConfiguration
            : fields[76] as FinampFeatureChipsConfiguration,
        showCoversOnAlbumScreen: fields[77] == null
            ? false
            : fields[77] as bool,
        hasDownloadedPlaylistInfo: fields[74] == null
            ? false
            : fields[74] as bool,
        transcodingStreamingFormat: fields[75] == null
            ? FinampTranscodingStreamingFormat.aacFragmentedMp4
            : fields[75] as FinampTranscodingStreamingFormat,
        downloadSizeWarningCutoff: fields[80] == null
            ? 150
            : (fields[80] as num).toInt(),
        allowDeleteFromServer: fields[81] == null ? false : fields[81] as bool,
        oneLineMarqueeTextButton: fields[82] == null
            ? false
            : fields[82] as bool,
        showAlbumReleaseDateOnPlayerScreen: fields[83] == null
            ? false
            : fields[83] as bool,
        releaseDateFormat: fields[84] == null
            ? ReleaseDateFormat.year
            : fields[84] as ReleaseDateFormat,
        defaultArtistType: fields[92] == null
            ? ArtistType.albumArtist
            : fields[92] as ArtistType,
        autoOffline: fields[88] == null
            ? AutoOfflineOption.disconnected
            : fields[88] as AutoOfflineOption,
        autoOfflineListenerActive: fields[89] == null
            ? true
            : fields[89] as bool,
        audioFadeOutDuration: fields[86] == null
            ? Duration.zero
            : fields[86] as Duration,
        audioFadeInDuration: fields[87] == null
            ? Duration.zero
            : fields[87] as Duration,
        autoReloadQueue: fields[97] == null ? false : fields[97] as bool,
        screenSize: fields[100] as ScreenSize?,
        genreCuratedItemSelectionTypeTracks: fields[101] == null
            ? CuratedItemSelectionType.mostPlayed
            : fields[101] as CuratedItemSelectionType,
        genreCuratedItemSelectionTypeAlbums: fields[102] == null
            ? CuratedItemSelectionType.latestReleases
            : fields[102] as CuratedItemSelectionType,
        genreCuratedItemSelectionTypeArtists: fields[103] == null
            ? CuratedItemSelectionType.favorites
            : fields[103] as CuratedItemSelectionType,
        genreItemSectionsOrder: fields[104] == null
            ? [
                GenreItemSections.tracks,
                GenreItemSections.albums,
                GenreItemSections.artists,
              ]
            : (fields[104] as List).cast<GenreItemSections>(),
        genreFilterArtistScreens: fields[105] == null
            ? true
            : fields[105] as bool,
        genreListsInheritSorting: fields[106] == null
            ? true
            : fields[106] as bool,
        genreItemSectionFilterChipOrder: fields[107] == null
            ? [
                CuratedItemSelectionType.mostPlayed,
                CuratedItemSelectionType.favorites,
                CuratedItemSelectionType.random,
                CuratedItemSelectionType.latestReleases,
                CuratedItemSelectionType.recentlyAdded,
                CuratedItemSelectionType.recentlyPlayed,
              ]
            : (fields[107] as List).cast<CuratedItemSelectionType>(),
        applyFilterOnGenreChipTap: fields[108] == null
            ? false
            : fields[108] as bool,
        artistCuratedItemSelectionType: fields[109] == null
            ? CuratedItemSelectionType.mostPlayed
            : fields[109] as CuratedItemSelectionType,
        artistItemSectionFilterChipOrder: fields[110] == null
            ? [
                CuratedItemSelectionType.mostPlayed,
                CuratedItemSelectionType.favorites,
                CuratedItemSelectionType.random,
                CuratedItemSelectionType.latestReleases,
                CuratedItemSelectionType.recentlyAdded,
                CuratedItemSelectionType.recentlyPlayed,
              ]
            : (fields[110] as List).cast<CuratedItemSelectionType>(),
        artistItemSectionsOrder: fields[111] == null
            ? [
                ArtistItemSections.tracks,
                ArtistItemSections.albums,
                ArtistItemSections.appearsOn,
              ]
            : (fields[111] as List).cast<ArtistItemSections>(),
        autoSwitchItemCurationType: fields[112] == null
            ? true
            : fields[112] as bool,
        playlistTracksSortBy: fields[113] == null
            ? SortBy.defaultOrder
            : fields[113] as SortBy,
        playlistTracksSortOrder: fields[114] == null
            ? SortOrder.ascending
            : fields[114] as SortOrder,
        genreFilterPlaylists: fields[115] == null ? false : fields[115] as bool,
        clearQueueOnStopEvent: fields[117] == null
            ? false
            : fields[117] as bool,
        useHighContrastColors: fields[120] == null
            ? false
            : fields[120] as bool,
        hasCompletedDownloadsFileOwnerMigration: fields[121] == null
            ? false
            : fields[121] as bool,
        tileAdditionalInfoType: fields[122] == null
            ? {
                TabContentType.tracks: TileAdditionalInfoType.adaptive,
                TabContentType.albums: TileAdditionalInfoType.adaptive,
                TabContentType.artists: TileAdditionalInfoType.adaptive,
                TabContentType.playlists: TileAdditionalInfoType.adaptive,
                TabContentType.genres: TileAdditionalInfoType.adaptive,
              }
            : (fields[122] as Map)
                  .cast<TabContentType, TileAdditionalInfoType>(),
        rpcEnabled: fields[123] == null ? false : fields[123] as bool,
        rpcIcon: fields[124] == null
            ? DiscordRpcIcon.transparent
            : fields[124] as DiscordRpcIcon,
        preferAddingToFavoritesOverPlaylists: fields[126] == null
            ? false
            : fields[126] as bool,
        previousTracksExpaned: fields[127] == null
            ? false
            : fields[127] as bool,
        autoplayRestoredQueue: fields[128] == null
            ? false
            : fields[128] as bool,
        preferNextUpPrepending: fields[129] == null
            ? true
            : fields[129] as bool,
        rememberLastUsedPlaybackActionRowPage: fields[130] == null
            ? true
            : fields[130] as bool,
        lastUsedPlaybackActionRowPage: fields[131] == null
            ? PlaybackActionRowPage.newQueue
            : fields[131] as PlaybackActionRowPage,
        lastUsedPlaybackActionRowPageForQueueMenu: fields[139] == null
            ? PlaybackActionRowPage.moveWithinQueue
            : fields[139] as PlaybackActionRowPage,
        accentColor: fields[132] == null
            ? DefaultSettings.accentColor
            : fields[132] as Color?,
        themeMode: fields[133] == null
            ? ThemeMode.system
            : fields[133] as ThemeMode,
        locale: fields[134] == null
            ? DefaultSettings.locale
            : fields[134] as Locale?,
        hasCompletedThemeModeLocaleMigration: fields[135] == null
            ? false
            : fields[135] as bool,
        systemAccentColor: fields[136] == null
            ? DefaultSettings.accentColor
            : fields[136] as Color?,
        useSystemAccentColor: fields[137] == null ? false : fields[137] as bool,
        useMonochromeIcon: fields[138] == null ? false : fields[138] as bool,
        duckOnAudioInterruption: fields[142] == null
            ? true
            : fields[142] as bool,
        forceAudioOffloadingOnAndroid: fields[143] == null
            ? false
            : fields[143] as bool,
        previousTracksPersistenceMode: fields[145] == null
            ? PreviousTracksPersistenceMode.persistent
            : fields[145] as PreviousTracksPersistenceMode,
      )
      ..disableGesture = fields[19] == null ? false : fields[19] as bool
      ..showFastScroller = fields[25] == null ? true : fields[25] as bool
      ..defaultDownloadLocation = fields[58] as String?
      ..lastUsedDownloadLocationId = fields[85] as String?
      ..sleepTimer = fields[116] as SleepTimer?
      ..autoExpandPlayerScreen = fields[125] == null
          ? false
          : fields[125] as bool
      ..radioEnabled = fields[140] == null ? false : fields[140] as bool
      ..radioMode = fields[141] == null
          ? RadioMode.similar
          : fields[141] as RadioMode;
  }

  @override
  void write(BinaryWriter writer, FinampSettings obj) {
    writer
      ..writeByte(139)
      ..writeByte(0)
      ..write(obj.isOffline)
      ..writeByte(1)
      ..write(obj.shouldTranscode)
      ..writeByte(2)
      ..write(obj.transcodeBitrate)
      ..writeByte(3)
      ..write(obj.downloadLocations)
      ..writeByte(4)
      ..write(obj.androidStopForegroundOnPause)
      ..writeByte(5)
      ..write(obj.showTabs)
      ..writeByte(6)
      ..write(obj.onlyShowFavorites)
      ..writeByte(7)
      ..write(obj.sortBy)
      ..writeByte(8)
      ..write(obj.sortOrder)
      ..writeByte(9)
      ..write(obj.trackShuffleItemCount)
      ..writeByte(10)
      ..write(obj.contentViewType)
      ..writeByte(11)
      ..write(obj.contentGridViewCrossAxisCountPortrait)
      ..writeByte(12)
      ..write(obj.contentGridViewCrossAxisCountLandscape)
      ..writeByte(13)
      ..write(obj.showTextOnGridView)
      ..writeByte(15)
      ..write(obj.downloadLocationsMap)
      ..writeByte(16)
      ..write(obj.useCoverAsBackground)
      ..writeByte(18)
      ..write(obj.bufferDurationSeconds)
      ..writeByte(19)
      ..write(obj.disableGesture)
      ..writeByte(20)
      ..write(obj.tabSortBy)
      ..writeByte(21)
      ..write(obj.tabSortOrder)
      ..writeByte(22)
      ..write(obj.tabOrder)
      ..writeByte(25)
      ..write(obj.showFastScroller)
      ..writeByte(27)
      ..write(obj.loopMode)
      ..writeByte(28)
      ..write(obj.autoloadLastQueueOnStartup)
      ..writeByte(29)
      ..write(obj.volumeNormalizationActive)
      ..writeByte(30)
      ..write(obj.volumeNormalizationIOSBaseGain)
      ..writeByte(33)
      ..write(obj.volumeNormalizationMode)
      ..writeByte(34)
      ..write(obj.hasCompletedDownloadsServiceMigration)
      ..writeByte(35)
      ..write(obj.requireWifiForDownloads)
      ..writeByte(36)
      ..write(obj.onlyShowFullyDownloaded)
      ..writeByte(37)
      ..write(obj.showDownloadsWithUnknownLibrary)
      ..writeByte(38)
      ..write(obj.maxConcurrentDownloads)
      ..writeByte(39)
      ..write(obj.downloadWorkers)
      ..writeByte(40)
      ..write(obj.resyncOnStartup)
      ..writeByte(41)
      ..write(obj.preferQuickSyncs)
      ..writeByte(42)
      ..write(obj.hasCompletedIsarUserMigration)
      ..writeByte(43)
      ..write(obj.downloadTranscodingCodec)
      ..writeByte(44)
      ..write(obj.shouldTranscodeDownloads)
      ..writeByte(45)
      ..write(obj.downloadTranscodeBitrate)
      ..writeByte(46)
      ..write(obj.shouldRedownloadTranscodes)
      ..writeByte(47)
      ..write(obj.enableVibration)
      ..writeByte(48)
      ..write(obj.playerScreenCoverMinimumPadding)
      ..writeByte(49)
      ..write(obj.prioritizeCoverFactor)
      ..writeByte(50)
      ..write(obj.suppressPlayerPadding)
      ..writeByte(51)
      ..write(obj.hidePlayerBottomActions)
      ..writeByte(52)
      ..write(obj.reportQueueToServer)
      ..writeByte(53)
      ..write(obj.periodicPlaybackSessionUpdateFrequencySeconds)
      ..writeByte(54)
      ..write(obj.showArtistsTracksSection)
      ..writeByte(55)
      ..write(obj.showArtistChipImage)
      ..writeByte(56)
      ..write(obj.playbackSpeed)
      ..writeByte(57)
      ..write(obj.playbackSpeedVisibility)
      ..writeByte(58)
      ..write(obj.defaultDownloadLocation)
      ..writeByte(59)
      ..write(obj.useFixedSizeGridTiles)
      ..writeByte(60)
      ..write(obj.fixedGridTileSize)
      ..writeByte(61)
      ..write(obj.allowSplitScreen)
      ..writeByte(62)
      ..write(obj.splitScreenPlayerWidth)
      ..writeByte(63)
      ..write(obj.trackOfflineFavorites)
      ..writeByte(64)
      ..write(obj.showProgressOnNowPlayingBar)
      ..writeByte(65)
      ..write(obj.startInstantMixForIndividualTracks)
      ..writeByte(66)
      ..write(obj.showLyricsTimestamps)
      ..writeByte(67)
      ..write(obj.lyricsAlignment)
      ..writeByte(68)
      ..write(obj.showStopButtonOnMediaNotification)
      ..writeByte(69)
      ..write(obj.showSeekControlsOnMediaNotification)
      ..writeByte(70)
      ..write(obj.lyricsFontSize)
      ..writeByte(71)
      ..write(obj.showLyricsScreenAlbumPrelude)
      ..writeByte(72)
      ..write(obj.keepScreenOnOption)
      ..writeByte(73)
      ..write(obj.keepScreenOnWhilePluggedIn)
      ..writeByte(74)
      ..write(obj.hasDownloadedPlaylistInfo)
      ..writeByte(75)
      ..write(obj.transcodingStreamingFormat)
      ..writeByte(76)
      ..write(obj.featureChipsConfiguration)
      ..writeByte(77)
      ..write(obj.showCoversOnAlbumScreen)
      ..writeByte(78)
      ..write(obj.bufferDisableSizeConstraints)
      ..writeByte(79)
      ..write(obj.bufferSizeMegabytes)
      ..writeByte(80)
      ..write(obj.downloadSizeWarningCutoff)
      ..writeByte(81)
      ..write(obj.allowDeleteFromServer)
      ..writeByte(82)
      ..write(obj.oneLineMarqueeTextButton)
      ..writeByte(83)
      ..write(obj.showAlbumReleaseDateOnPlayerScreen)
      ..writeByte(84)
      ..write(obj.releaseDateFormat)
      ..writeByte(85)
      ..write(obj.lastUsedDownloadLocationId)
      ..writeByte(86)
      ..write(obj.audioFadeOutDuration)
      ..writeByte(87)
      ..write(obj.audioFadeInDuration)
      ..writeByte(88)
      ..write(obj.autoOffline)
      ..writeByte(89)
      ..write(obj.autoOfflineListenerActive)
      ..writeByte(90)
      ..write(obj.itemSwipeActionLeftToRight)
      ..writeByte(91)
      ..write(obj.itemSwipeActionRightToLeft)
      ..writeByte(92)
      ..write(obj.defaultArtistType)
      ..writeByte(93)
      ..write(obj.currentVolume)
      ..writeByte(94)
      ..write(obj.playOnStaleDelay)
      ..writeByte(95)
      ..write(obj.playOnReconnectionDelay)
      ..writeByte(96)
      ..write(obj.enablePlayon)
      ..writeByte(97)
      ..write(obj.autoReloadQueue)
      ..writeByte(98)
      ..write(obj.showShuffleButtonOnMediaNotification)
      ..writeByte(99)
      ..write(obj.showFavoriteButtonOnMediaNotification)
      ..writeByte(100)
      ..write(obj.screenSize)
      ..writeByte(101)
      ..write(obj.genreCuratedItemSelectionTypeTracks)
      ..writeByte(102)
      ..write(obj.genreCuratedItemSelectionTypeAlbums)
      ..writeByte(103)
      ..write(obj.genreCuratedItemSelectionTypeArtists)
      ..writeByte(104)
      ..write(obj.genreItemSectionsOrder)
      ..writeByte(105)
      ..write(obj.genreFilterArtistScreens)
      ..writeByte(106)
      ..write(obj.genreListsInheritSorting)
      ..writeByte(107)
      ..write(obj.genreItemSectionFilterChipOrder)
      ..writeByte(108)
      ..write(obj.applyFilterOnGenreChipTap)
      ..writeByte(109)
      ..write(obj.artistCuratedItemSelectionType)
      ..writeByte(110)
      ..write(obj.artistItemSectionFilterChipOrder)
      ..writeByte(111)
      ..write(obj.artistItemSectionsOrder)
      ..writeByte(112)
      ..write(obj.autoSwitchItemCurationType)
      ..writeByte(113)
      ..write(obj.playlistTracksSortBy)
      ..writeByte(114)
      ..write(obj.playlistTracksSortOrder)
      ..writeByte(115)
      ..write(obj.genreFilterPlaylists)
      ..writeByte(116)
      ..write(obj.sleepTimer)
      ..writeByte(117)
      ..write(obj.clearQueueOnStopEvent)
      ..writeByte(118)
      ..write(obj.playbackPitch)
      ..writeByte(119)
      ..write(obj.syncPlaybackSpeedAndPitch)
      ..writeByte(120)
      ..write(obj.useHighContrastColors)
      ..writeByte(121)
      ..write(obj.hasCompletedDownloadsFileOwnerMigration)
      ..writeByte(122)
      ..write(obj.tileAdditionalInfoType)
      ..writeByte(123)
      ..write(obj.rpcEnabled)
      ..writeByte(124)
      ..write(obj.rpcIcon)
      ..writeByte(125)
      ..write(obj.autoExpandPlayerScreen)
      ..writeByte(126)
      ..write(obj.preferAddingToFavoritesOverPlaylists)
      ..writeByte(127)
      ..write(obj.previousTracksExpaned)
      ..writeByte(128)
      ..write(obj.autoplayRestoredQueue)
      ..writeByte(129)
      ..write(obj.preferNextUpPrepending)
      ..writeByte(130)
      ..write(obj.rememberLastUsedPlaybackActionRowPage)
      ..writeByte(131)
      ..write(obj.lastUsedPlaybackActionRowPage)
      ..writeByte(132)
      ..write(obj.accentColor)
      ..writeByte(133)
      ..write(obj.themeMode)
      ..writeByte(134)
      ..write(obj.locale)
      ..writeByte(135)
      ..write(obj.hasCompletedThemeModeLocaleMigration)
      ..writeByte(136)
      ..write(obj.systemAccentColor)
      ..writeByte(137)
      ..write(obj.useSystemAccentColor)
      ..writeByte(138)
      ..write(obj.useMonochromeIcon)
      ..writeByte(139)
      ..write(obj.lastUsedPlaybackActionRowPageForQueueMenu)
      ..writeByte(140)
      ..write(obj.radioEnabled)
      ..writeByte(141)
      ..write(obj.radioMode)
      ..writeByte(142)
      ..write(obj.duckOnAudioInterruption)
      ..writeByte(143)
      ..write(obj.forceAudioOffloadingOnAndroid)
      ..writeByte(144)
      ..write(obj.multichannelHandlingSetting)
      ..writeByte(145)
      ..write(obj.previousTracksPersistenceMode);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FinampSettingsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class DownloadLocationAdapter extends TypeAdapter<DownloadLocation> {
  @override
  final typeId = 31;

  @override
  DownloadLocation read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DownloadLocation(
      name: fields[0] as String,
      relativePath: fields[1] as String?,
      id: fields[4] == null ? '0' : fields[4] as String,
      legacyUseHumanReadableNames: fields[2] as bool?,
      legacyDeletable: fields[3] as bool?,
      baseDirectory: fields[5] == null
          ? DownloadLocationType.migrated
          : fields[5] as DownloadLocationType,
    );
  }

  @override
  void write(BinaryWriter writer, DownloadLocation obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.relativePath)
      ..writeByte(2)
      ..write(obj.legacyUseHumanReadableNames)
      ..writeByte(3)
      ..write(obj.legacyDeletable)
      ..writeByte(4)
      ..write(obj.id)
      ..writeByte(5)
      ..write(obj.baseDirectory);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DownloadLocationAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class DownloadedTrackAdapter extends TypeAdapter<DownloadedTrack> {
  @override
  final typeId = 3;

  @override
  DownloadedTrack read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DownloadedTrack(
      track: fields[0] as BaseItemDto,
      mediaSourceInfo: fields[1] as MediaSourceInfo,
      downloadId: fields[2] as String,
      requiredBy: (fields[3] as List).cast<String>(),
      path: fields[4] as String,
      useHumanReadableNames: fields[5] as bool,
      viewId: fields[6] as String,
      isPathRelative: fields[7] == null ? false : fields[7] as bool,
      downloadLocationId: fields[8] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, DownloadedTrack obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.track)
      ..writeByte(1)
      ..write(obj.mediaSourceInfo)
      ..writeByte(2)
      ..write(obj.downloadId)
      ..writeByte(3)
      ..write(obj.requiredBy)
      ..writeByte(4)
      ..write(obj.path)
      ..writeByte(5)
      ..write(obj.useHumanReadableNames)
      ..writeByte(6)
      ..write(obj.viewId)
      ..writeByte(7)
      ..write(obj.isPathRelative)
      ..writeByte(8)
      ..write(obj.downloadLocationId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DownloadedTrackAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class DownloadedParentAdapter extends TypeAdapter<DownloadedParent> {
  @override
  final typeId = 4;

  @override
  DownloadedParent read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DownloadedParent(
      item: fields[0] as BaseItemDto,
      downloadedChildren: (fields[1] as Map).cast<String, BaseItemDto>(),
      viewId: fields[2] as String,
    );
  }

  @override
  void write(BinaryWriter writer, DownloadedParent obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.item)
      ..writeByte(1)
      ..write(obj.downloadedChildren)
      ..writeByte(2)
      ..write(obj.viewId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DownloadedParentAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class DownloadedImageAdapter extends TypeAdapter<DownloadedImage> {
  @override
  final typeId = 40;

  @override
  DownloadedImage read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DownloadedImage(
      id: fields[0] as String,
      downloadId: fields[1] as String,
      path: fields[2] as String,
      requiredBy: (fields[3] as List).cast<String>(),
      downloadLocationId: fields[4] as String,
    );
  }

  @override
  void write(BinaryWriter writer, DownloadedImage obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.downloadId)
      ..writeByte(2)
      ..write(obj.path)
      ..writeByte(3)
      ..write(obj.requiredBy)
      ..writeByte(4)
      ..write(obj.downloadLocationId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DownloadedImageAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class OfflineListenAdapter extends TypeAdapter<OfflineListen> {
  @override
  final typeId = 43;

  @override
  OfflineListen read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return OfflineListen(
      timestamp: (fields[0] as num).toInt(),
      userId: fields[1] as String,
      itemId: fields[2] as String,
      name: fields[3] as String,
      artist: fields[4] as String?,
      album: fields[5] as String?,
      trackMbid: fields[6] as String?,
      deviceInfo: fields[7] as DeviceInfo?,
    );
  }

  @override
  void write(BinaryWriter writer, OfflineListen obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.timestamp)
      ..writeByte(1)
      ..write(obj.userId)
      ..writeByte(2)
      ..write(obj.itemId)
      ..writeByte(3)
      ..write(obj.name)
      ..writeByte(4)
      ..write(obj.artist)
      ..writeByte(5)
      ..write(obj.album)
      ..writeByte(6)
      ..write(obj.trackMbid)
      ..writeByte(7)
      ..write(obj.deviceInfo);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OfflineListenAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class QueueItemSourceAdapter extends TypeAdapter<QueueItemSource> {
  @override
  final typeId = 54;

  @override
  QueueItemSource read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return QueueItemSource(
      type: fields[0] as QueueItemSourceType,
      name: fields[1] as QueueItemSourceName,
      id: fields[2] as BaseItemId,
      contextNormalizationGain: (fields[4] as num?)?.toDouble(),
    );
  }

  @override
  void write(BinaryWriter writer, QueueItemSource obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.type)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.id)
      ..writeByte(4)
      ..write(obj.contextNormalizationGain);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QueueItemSourceAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class QueueItemSourceNameAdapter extends TypeAdapter<QueueItemSourceName> {
  @override
  final typeId = 56;

  @override
  QueueItemSourceName read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return QueueItemSourceName(
      type: fields[0] as QueueItemSourceNameType,
      pretranslatedName: fields[1] as String?,
      localizationParameter: fields[2] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, QueueItemSourceName obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.type)
      ..writeByte(1)
      ..write(obj.pretranslatedName)
      ..writeByte(2)
      ..write(obj.localizationParameter);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QueueItemSourceNameAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class FinampQueueItemAdapter extends TypeAdapter<FinampQueueItem> {
  @override
  final typeId = 57;

  @override
  FinampQueueItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FinampQueueItem(
      item: fields[1] as MediaItem,
      source: fields[2] as QueueItemSource,
      type: fields[3] == null
          ? QueueItemQueueType.queue
          : fields[3] as QueueItemQueueType,
    )..id = fields[0] as String;
  }

  @override
  void write(BinaryWriter writer, FinampQueueItem obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.item)
      ..writeByte(2)
      ..write(obj.source)
      ..writeByte(3)
      ..write(obj.type);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FinampQueueItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class FinampQueueOrderAdapter extends TypeAdapter<FinampQueueOrder> {
  @override
  final typeId = 58;

  @override
  FinampQueueOrder read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FinampQueueOrder(
      items: (fields[0] as List).cast<FinampQueueItem>(),
      originalSource: fields[1] as QueueItemSource,
      linearOrder: (fields[2] as List).cast<int>(),
      shuffledOrder: (fields[3] as List).cast<int>(),
      sourceLibrary: fields[5] as BaseItemDto?,
    )..id = fields[4] as String;
  }

  @override
  void write(BinaryWriter writer, FinampQueueOrder obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.items)
      ..writeByte(1)
      ..write(obj.originalSource)
      ..writeByte(2)
      ..write(obj.linearOrder)
      ..writeByte(3)
      ..write(obj.shuffledOrder)
      ..writeByte(4)
      ..write(obj.id)
      ..writeByte(5)
      ..write(obj.sourceLibrary);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FinampQueueOrderAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class FinampQueueInfoAdapter extends TypeAdapter<FinampQueueInfo> {
  @override
  final typeId = 59;

  @override
  FinampQueueInfo read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FinampQueueInfo(
      id: fields[6] as String,
      previousTracks: (fields[0] as List).cast<FinampQueueItem>(),
      currentTrack: fields[1] as FinampQueueItem?,
      nextUp: (fields[2] as List).cast<FinampQueueItem>(),
      queue: (fields[3] as List).cast<FinampQueueItem>(),
      source: fields[4] as QueueItemSource,
      saveState: fields[5] as SavedQueueState,
      sourceLibrary: fields[7] as BaseItemDto?,
    );
  }

  @override
  void write(BinaryWriter writer, FinampQueueInfo obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.previousTracks)
      ..writeByte(1)
      ..write(obj.currentTrack)
      ..writeByte(2)
      ..write(obj.nextUp)
      ..writeByte(3)
      ..write(obj.queue)
      ..writeByte(4)
      ..write(obj.source)
      ..writeByte(5)
      ..write(obj.saveState)
      ..writeByte(6)
      ..write(obj.id)
      ..writeByte(7)
      ..write(obj.sourceLibrary);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FinampQueueInfoAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class FinampHistoryItemAdapter extends TypeAdapter<FinampHistoryItem> {
  @override
  final typeId = 60;

  @override
  FinampHistoryItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FinampHistoryItem(
      item: fields[0] as FinampQueueItem,
      startTime: fields[1] as DateTime,
      endTime: fields[2] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, FinampHistoryItem obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.item)
      ..writeByte(1)
      ..write(obj.startTime)
      ..writeByte(2)
      ..write(obj.endTime);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FinampHistoryItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class MediaItemIdAdapter extends TypeAdapter<MediaItemId> {
  @override
  final typeId = 69;

  @override
  MediaItemId read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MediaItemId(
      contentType: fields[0] as TabContentType,
      parentType: fields[1] as MediaItemParentType,
      itemId: fields[2] as BaseItemId?,
      parentId: fields[3] as BaseItemId?,
    );
  }

  @override
  void write(BinaryWriter writer, MediaItemId obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.contentType)
      ..writeByte(1)
      ..write(obj.parentType)
      ..writeByte(2)
      ..write(obj.itemId)
      ..writeByte(3)
      ..write(obj.parentId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MediaItemIdAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class FinampFeatureChipsConfigurationAdapter
    extends TypeAdapter<FinampFeatureChipsConfiguration> {
  @override
  final typeId = 75;

  @override
  FinampFeatureChipsConfiguration read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FinampFeatureChipsConfiguration(
      enabled: fields[0] as bool,
      features: (fields[1] as List).cast<FinampFeatureChipType>(),
    );
  }

  @override
  void write(BinaryWriter writer, FinampFeatureChipsConfiguration obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.enabled)
      ..writeByte(1)
      ..write(obj.features);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FinampFeatureChipsConfigurationAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class DeviceInfoAdapter extends TypeAdapter<DeviceInfo> {
  @override
  final typeId = 76;

  @override
  DeviceInfo read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DeviceInfo(name: fields[0] as String, id: fields[1] as String?);
  }

  @override
  void write(BinaryWriter writer, DeviceInfo obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.id);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeviceInfoAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ScreenSizeAdapter extends TypeAdapter<ScreenSize> {
  @override
  final typeId = 94;

  @override
  ScreenSize read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ScreenSize(
      (fields[1] as num).toDouble(),
      (fields[2] as num).toDouble(),
      (fields[3] as num).toDouble(),
      (fields[4] as num).toDouble(),
    );
  }

  @override
  void write(BinaryWriter writer, ScreenSize obj) {
    writer
      ..writeByte(4)
      ..writeByte(1)
      ..write(obj.sizeX)
      ..writeByte(2)
      ..write(obj.sizeY)
      ..writeByte(3)
      ..write(obj.locationX)
      ..writeByte(4)
      ..write(obj.locationY);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScreenSizeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SleepTimerAdapter extends TypeAdapter<SleepTimer> {
  @override
  final typeId = 98;

  @override
  SleepTimer read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SleepTimer(
      fields[1] == null ? 0 : (fields[1] as num).toInt(),
      fields[4] == null ? 0 : (fields[4] as num).toInt(),
    );
  }

  @override
  void write(BinaryWriter writer, SleepTimer obj) {
    writer
      ..writeByte(2)
      ..writeByte(1)
      ..write(obj.secondsLength)
      ..writeByte(4)
      ..write(obj.tracksLength);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SleepTimerAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class RawThemeResultAdapter extends TypeAdapter<RawThemeResult> {
  @override
  final typeId = 108;

  @override
  RawThemeResult read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RawThemeResult(
      (fields[0] as num).toInt(),
      (fields[1] as num).toInt(),
    );
  }

  @override
  void write(BinaryWriter writer, RawThemeResult obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj._highlightInt)
      ..writeByte(1)
      ..write(obj._backgroundInt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RawThemeResultAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class FinampStorableQueueInfoAdapter
    extends TypeAdapter<FinampStorableQueueInfo> {
  @override
  final typeId = 110;

  @override
  FinampStorableQueueInfo read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FinampStorableQueueInfo(
      currentTrackSeek: (fields[2] as num?)?.toInt(),
      creation: (fields[5] as num).toInt(),
      sourceList: (fields[6] as List).cast<QueueItemSource>(),
      packedPreviousTracks: fields[0] as Uint8List,
      packedCurrentTrack: fields[1] as Uint8List,
      packedNextUp: fields[3] as Uint8List,
      packedQueue: fields[4] as Uint8List,
      sourceIndex: (fields[7] as num).toInt(),
      trackSourceIndexes: fields[8] as Uint8List,
      packedShuffleOrder: fields[9] as Uint8List?,
    );
  }

  @override
  void write(BinaryWriter writer, FinampStorableQueueInfo obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.packedPreviousTracks)
      ..writeByte(1)
      ..write(obj.packedCurrentTrack)
      ..writeByte(2)
      ..write(obj.currentTrackSeek)
      ..writeByte(3)
      ..write(obj.packedNextUp)
      ..writeByte(4)
      ..write(obj.packedQueue)
      ..writeByte(5)
      ..write(obj.creation)
      ..writeByte(6)
      ..write(obj.sourceList)
      ..writeByte(7)
      ..write(obj.sourceIndex)
      ..writeByte(8)
      ..write(obj.trackSourceIndexes)
      ..writeByte(9)
      ..write(obj.packedShuffleOrder);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FinampStorableQueueInfoAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class TabContentTypeAdapter extends TypeAdapter<TabContentType> {
  @override
  final typeId = 36;

  @override
  TabContentType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return TabContentType.albums;
      case 1:
        return TabContentType.artists;
      case 2:
        return TabContentType.playlists;
      case 3:
        return TabContentType.genres;
      case 4:
        return TabContentType.tracks;
      default:
        return TabContentType.albums;
    }
  }

  @override
  void write(BinaryWriter writer, TabContentType obj) {
    switch (obj) {
      case TabContentType.albums:
        writer.writeByte(0);
      case TabContentType.artists:
        writer.writeByte(1);
      case TabContentType.playlists:
        writer.writeByte(2);
      case TabContentType.genres:
        writer.writeByte(3);
      case TabContentType.tracks:
        writer.writeByte(4);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TabContentTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ContentViewTypeAdapter extends TypeAdapter<ContentViewType> {
  @override
  final typeId = 39;

  @override
  ContentViewType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return ContentViewType.list;
      case 1:
        return ContentViewType.grid;
      default:
        return ContentViewType.list;
    }
  }

  @override
  void write(BinaryWriter writer, ContentViewType obj) {
    switch (obj) {
      case ContentViewType.list:
        writer.writeByte(0);
      case ContentViewType.grid:
        writer.writeByte(1);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ContentViewTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class FinampPlaybackOrderAdapter extends TypeAdapter<FinampPlaybackOrder> {
  @override
  final typeId = 50;

  @override
  FinampPlaybackOrder read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return FinampPlaybackOrder.shuffled;
      case 1:
        return FinampPlaybackOrder.linear;
      default:
        return FinampPlaybackOrder.shuffled;
    }
  }

  @override
  void write(BinaryWriter writer, FinampPlaybackOrder obj) {
    switch (obj) {
      case FinampPlaybackOrder.shuffled:
        writer.writeByte(0);
      case FinampPlaybackOrder.linear:
        writer.writeByte(1);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FinampPlaybackOrderAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class FinampLoopModeAdapter extends TypeAdapter<FinampLoopMode> {
  @override
  final typeId = 51;

  @override
  FinampLoopMode read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return FinampLoopMode.none;
      case 1:
        return FinampLoopMode.one;
      case 2:
        return FinampLoopMode.all;
      default:
        return FinampLoopMode.none;
    }
  }

  @override
  void write(BinaryWriter writer, FinampLoopMode obj) {
    switch (obj) {
      case FinampLoopMode.none:
        writer.writeByte(0);
      case FinampLoopMode.one:
        writer.writeByte(1);
      case FinampLoopMode.all:
        writer.writeByte(2);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FinampLoopModeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class QueueItemSourceTypeAdapter extends TypeAdapter<QueueItemSourceType> {
  @override
  final typeId = 52;

  @override
  QueueItemSourceType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return QueueItemSourceType.album;
      case 1:
        return QueueItemSourceType.playlist;
      case 2:
        return QueueItemSourceType.trackMix;
      case 3:
        return QueueItemSourceType.artistMix;
      case 4:
        return QueueItemSourceType.albumMix;
      case 5:
        return QueueItemSourceType.favorites;
      case 6:
        return QueueItemSourceType.allTracks;
      case 7:
        return QueueItemSourceType.filteredList;
      case 8:
        return QueueItemSourceType.genre;
      case 9:
        return QueueItemSourceType.artist;
      case 10:
        return QueueItemSourceType.nextUp;
      case 11:
        return QueueItemSourceType.nextUpAlbum;
      case 12:
        return QueueItemSourceType.nextUpPlaylist;
      case 13:
        return QueueItemSourceType.nextUpArtist;
      case 14:
        return QueueItemSourceType.nextUpGenre;
      case 15:
        return QueueItemSourceType.formerNextUp;
      case 16:
        return QueueItemSourceType.downloads;
      case 17:
        return QueueItemSourceType.queue;
      case 18:
        return QueueItemSourceType.unknown;
      case 19:
        return QueueItemSourceType.genreMix;
      case 20:
        return QueueItemSourceType.track;
      case 21:
        return QueueItemSourceType.remoteClient;
      case 22:
        return QueueItemSourceType.radio;
      default:
        return QueueItemSourceType.album;
    }
  }

  @override
  void write(BinaryWriter writer, QueueItemSourceType obj) {
    switch (obj) {
      case QueueItemSourceType.album:
        writer.writeByte(0);
      case QueueItemSourceType.playlist:
        writer.writeByte(1);
      case QueueItemSourceType.trackMix:
        writer.writeByte(2);
      case QueueItemSourceType.artistMix:
        writer.writeByte(3);
      case QueueItemSourceType.albumMix:
        writer.writeByte(4);
      case QueueItemSourceType.favorites:
        writer.writeByte(5);
      case QueueItemSourceType.allTracks:
        writer.writeByte(6);
      case QueueItemSourceType.filteredList:
        writer.writeByte(7);
      case QueueItemSourceType.genre:
        writer.writeByte(8);
      case QueueItemSourceType.artist:
        writer.writeByte(9);
      case QueueItemSourceType.nextUp:
        writer.writeByte(10);
      case QueueItemSourceType.nextUpAlbum:
        writer.writeByte(11);
      case QueueItemSourceType.nextUpPlaylist:
        writer.writeByte(12);
      case QueueItemSourceType.nextUpArtist:
        writer.writeByte(13);
      case QueueItemSourceType.nextUpGenre:
        writer.writeByte(14);
      case QueueItemSourceType.formerNextUp:
        writer.writeByte(15);
      case QueueItemSourceType.downloads:
        writer.writeByte(16);
      case QueueItemSourceType.queue:
        writer.writeByte(17);
      case QueueItemSourceType.unknown:
        writer.writeByte(18);
      case QueueItemSourceType.genreMix:
        writer.writeByte(19);
      case QueueItemSourceType.track:
        writer.writeByte(20);
      case QueueItemSourceType.remoteClient:
        writer.writeByte(21);
      case QueueItemSourceType.radio:
        writer.writeByte(22);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QueueItemSourceTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class QueueItemQueueTypeAdapter extends TypeAdapter<QueueItemQueueType> {
  @override
  final typeId = 53;

  @override
  QueueItemQueueType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return QueueItemQueueType.previousTracks;
      case 1:
        return QueueItemQueueType.currentTrack;
      case 2:
        return QueueItemQueueType.nextUp;
      case 3:
        return QueueItemQueueType.queue;
      default:
        return QueueItemQueueType.previousTracks;
    }
  }

  @override
  void write(BinaryWriter writer, QueueItemQueueType obj) {
    switch (obj) {
      case QueueItemQueueType.previousTracks:
        writer.writeByte(0);
      case QueueItemQueueType.currentTrack:
        writer.writeByte(1);
      case QueueItemQueueType.nextUp:
        writer.writeByte(2);
      case QueueItemQueueType.queue:
        writer.writeByte(3);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QueueItemQueueTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class QueueItemSourceNameTypeAdapter
    extends TypeAdapter<QueueItemSourceNameType> {
  @override
  final typeId = 55;

  @override
  QueueItemSourceNameType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return QueueItemSourceNameType.preTranslated;
      case 1:
        return QueueItemSourceNameType.yourLikes;
      case 2:
        return QueueItemSourceNameType.shuffleAll;
      case 3:
        return QueueItemSourceNameType.mix;
      case 4:
        return QueueItemSourceNameType.instantMix;
      case 5:
        return QueueItemSourceNameType.nextUp;
      case 6:
        return QueueItemSourceNameType.tracksFormerNextUp;
      case 7:
        return QueueItemSourceNameType.savedQueue;
      case 8:
        return QueueItemSourceNameType.queue;
      case 9:
        return QueueItemSourceNameType.remoteClient;
      case 10:
        return QueueItemSourceNameType.radio;
      default:
        return QueueItemSourceNameType.preTranslated;
    }
  }

  @override
  void write(BinaryWriter writer, QueueItemSourceNameType obj) {
    switch (obj) {
      case QueueItemSourceNameType.preTranslated:
        writer.writeByte(0);
      case QueueItemSourceNameType.yourLikes:
        writer.writeByte(1);
      case QueueItemSourceNameType.shuffleAll:
        writer.writeByte(2);
      case QueueItemSourceNameType.mix:
        writer.writeByte(3);
      case QueueItemSourceNameType.instantMix:
        writer.writeByte(4);
      case QueueItemSourceNameType.nextUp:
        writer.writeByte(5);
      case QueueItemSourceNameType.tracksFormerNextUp:
        writer.writeByte(6);
      case QueueItemSourceNameType.savedQueue:
        writer.writeByte(7);
      case QueueItemSourceNameType.queue:
        writer.writeByte(8);
      case QueueItemSourceNameType.remoteClient:
        writer.writeByte(9);
      case QueueItemSourceNameType.radio:
        writer.writeByte(10);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QueueItemSourceNameTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SavedQueueStateAdapter extends TypeAdapter<SavedQueueState> {
  @override
  final typeId = 62;

  @override
  SavedQueueState read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return SavedQueueState.preInit;
      case 1:
        return SavedQueueState.init;
      case 2:
        return SavedQueueState.loading;
      case 3:
        return SavedQueueState.saving;
      case 4:
        return SavedQueueState.failed;
      case 5:
        return SavedQueueState.pendingSave;
      default:
        return SavedQueueState.preInit;
    }
  }

  @override
  void write(BinaryWriter writer, SavedQueueState obj) {
    switch (obj) {
      case SavedQueueState.preInit:
        writer.writeByte(0);
      case SavedQueueState.init:
        writer.writeByte(1);
      case SavedQueueState.loading:
        writer.writeByte(2);
      case SavedQueueState.saving:
        writer.writeByte(3);
      case SavedQueueState.failed:
        writer.writeByte(4);
      case SavedQueueState.pendingSave:
        writer.writeByte(5);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SavedQueueStateAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class VolumeNormalizationModeAdapter
    extends TypeAdapter<VolumeNormalizationMode> {
  @override
  final typeId = 63;

  @override
  VolumeNormalizationMode read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return VolumeNormalizationMode.hybrid;
      case 1:
        return VolumeNormalizationMode.trackBased;
      case 2:
        return VolumeNormalizationMode.albumOnly;
      case 3:
        return VolumeNormalizationMode.albumBased;
      default:
        return VolumeNormalizationMode.hybrid;
    }
  }

  @override
  void write(BinaryWriter writer, VolumeNormalizationMode obj) {
    switch (obj) {
      case VolumeNormalizationMode.hybrid:
        writer.writeByte(0);
      case VolumeNormalizationMode.trackBased:
        writer.writeByte(1);
      case VolumeNormalizationMode.albumOnly:
        writer.writeByte(2);
      case VolumeNormalizationMode.albumBased:
        writer.writeByte(3);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VolumeNormalizationModeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class DownloadLocationTypeAdapter extends TypeAdapter<DownloadLocationType> {
  @override
  final typeId = 64;

  @override
  DownloadLocationType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return DownloadLocationType.internalDocuments;
      case 1:
        return DownloadLocationType.internalSupport;
      case 2:
        return DownloadLocationType.external;
      case 3:
        return DownloadLocationType.custom;
      case 4:
        return DownloadLocationType.none;
      case 5:
        return DownloadLocationType.migrated;
      case 6:
        return DownloadLocationType.cache;
      default:
        return DownloadLocationType.internalDocuments;
    }
  }

  @override
  void write(BinaryWriter writer, DownloadLocationType obj) {
    switch (obj) {
      case DownloadLocationType.internalDocuments:
        writer.writeByte(0);
      case DownloadLocationType.internalSupport:
        writer.writeByte(1);
      case DownloadLocationType.external:
        writer.writeByte(2);
      case DownloadLocationType.custom:
        writer.writeByte(3);
      case DownloadLocationType.none:
        writer.writeByte(4);
      case DownloadLocationType.migrated:
        writer.writeByte(5);
      case DownloadLocationType.cache:
        writer.writeByte(6);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DownloadLocationTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class FinampTranscodingCodecAdapter
    extends TypeAdapter<FinampTranscodingCodec> {
  @override
  final typeId = 65;

  @override
  FinampTranscodingCodec read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return FinampTranscodingCodec.aac;
      case 1:
        return FinampTranscodingCodec.mp3;
      case 2:
        return FinampTranscodingCodec.opus;
      case 3:
        return FinampTranscodingCodec.original;
      default:
        return FinampTranscodingCodec.aac;
    }
  }

  @override
  void write(BinaryWriter writer, FinampTranscodingCodec obj) {
    switch (obj) {
      case FinampTranscodingCodec.aac:
        writer.writeByte(0);
      case FinampTranscodingCodec.mp3:
        writer.writeByte(1);
      case FinampTranscodingCodec.opus:
        writer.writeByte(2);
      case FinampTranscodingCodec.original:
        writer.writeByte(3);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FinampTranscodingCodecAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class TranscodeDownloadsSettingAdapter
    extends TypeAdapter<TranscodeDownloadsSetting> {
  @override
  final typeId = 66;

  @override
  TranscodeDownloadsSetting read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return TranscodeDownloadsSetting.always;
      case 1:
        return TranscodeDownloadsSetting.never;
      case 2:
        return TranscodeDownloadsSetting.ask;
      default:
        return TranscodeDownloadsSetting.always;
    }
  }

  @override
  void write(BinaryWriter writer, TranscodeDownloadsSetting obj) {
    switch (obj) {
      case TranscodeDownloadsSetting.always:
        writer.writeByte(0);
      case TranscodeDownloadsSetting.never:
        writer.writeByte(1);
      case TranscodeDownloadsSetting.ask:
        writer.writeByte(2);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TranscodeDownloadsSettingAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class PlaybackSpeedVisibilityAdapter
    extends TypeAdapter<PlaybackSpeedVisibility> {
  @override
  final typeId = 67;

  @override
  PlaybackSpeedVisibility read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return PlaybackSpeedVisibility.automatic;
      case 1:
        return PlaybackSpeedVisibility.visible;
      case 2:
        return PlaybackSpeedVisibility.hidden;
      default:
        return PlaybackSpeedVisibility.automatic;
    }
  }

  @override
  void write(BinaryWriter writer, PlaybackSpeedVisibility obj) {
    switch (obj) {
      case PlaybackSpeedVisibility.automatic:
        writer.writeByte(0);
      case PlaybackSpeedVisibility.visible:
        writer.writeByte(1);
      case PlaybackSpeedVisibility.hidden:
        writer.writeByte(2);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlaybackSpeedVisibilityAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class MediaItemParentTypeAdapter extends TypeAdapter<MediaItemParentType> {
  @override
  final typeId = 68;

  @override
  MediaItemParentType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return MediaItemParentType.collection;
      case 1:
        return MediaItemParentType.rootCollection;
      case 2:
        return MediaItemParentType.instantMix;
      default:
        return MediaItemParentType.collection;
    }
  }

  @override
  void write(BinaryWriter writer, MediaItemParentType obj) {
    switch (obj) {
      case MediaItemParentType.collection:
        writer.writeByte(0);
      case MediaItemParentType.rootCollection:
        writer.writeByte(1);
      case MediaItemParentType.instantMix:
        writer.writeByte(2);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MediaItemParentTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class LyricsAlignmentAdapter extends TypeAdapter<LyricsAlignment> {
  @override
  final typeId = 70;

  @override
  LyricsAlignment read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return LyricsAlignment.start;
      case 1:
        return LyricsAlignment.center;
      case 2:
        return LyricsAlignment.end;
      default:
        return LyricsAlignment.start;
    }
  }

  @override
  void write(BinaryWriter writer, LyricsAlignment obj) {
    switch (obj) {
      case LyricsAlignment.start:
        writer.writeByte(0);
      case LyricsAlignment.center:
        writer.writeByte(1);
      case LyricsAlignment.end:
        writer.writeByte(2);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LyricsAlignmentAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class LyricsFontSizeAdapter extends TypeAdapter<LyricsFontSize> {
  @override
  final typeId = 71;

  @override
  LyricsFontSize read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return LyricsFontSize.small;
      case 1:
        return LyricsFontSize.medium;
      case 2:
        return LyricsFontSize.large;
      default:
        return LyricsFontSize.small;
    }
  }

  @override
  void write(BinaryWriter writer, LyricsFontSize obj) {
    switch (obj) {
      case LyricsFontSize.small:
        writer.writeByte(0);
      case LyricsFontSize.medium:
        writer.writeByte(1);
      case LyricsFontSize.large:
        writer.writeByte(2);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LyricsFontSizeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class KeepScreenOnOptionAdapter extends TypeAdapter<KeepScreenOnOption> {
  @override
  final typeId = 72;

  @override
  KeepScreenOnOption read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return KeepScreenOnOption.disabled;
      case 1:
        return KeepScreenOnOption.alwaysOn;
      case 2:
        return KeepScreenOnOption.whilePlaying;
      case 3:
        return KeepScreenOnOption.whileLyrics;
      default:
        return KeepScreenOnOption.disabled;
    }
  }

  @override
  void write(BinaryWriter writer, KeepScreenOnOption obj) {
    switch (obj) {
      case KeepScreenOnOption.disabled:
        writer.writeByte(0);
      case KeepScreenOnOption.alwaysOn:
        writer.writeByte(1);
      case KeepScreenOnOption.whilePlaying:
        writer.writeByte(2);
      case KeepScreenOnOption.whileLyrics:
        writer.writeByte(3);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KeepScreenOnOptionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class FinampTranscodingStreamingFormatAdapter
    extends TypeAdapter<FinampTranscodingStreamingFormat> {
  @override
  final typeId = 73;

  @override
  FinampTranscodingStreamingFormat read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return FinampTranscodingStreamingFormat.aacMpegTS;
      case 1:
        return FinampTranscodingStreamingFormat.aacFragmentedMp4;
      case 2:
        return FinampTranscodingStreamingFormat.opusFragmentedMp4;
      case 3:
        return FinampTranscodingStreamingFormat.flacFragmentedMp4;
      case 4:
        return FinampTranscodingStreamingFormat.vorbisMpegTS;
      case 5:
        return FinampTranscodingStreamingFormat.vorbisFragmentedMp4;
      default:
        return FinampTranscodingStreamingFormat.aacMpegTS;
    }
  }

  @override
  void write(BinaryWriter writer, FinampTranscodingStreamingFormat obj) {
    switch (obj) {
      case FinampTranscodingStreamingFormat.aacMpegTS:
        writer.writeByte(0);
      case FinampTranscodingStreamingFormat.aacFragmentedMp4:
        writer.writeByte(1);
      case FinampTranscodingStreamingFormat.opusFragmentedMp4:
        writer.writeByte(2);
      case FinampTranscodingStreamingFormat.flacFragmentedMp4:
        writer.writeByte(3);
      case FinampTranscodingStreamingFormat.vorbisMpegTS:
        writer.writeByte(4);
      case FinampTranscodingStreamingFormat.vorbisFragmentedMp4:
        writer.writeByte(5);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FinampTranscodingStreamingFormatAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class FinampFeatureChipTypeAdapter extends TypeAdapter<FinampFeatureChipType> {
  @override
  final typeId = 74;

  @override
  FinampFeatureChipType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return FinampFeatureChipType.playCount;
      case 1:
        return FinampFeatureChipType.additionalPeople;
      case 2:
        return FinampFeatureChipType.playbackMode;
      case 3:
        return FinampFeatureChipType.codec;
      case 4:
        return FinampFeatureChipType.bitRate;
      case 5:
        return FinampFeatureChipType.bitDepth;
      case 6:
        return FinampFeatureChipType.size;
      case 7:
        return FinampFeatureChipType.normalizationGain;
      case 8:
        return FinampFeatureChipType.sampleRate;
      case 9:
        return FinampFeatureChipType.explicit;
      default:
        return FinampFeatureChipType.playCount;
    }
  }

  @override
  void write(BinaryWriter writer, FinampFeatureChipType obj) {
    switch (obj) {
      case FinampFeatureChipType.playCount:
        writer.writeByte(0);
      case FinampFeatureChipType.additionalPeople:
        writer.writeByte(1);
      case FinampFeatureChipType.playbackMode:
        writer.writeByte(2);
      case FinampFeatureChipType.codec:
        writer.writeByte(3);
      case FinampFeatureChipType.bitRate:
        writer.writeByte(4);
      case FinampFeatureChipType.bitDepth:
        writer.writeByte(5);
      case FinampFeatureChipType.size:
        writer.writeByte(6);
      case FinampFeatureChipType.normalizationGain:
        writer.writeByte(7);
      case FinampFeatureChipType.sampleRate:
        writer.writeByte(8);
      case FinampFeatureChipType.explicit:
        writer.writeByte(9);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FinampFeatureChipTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ReleaseDateFormatAdapter extends TypeAdapter<ReleaseDateFormat> {
  @override
  final typeId = 77;

  @override
  ReleaseDateFormat read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return ReleaseDateFormat.year;
      case 1:
        return ReleaseDateFormat.iso;
      case 2:
        return ReleaseDateFormat.monthYear;
      case 3:
        return ReleaseDateFormat.monthDayYear;
      default:
        return ReleaseDateFormat.year;
    }
  }

  @override
  void write(BinaryWriter writer, ReleaseDateFormat obj) {
    switch (obj) {
      case ReleaseDateFormat.year:
        writer.writeByte(0);
      case ReleaseDateFormat.iso:
        writer.writeByte(1);
      case ReleaseDateFormat.monthYear:
        writer.writeByte(2);
      case ReleaseDateFormat.monthDayYear:
        writer.writeByte(3);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReleaseDateFormatAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class AutoOfflineOptionAdapter extends TypeAdapter<AutoOfflineOption> {
  @override
  final typeId = 78;

  @override
  AutoOfflineOption read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return AutoOfflineOption.disabled;
      case 1:
        return AutoOfflineOption.network;
      case 2:
        return AutoOfflineOption.disconnected;
      case 3:
        return AutoOfflineOption.unreachable;
      default:
        return AutoOfflineOption.disabled;
    }
  }

  @override
  void write(BinaryWriter writer, AutoOfflineOption obj) {
    switch (obj) {
      case AutoOfflineOption.disabled:
        writer.writeByte(0);
      case AutoOfflineOption.network:
        writer.writeByte(1);
      case AutoOfflineOption.disconnected:
        writer.writeByte(2);
      case AutoOfflineOption.unreachable:
        writer.writeByte(3);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AutoOfflineOptionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ItemSwipeActionsAdapter extends TypeAdapter<ItemSwipeActions> {
  @override
  final typeId = 92;

  @override
  ItemSwipeActions read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return ItemSwipeActions.nothing;
      case 1:
        return ItemSwipeActions.addToQueue;
      case 2:
        return ItemSwipeActions.addToNextUp;
      case 3:
        return ItemSwipeActions.playNext;
      default:
        return ItemSwipeActions.nothing;
    }
  }

  @override
  void write(BinaryWriter writer, ItemSwipeActions obj) {
    switch (obj) {
      case ItemSwipeActions.nothing:
        writer.writeByte(0);
      case ItemSwipeActions.addToQueue:
        writer.writeByte(1);
      case ItemSwipeActions.addToNextUp:
        writer.writeByte(2);
      case ItemSwipeActions.playNext:
        writer.writeByte(3);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ItemSwipeActionsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ArtistTypeAdapter extends TypeAdapter<ArtistType> {
  @override
  final typeId = 93;

  @override
  ArtistType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return ArtistType.albumArtist;
      case 1:
        return ArtistType.artist;
      default:
        return ArtistType.albumArtist;
    }
  }

  @override
  void write(BinaryWriter writer, ArtistType obj) {
    switch (obj) {
      case ArtistType.albumArtist:
        writer.writeByte(0);
      case ArtistType.artist:
        writer.writeByte(1);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ArtistTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class CuratedItemSelectionTypeAdapter
    extends TypeAdapter<CuratedItemSelectionType> {
  @override
  final typeId = 95;

  @override
  CuratedItemSelectionType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return CuratedItemSelectionType.mostPlayed;
      case 1:
        return CuratedItemSelectionType.favorites;
      case 2:
        return CuratedItemSelectionType.random;
      case 3:
        return CuratedItemSelectionType.latestReleases;
      case 4:
        return CuratedItemSelectionType.recentlyAdded;
      case 5:
        return CuratedItemSelectionType.recentlyPlayed;
      default:
        return CuratedItemSelectionType.mostPlayed;
    }
  }

  @override
  void write(BinaryWriter writer, CuratedItemSelectionType obj) {
    switch (obj) {
      case CuratedItemSelectionType.mostPlayed:
        writer.writeByte(0);
      case CuratedItemSelectionType.favorites:
        writer.writeByte(1);
      case CuratedItemSelectionType.random:
        writer.writeByte(2);
      case CuratedItemSelectionType.latestReleases:
        writer.writeByte(3);
      case CuratedItemSelectionType.recentlyAdded:
        writer.writeByte(4);
      case CuratedItemSelectionType.recentlyPlayed:
        writer.writeByte(5);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CuratedItemSelectionTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class GenreItemSectionsAdapter extends TypeAdapter<GenreItemSections> {
  @override
  final typeId = 96;

  @override
  GenreItemSections read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return GenreItemSections.tracks;
      case 1:
        return GenreItemSections.albums;
      case 2:
        return GenreItemSections.artists;
      default:
        return GenreItemSections.tracks;
    }
  }

  @override
  void write(BinaryWriter writer, GenreItemSections obj) {
    switch (obj) {
      case GenreItemSections.tracks:
        writer.writeByte(0);
      case GenreItemSections.albums:
        writer.writeByte(1);
      case GenreItemSections.artists:
        writer.writeByte(2);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GenreItemSectionsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ArtistItemSectionsAdapter extends TypeAdapter<ArtistItemSections> {
  @override
  final typeId = 97;

  @override
  ArtistItemSections read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return ArtistItemSections.tracks;
      case 1:
        return ArtistItemSections.albums;
      case 2:
        return ArtistItemSections.appearsOn;
      default:
        return ArtistItemSections.tracks;
    }
  }

  @override
  void write(BinaryWriter writer, ArtistItemSections obj) {
    switch (obj) {
      case ArtistItemSections.tracks:
        writer.writeByte(0);
      case ArtistItemSections.albums:
        writer.writeByte(1);
      case ArtistItemSections.appearsOn:
        writer.writeByte(2);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ArtistItemSectionsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SleepTimerTypeAdapter extends TypeAdapter<SleepTimerType> {
  @override
  final typeId = 99;

  @override
  SleepTimerType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return SleepTimerType.duration;
      case 1:
        return SleepTimerType.tracks;
      default:
        return SleepTimerType.duration;
    }
  }

  @override
  void write(BinaryWriter writer, SleepTimerType obj) {
    switch (obj) {
      case SleepTimerType.duration:
        writer.writeByte(0);
      case SleepTimerType.tracks:
        writer.writeByte(1);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SleepTimerTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class TileAdditionalInfoTypeAdapter
    extends TypeAdapter<TileAdditionalInfoType> {
  @override
  final typeId = 100;

  @override
  TileAdditionalInfoType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return TileAdditionalInfoType.adaptive;
      case 1:
        return TileAdditionalInfoType.dateAdded;
      case 2:
        return TileAdditionalInfoType.dateReleased;
      case 3:
        return TileAdditionalInfoType.duration;
      case 4:
        return TileAdditionalInfoType.playCount;
      case 5:
        return TileAdditionalInfoType.dateLastPlayed;
      case 6:
        return TileAdditionalInfoType.none;
      default:
        return TileAdditionalInfoType.adaptive;
    }
  }

  @override
  void write(BinaryWriter writer, TileAdditionalInfoType obj) {
    switch (obj) {
      case TileAdditionalInfoType.adaptive:
        writer.writeByte(0);
      case TileAdditionalInfoType.dateAdded:
        writer.writeByte(1);
      case TileAdditionalInfoType.dateReleased:
        writer.writeByte(2);
      case TileAdditionalInfoType.duration:
        writer.writeByte(3);
      case TileAdditionalInfoType.playCount:
        writer.writeByte(4);
      case TileAdditionalInfoType.dateLastPlayed:
        writer.writeByte(5);
      case TileAdditionalInfoType.none:
        writer.writeByte(6);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TileAdditionalInfoTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class DiscordRpcIconAdapter extends TypeAdapter<DiscordRpcIcon> {
  @override
  final typeId = 101;

  @override
  DiscordRpcIcon read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return DiscordRpcIcon.black;
      case 1:
        return DiscordRpcIcon.dark;
      case 2:
        return DiscordRpcIcon.light;
      case 3:
        return DiscordRpcIcon.transparent;
      case 4:
        return DiscordRpcIcon.transparentWhite;
      case 5:
        return DiscordRpcIcon.jellyfinTransparent;
      default:
        return DiscordRpcIcon.black;
    }
  }

  @override
  void write(BinaryWriter writer, DiscordRpcIcon obj) {
    switch (obj) {
      case DiscordRpcIcon.black:
        writer.writeByte(0);
      case DiscordRpcIcon.dark:
        writer.writeByte(1);
      case DiscordRpcIcon.light:
        writer.writeByte(2);
      case DiscordRpcIcon.transparent:
        writer.writeByte(3);
      case DiscordRpcIcon.transparentWhite:
        writer.writeByte(4);
      case DiscordRpcIcon.jellyfinTransparent:
        writer.writeByte(5);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiscordRpcIconAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class PlaybackActionRowPageAdapter extends TypeAdapter<PlaybackActionRowPage> {
  @override
  final typeId = 107;

  @override
  PlaybackActionRowPage read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return PlaybackActionRowPage.newQueue;
      case 1:
        return PlaybackActionRowPage.playNext;
      case 2:
        return PlaybackActionRowPage.appendNext;
      case 3:
        return PlaybackActionRowPage.playLast;
      case 4:
        return PlaybackActionRowPage.moveWithinQueue;
      case 5:
        return PlaybackActionRowPage.regularTrackOptions;
      default:
        return PlaybackActionRowPage.newQueue;
    }
  }

  @override
  void write(BinaryWriter writer, PlaybackActionRowPage obj) {
    switch (obj) {
      case PlaybackActionRowPage.newQueue:
        writer.writeByte(0);
      case PlaybackActionRowPage.playNext:
        writer.writeByte(1);
      case PlaybackActionRowPage.appendNext:
        writer.writeByte(2);
      case PlaybackActionRowPage.playLast:
        writer.writeByte(3);
      case PlaybackActionRowPage.moveWithinQueue:
        writer.writeByte(4);
      case PlaybackActionRowPage.regularTrackOptions:
        writer.writeByte(5);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlaybackActionRowPageAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class RadioModeAdapter extends TypeAdapter<RadioMode> {
  @override
  final typeId = 109;

  @override
  RadioMode read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return RadioMode.similar;
      case 1:
        return RadioMode.continuous;
      case 2:
        return RadioMode.albumMix;
      case 3:
        return RadioMode.reshuffle;
      case 4:
        return RadioMode.random;
      default:
        return RadioMode.similar;
    }
  }

  @override
  void write(BinaryWriter writer, RadioMode obj) {
    switch (obj) {
      case RadioMode.similar:
        writer.writeByte(0);
      case RadioMode.continuous:
        writer.writeByte(1);
      case RadioMode.albumMix:
        writer.writeByte(2);
      case RadioMode.reshuffle:
        writer.writeByte(3);
      case RadioMode.random:
        writer.writeByte(4);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RadioModeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class MultichannelHandlingSettingAdapter
    extends TypeAdapter<MultichannelHandlingSetting> {
  @override
  final typeId = 111;

  @override
  MultichannelHandlingSetting read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return MultichannelHandlingSetting.stereoDownmixLossy;
      case 1:
        return MultichannelHandlingSetting.stereoDownmixAll;
      case 2:
        return MultichannelHandlingSetting.fixedBitrate;
      default:
        return MultichannelHandlingSetting.stereoDownmixLossy;
    }
  }

  @override
  void write(BinaryWriter writer, MultichannelHandlingSetting obj) {
    switch (obj) {
      case MultichannelHandlingSetting.stereoDownmixLossy:
        writer.writeByte(0);
      case MultichannelHandlingSetting.stereoDownmixAll:
        writer.writeByte(1);
      case MultichannelHandlingSetting.fixedBitrate:
        writer.writeByte(2);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MultichannelHandlingSettingAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class PreviousTracksPersistenceModeAdapter
    extends TypeAdapter<PreviousTracksPersistenceMode> {
  @override
  final typeId = 112;

  @override
  PreviousTracksPersistenceMode read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return PreviousTracksPersistenceMode.persistent;
      case 1:
        return PreviousTracksPersistenceMode.initiallyCollapsed;
      case 2:
        return PreviousTracksPersistenceMode.initiallyExpanded;
      default:
        return PreviousTracksPersistenceMode.persistent;
    }
  }

  @override
  void write(BinaryWriter writer, PreviousTracksPersistenceMode obj) {
    switch (obj) {
      case PreviousTracksPersistenceMode.persistent:
        writer.writeByte(0);
      case PreviousTracksPersistenceMode.initiallyCollapsed:
        writer.writeByte(1);
      case PreviousTracksPersistenceMode.initiallyExpanded:
        writer.writeByte(2);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PreviousTracksPersistenceModeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetFinampUserCollection on Isar {
  IsarCollection<FinampUser> get finampUsers => this.collection();
}

const FinampUserSchema = CollectionSchema(
  name: r'FinampUser',
  id: -4140083613547586279,
  properties: {
    r'accessToken': PropertySchema(
      id: 0,
      name: r'accessToken',
      type: IsarType.string,
    ),
    r'baseURL': PropertySchema(id: 1, name: r'baseURL', type: IsarType.string),
    r'baseUrl': PropertySchema(id: 2, name: r'baseUrl', type: IsarType.string),
    r'currentViewId': PropertySchema(
      id: 3,
      name: r'currentViewId',
      type: IsarType.string,
    ),
    r'id': PropertySchema(id: 4, name: r'id', type: IsarType.string),
    r'isLocal': PropertySchema(id: 5, name: r'isLocal', type: IsarType.bool),
    r'isarViews': PropertySchema(
      id: 6,
      name: r'isarViews',
      type: IsarType.string,
    ),
    r'localAddress': PropertySchema(
      id: 7,
      name: r'localAddress',
      type: IsarType.string,
    ),
    r'preferLocalNetwork': PropertySchema(
      id: 8,
      name: r'preferLocalNetwork',
      type: IsarType.bool,
    ),
    r'serverId': PropertySchema(
      id: 9,
      name: r'serverId',
      type: IsarType.string,
    ),
  },

  estimateSize: _finampUserEstimateSize,
  serialize: _finampUserSerialize,
  deserialize: _finampUserDeserialize,
  deserializeProp: _finampUserDeserializeProp,
  idName: r'isarId',
  indexes: {},
  links: {},
  embeddedSchemas: {},

  getId: _finampUserGetId,
  getLinks: _finampUserGetLinks,
  attach: _finampUserAttach,
  version: '3.1.0+1',
);

int _finampUserEstimateSize(
  FinampUser object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.accessToken.length * 3;
  bytesCount += 3 + object.baseURL.length * 3;
  bytesCount += 3 + object.publicAddress.length * 3;
  {
    final value = object.isarCurrentViewId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.id.length * 3;
  bytesCount += 3 + object.isarViews.length * 3;
  bytesCount += 3 + object.localAddress.length * 3;
  bytesCount += 3 + object.serverId.length * 3;
  return bytesCount;
}

void _finampUserSerialize(
  FinampUser object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.accessToken);
  writer.writeString(offsets[1], object.baseURL);
  writer.writeString(offsets[2], object.publicAddress);
  writer.writeString(offsets[3], object.isarCurrentViewId);
  writer.writeString(offsets[4], object.id);
  writer.writeBool(offsets[5], object.isLocal);
  writer.writeString(offsets[6], object.isarViews);
  writer.writeString(offsets[7], object.localAddress);
  writer.writeBool(offsets[8], object.preferLocalNetwork);
  writer.writeString(offsets[9], object.serverId);
}

FinampUser _finampUserDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = FinampUser(
    accessToken: reader.readString(offsets[0]),
    publicAddress: reader.readString(offsets[2]),
    id: reader.readString(offsets[4]),
    isLocal: reader.readBool(offsets[5]),
    localAddress: reader.readString(offsets[7]),
    preferLocalNetwork: reader.readBool(offsets[8]),
    serverId: reader.readString(offsets[9]),
  );
  object.isarCurrentViewId = reader.readStringOrNull(offsets[3]);
  object.isarViews = reader.readString(offsets[6]);
  return object;
}

P _finampUserDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    case 1:
      return (reader.readString(offset)) as P;
    case 2:
      return (reader.readString(offset)) as P;
    case 3:
      return (reader.readStringOrNull(offset)) as P;
    case 4:
      return (reader.readString(offset)) as P;
    case 5:
      return (reader.readBool(offset)) as P;
    case 6:
      return (reader.readString(offset)) as P;
    case 7:
      return (reader.readString(offset)) as P;
    case 8:
      return (reader.readBool(offset)) as P;
    case 9:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _finampUserGetId(FinampUser object) {
  return object.isarId;
}

List<IsarLinkBase<dynamic>> _finampUserGetLinks(FinampUser object) {
  return [];
}

void _finampUserAttach(IsarCollection<dynamic> col, Id id, FinampUser object) {}

extension FinampUserQueryWhereSort
    on QueryBuilder<FinampUser, FinampUser, QWhere> {
  QueryBuilder<FinampUser, FinampUser, QAfterWhere> anyIsarId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension FinampUserQueryWhere
    on QueryBuilder<FinampUser, FinampUser, QWhereClause> {
  QueryBuilder<FinampUser, FinampUser, QAfterWhereClause> isarIdEqualTo(
    Id isarId,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(lower: isarId, upper: isarId),
      );
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterWhereClause> isarIdNotEqualTo(
    Id isarId,
  ) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: isarId, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: isarId, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: isarId, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: isarId, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterWhereClause> isarIdGreaterThan(
    Id isarId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: isarId, includeLower: include),
      );
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterWhereClause> isarIdLessThan(
    Id isarId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: isarId, includeUpper: include),
      );
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterWhereClause> isarIdBetween(
    Id lowerIsarId,
    Id upperIsarId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(
          lower: lowerIsarId,
          includeLower: includeLower,
          upper: upperIsarId,
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension FinampUserQueryFilter
    on QueryBuilder<FinampUser, FinampUser, QFilterCondition> {
  QueryBuilder<FinampUser, FinampUser, QAfterFilterCondition>
  accessTokenEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'accessToken',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterFilterCondition>
  accessTokenGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'accessToken',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterFilterCondition>
  accessTokenLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'accessToken',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterFilterCondition>
  accessTokenBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'accessToken',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterFilterCondition>
  accessTokenStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'accessToken',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterFilterCondition>
  accessTokenEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'accessToken',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterFilterCondition>
  accessTokenContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'accessToken',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterFilterCondition>
  accessTokenMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'accessToken',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterFilterCondition>
  accessTokenIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'accessToken', value: ''),
      );
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterFilterCondition>
  accessTokenIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'accessToken', value: ''),
      );
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterFilterCondition> baseURLEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'baseURL',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterFilterCondition>
  baseURLGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'baseURL',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterFilterCondition> baseURLLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'baseURL',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterFilterCondition> baseURLBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'baseURL',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterFilterCondition> baseURLStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'baseURL',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterFilterCondition> baseURLEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'baseURL',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterFilterCondition> baseURLContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'baseURL',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterFilterCondition> baseURLMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'baseURL',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterFilterCondition> baseURLIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'baseURL', value: ''),
      );
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterFilterCondition>
  baseURLIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'baseURL', value: ''),
      );
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterFilterCondition>
  publicAddressEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'baseUrl',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterFilterCondition>
  publicAddressGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'baseUrl',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterFilterCondition>
  publicAddressLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'baseUrl',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterFilterCondition>
  publicAddressBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'baseUrl',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterFilterCondition>
  publicAddressStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'baseUrl',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterFilterCondition>
  publicAddressEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'baseUrl',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterFilterCondition>
  publicAddressContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'baseUrl',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterFilterCondition>
  publicAddressMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'baseUrl',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterFilterCondition>
  publicAddressIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'baseUrl', value: ''),
      );
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterFilterCondition>
  publicAddressIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'baseUrl', value: ''),
      );
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterFilterCondition>
  isarCurrentViewIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'currentViewId'),
      );
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterFilterCondition>
  isarCurrentViewIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'currentViewId'),
      );
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterFilterCondition>
  isarCurrentViewIdEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'currentViewId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterFilterCondition>
  isarCurrentViewIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'currentViewId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterFilterCondition>
  isarCurrentViewIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'currentViewId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterFilterCondition>
  isarCurrentViewIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'currentViewId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterFilterCondition>
  isarCurrentViewIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'currentViewId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterFilterCondition>
  isarCurrentViewIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'currentViewId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterFilterCondition>
  isarCurrentViewIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'currentViewId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterFilterCondition>
  isarCurrentViewIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'currentViewId',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterFilterCondition>
  isarCurrentViewIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'currentViewId', value: ''),
      );
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterFilterCondition>
  isarCurrentViewIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'currentViewId', value: ''),
      );
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterFilterCondition> idEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterFilterCondition> idGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterFilterCondition> idLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterFilterCondition> idBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterFilterCondition> idStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterFilterCondition> idEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterFilterCondition> idContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterFilterCondition> idMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'id',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterFilterCondition> idIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: ''),
      );
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterFilterCondition> idIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'id', value: ''),
      );
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterFilterCondition> isLocalEqualTo(
    bool value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'isLocal', value: value),
      );
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterFilterCondition> isarIdEqualTo(
    Id value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'isarId', value: value),
      );
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterFilterCondition> isarIdGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'isarId',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterFilterCondition> isarIdLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'isarId',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterFilterCondition> isarIdBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'isarId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterFilterCondition> isarViewsEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'isarViews',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterFilterCondition>
  isarViewsGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'isarViews',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterFilterCondition> isarViewsLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'isarViews',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterFilterCondition> isarViewsBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'isarViews',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterFilterCondition>
  isarViewsStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'isarViews',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterFilterCondition> isarViewsEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'isarViews',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterFilterCondition> isarViewsContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'isarViews',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterFilterCondition> isarViewsMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'isarViews',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterFilterCondition>
  isarViewsIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'isarViews', value: ''),
      );
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterFilterCondition>
  isarViewsIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'isarViews', value: ''),
      );
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterFilterCondition>
  localAddressEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'localAddress',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterFilterCondition>
  localAddressGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'localAddress',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterFilterCondition>
  localAddressLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'localAddress',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterFilterCondition>
  localAddressBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'localAddress',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterFilterCondition>
  localAddressStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'localAddress',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterFilterCondition>
  localAddressEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'localAddress',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterFilterCondition>
  localAddressContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'localAddress',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterFilterCondition>
  localAddressMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'localAddress',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterFilterCondition>
  localAddressIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'localAddress', value: ''),
      );
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterFilterCondition>
  localAddressIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'localAddress', value: ''),
      );
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterFilterCondition>
  preferLocalNetworkEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'preferLocalNetwork', value: value),
      );
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterFilterCondition> serverIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'serverId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterFilterCondition>
  serverIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'serverId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterFilterCondition> serverIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'serverId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterFilterCondition> serverIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'serverId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterFilterCondition>
  serverIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'serverId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterFilterCondition> serverIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'serverId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterFilterCondition> serverIdContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'serverId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterFilterCondition> serverIdMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'serverId',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterFilterCondition>
  serverIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'serverId', value: ''),
      );
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterFilterCondition>
  serverIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'serverId', value: ''),
      );
    });
  }
}

extension FinampUserQueryObject
    on QueryBuilder<FinampUser, FinampUser, QFilterCondition> {}

extension FinampUserQueryLinks
    on QueryBuilder<FinampUser, FinampUser, QFilterCondition> {}

extension FinampUserQuerySortBy
    on QueryBuilder<FinampUser, FinampUser, QSortBy> {
  QueryBuilder<FinampUser, FinampUser, QAfterSortBy> sortByAccessToken() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'accessToken', Sort.asc);
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterSortBy> sortByAccessTokenDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'accessToken', Sort.desc);
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterSortBy> sortByBaseURL() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'baseURL', Sort.asc);
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterSortBy> sortByBaseURLDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'baseURL', Sort.desc);
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterSortBy> sortByPublicAddress() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'baseUrl', Sort.asc);
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterSortBy> sortByPublicAddressDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'baseUrl', Sort.desc);
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterSortBy> sortByIsarCurrentViewId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'currentViewId', Sort.asc);
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterSortBy>
  sortByIsarCurrentViewIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'currentViewId', Sort.desc);
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterSortBy> sortById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterSortBy> sortByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterSortBy> sortByIsLocal() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isLocal', Sort.asc);
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterSortBy> sortByIsLocalDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isLocal', Sort.desc);
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterSortBy> sortByIsarViews() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isarViews', Sort.asc);
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterSortBy> sortByIsarViewsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isarViews', Sort.desc);
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterSortBy> sortByLocalAddress() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'localAddress', Sort.asc);
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterSortBy> sortByLocalAddressDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'localAddress', Sort.desc);
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterSortBy>
  sortByPreferLocalNetwork() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'preferLocalNetwork', Sort.asc);
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterSortBy>
  sortByPreferLocalNetworkDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'preferLocalNetwork', Sort.desc);
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterSortBy> sortByServerId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'serverId', Sort.asc);
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterSortBy> sortByServerIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'serverId', Sort.desc);
    });
  }
}

extension FinampUserQuerySortThenBy
    on QueryBuilder<FinampUser, FinampUser, QSortThenBy> {
  QueryBuilder<FinampUser, FinampUser, QAfterSortBy> thenByAccessToken() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'accessToken', Sort.asc);
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterSortBy> thenByAccessTokenDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'accessToken', Sort.desc);
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterSortBy> thenByBaseURL() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'baseURL', Sort.asc);
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterSortBy> thenByBaseURLDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'baseURL', Sort.desc);
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterSortBy> thenByPublicAddress() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'baseUrl', Sort.asc);
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterSortBy> thenByPublicAddressDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'baseUrl', Sort.desc);
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterSortBy> thenByIsarCurrentViewId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'currentViewId', Sort.asc);
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterSortBy>
  thenByIsarCurrentViewIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'currentViewId', Sort.desc);
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterSortBy> thenByIsLocal() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isLocal', Sort.asc);
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterSortBy> thenByIsLocalDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isLocal', Sort.desc);
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterSortBy> thenByIsarId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isarId', Sort.asc);
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterSortBy> thenByIsarIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isarId', Sort.desc);
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterSortBy> thenByIsarViews() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isarViews', Sort.asc);
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterSortBy> thenByIsarViewsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isarViews', Sort.desc);
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterSortBy> thenByLocalAddress() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'localAddress', Sort.asc);
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterSortBy> thenByLocalAddressDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'localAddress', Sort.desc);
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterSortBy>
  thenByPreferLocalNetwork() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'preferLocalNetwork', Sort.asc);
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterSortBy>
  thenByPreferLocalNetworkDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'preferLocalNetwork', Sort.desc);
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterSortBy> thenByServerId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'serverId', Sort.asc);
    });
  }

  QueryBuilder<FinampUser, FinampUser, QAfterSortBy> thenByServerIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'serverId', Sort.desc);
    });
  }
}

extension FinampUserQueryWhereDistinct
    on QueryBuilder<FinampUser, FinampUser, QDistinct> {
  QueryBuilder<FinampUser, FinampUser, QDistinct> distinctByAccessToken({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'accessToken', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<FinampUser, FinampUser, QDistinct> distinctByBaseURL({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'baseURL', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<FinampUser, FinampUser, QDistinct> distinctByPublicAddress({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'baseUrl', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<FinampUser, FinampUser, QDistinct> distinctByIsarCurrentViewId({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'currentViewId',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<FinampUser, FinampUser, QDistinct> distinctById({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'id', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<FinampUser, FinampUser, QDistinct> distinctByIsLocal() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isLocal');
    });
  }

  QueryBuilder<FinampUser, FinampUser, QDistinct> distinctByIsarViews({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isarViews', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<FinampUser, FinampUser, QDistinct> distinctByLocalAddress({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'localAddress', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<FinampUser, FinampUser, QDistinct>
  distinctByPreferLocalNetwork() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'preferLocalNetwork');
    });
  }

  QueryBuilder<FinampUser, FinampUser, QDistinct> distinctByServerId({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'serverId', caseSensitive: caseSensitive);
    });
  }
}

extension FinampUserQueryProperty
    on QueryBuilder<FinampUser, FinampUser, QQueryProperty> {
  QueryBuilder<FinampUser, int, QQueryOperations> isarIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isarId');
    });
  }

  QueryBuilder<FinampUser, String, QQueryOperations> accessTokenProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'accessToken');
    });
  }

  QueryBuilder<FinampUser, String, QQueryOperations> baseURLProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'baseURL');
    });
  }

  QueryBuilder<FinampUser, String, QQueryOperations> publicAddressProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'baseUrl');
    });
  }

  QueryBuilder<FinampUser, String?, QQueryOperations>
  isarCurrentViewIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'currentViewId');
    });
  }

  QueryBuilder<FinampUser, String, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<FinampUser, bool, QQueryOperations> isLocalProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isLocal');
    });
  }

  QueryBuilder<FinampUser, String, QQueryOperations> isarViewsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isarViews');
    });
  }

  QueryBuilder<FinampUser, String, QQueryOperations> localAddressProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'localAddress');
    });
  }

  QueryBuilder<FinampUser, bool, QQueryOperations>
  preferLocalNetworkProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'preferLocalNetwork');
    });
  }

  QueryBuilder<FinampUser, String, QQueryOperations> serverIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'serverId');
    });
  }
}

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetDownloadItemCollection on Isar {
  IsarCollection<DownloadItem> get downloadItems => this.collection();
}

const DownloadItemSchema = CollectionSchema(
  name: r'DownloadItem',
  id: 3470061580579511306,
  properties: {
    r'baseIndexNumber': PropertySchema(
      id: 0,
      name: r'baseIndexNumber',
      type: IsarType.long,
    ),
    r'baseItemType': PropertySchema(
      id: 1,
      name: r'baseItemType',
      type: IsarType.byte,
      enumMap: _DownloadItembaseItemTypeEnumValueMap,
    ),
    r'fileTranscodingProfile': PropertySchema(
      id: 2,
      name: r'fileTranscodingProfile',
      type: IsarType.object,

      target: r'DownloadProfile',
    ),
    r'id': PropertySchema(id: 3, name: r'id', type: IsarType.string),
    r'jsonItem': PropertySchema(
      id: 4,
      name: r'jsonItem',
      type: IsarType.string,
    ),
    r'name': PropertySchema(id: 5, name: r'name', type: IsarType.string),
    r'orderedChildren': PropertySchema(
      id: 6,
      name: r'orderedChildren',
      type: IsarType.longList,
    ),
    r'parentIndexNumber': PropertySchema(
      id: 7,
      name: r'parentIndexNumber',
      type: IsarType.long,
    ),
    r'path': PropertySchema(id: 8, name: r'path', type: IsarType.string),
    r'state': PropertySchema(
      id: 9,
      name: r'state',
      type: IsarType.byte,
      enumMap: _DownloadItemstateEnumValueMap,
    ),
    r'syncTranscodingProfile': PropertySchema(
      id: 10,
      name: r'syncTranscodingProfile',
      type: IsarType.object,

      target: r'DownloadProfile',
    ),
    r'type': PropertySchema(
      id: 11,
      name: r'type',
      type: IsarType.byte,
      enumMap: _DownloadItemtypeEnumValueMap,
    ),
    r'userTranscodingProfile': PropertySchema(
      id: 12,
      name: r'userTranscodingProfile',
      type: IsarType.object,

      target: r'DownloadProfile',
    ),
    r'viewId': PropertySchema(id: 13, name: r'viewId', type: IsarType.string),
  },

  estimateSize: _downloadItemEstimateSize,
  serialize: _downloadItemSerialize,
  deserialize: _downloadItemDeserialize,
  deserializeProp: _downloadItemDeserializeProp,
  idName: r'isarId',
  indexes: {
    r'state': IndexSchema(
      id: 7917036384617311412,
      name: r'state',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'state',
          type: IndexType.value,
          caseSensitive: false,
        ),
      ],
    ),
    r'type': IndexSchema(
      id: 5117122708147080838,
      name: r'type',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'type',
          type: IndexType.value,
          caseSensitive: false,
        ),
      ],
    ),
  },
  links: {
    r'requires': LinkSchema(
      id: 2869659933205985607,
      name: r'requires',
      target: r'DownloadItem',
      single: false,
    ),
    r'requiredBy': LinkSchema(
      id: 8162545016065706399,
      name: r'requiredBy',
      target: r'DownloadItem',
      single: false,
      linkName: r'requires',
    ),
    r'info': LinkSchema(
      id: 577543621393535253,
      name: r'info',
      target: r'DownloadItem',
      single: false,
    ),
    r'infoFor': LinkSchema(
      id: -2484078441196254859,
      name: r'infoFor',
      target: r'DownloadItem',
      single: false,
      linkName: r'info',
    ),
  },
  embeddedSchemas: {r'DownloadProfile': DownloadProfileSchema},

  getId: _downloadItemGetId,
  getLinks: _downloadItemGetLinks,
  attach: _downloadItemAttach,
  version: '3.1.0+1',
);

int _downloadItemEstimateSize(
  DownloadItem object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  {
    final value = object.fileTranscodingProfile;
    if (value != null) {
      bytesCount +=
          3 +
          DownloadProfileSchema.estimateSize(
            value,
            allOffsets[DownloadProfile]!,
            allOffsets,
          );
    }
  }
  bytesCount += 3 + object.id.length * 3;
  {
    final value = object.jsonItem;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.name.length * 3;
  {
    final value = object.orderedChildren;
    if (value != null) {
      bytesCount += 3 + value.length * 8;
    }
  }
  {
    final value = object.path;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.syncTranscodingProfile;
    if (value != null) {
      bytesCount +=
          3 +
          DownloadProfileSchema.estimateSize(
            value,
            allOffsets[DownloadProfile]!,
            allOffsets,
          );
    }
  }
  {
    final value = object.userTranscodingProfile;
    if (value != null) {
      bytesCount +=
          3 +
          DownloadProfileSchema.estimateSize(
            value,
            allOffsets[DownloadProfile]!,
            allOffsets,
          );
    }
  }
  {
    final value = object.isarViewId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  return bytesCount;
}

void _downloadItemSerialize(
  DownloadItem object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeLong(offsets[0], object.baseIndexNumber);
  writer.writeByte(offsets[1], object.baseItemType.index);
  writer.writeObject<DownloadProfile>(
    offsets[2],
    allOffsets,
    DownloadProfileSchema.serialize,
    object.fileTranscodingProfile,
  );
  writer.writeString(offsets[3], object.id);
  writer.writeString(offsets[4], object.jsonItem);
  writer.writeString(offsets[5], object.name);
  writer.writeLongList(offsets[6], object.orderedChildren);
  writer.writeLong(offsets[7], object.parentIndexNumber);
  writer.writeString(offsets[8], object.path);
  writer.writeByte(offsets[9], object.state.index);
  writer.writeObject<DownloadProfile>(
    offsets[10],
    allOffsets,
    DownloadProfileSchema.serialize,
    object.syncTranscodingProfile,
  );
  writer.writeByte(offsets[11], object.type.index);
  writer.writeObject<DownloadProfile>(
    offsets[12],
    allOffsets,
    DownloadProfileSchema.serialize,
    object.userTranscodingProfile,
  );
  writer.writeString(offsets[13], object.isarViewId);
}

DownloadItem _downloadItemDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = DownloadItem(
    baseIndexNumber: reader.readLongOrNull(offsets[0]),
    baseItemType:
        _DownloadItembaseItemTypeValueEnumMap[reader.readByteOrNull(
          offsets[1],
        )] ??
        BaseItemDtoType.noItem,
    fileTranscodingProfile: reader.readObjectOrNull<DownloadProfile>(
      offsets[2],
      DownloadProfileSchema.deserialize,
      allOffsets,
    ),
    id: reader.readString(offsets[3]),
    isarId: id,
    jsonItem: reader.readStringOrNull(offsets[4]),
    name: reader.readString(offsets[5]),
    orderedChildren: reader.readLongList(offsets[6]),
    parentIndexNumber: reader.readLongOrNull(offsets[7]),
    path: reader.readStringOrNull(offsets[8]),
    state:
        _DownloadItemstateValueEnumMap[reader.readByteOrNull(offsets[9])] ??
        DownloadItemState.notDownloaded,
    syncTranscodingProfile: reader.readObjectOrNull<DownloadProfile>(
      offsets[10],
      DownloadProfileSchema.deserialize,
      allOffsets,
    ),
    type:
        _DownloadItemtypeValueEnumMap[reader.readByteOrNull(offsets[11])] ??
        DownloadItemType.collection,
    userTranscodingProfile: reader.readObjectOrNull<DownloadProfile>(
      offsets[12],
      DownloadProfileSchema.deserialize,
      allOffsets,
    ),
    isarViewId: reader.readStringOrNull(offsets[13]),
  );
  return object;
}

P _downloadItemDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readLongOrNull(offset)) as P;
    case 1:
      return (_DownloadItembaseItemTypeValueEnumMap[reader.readByteOrNull(
                offset,
              )] ??
              BaseItemDtoType.noItem)
          as P;
    case 2:
      return (reader.readObjectOrNull<DownloadProfile>(
            offset,
            DownloadProfileSchema.deserialize,
            allOffsets,
          ))
          as P;
    case 3:
      return (reader.readString(offset)) as P;
    case 4:
      return (reader.readStringOrNull(offset)) as P;
    case 5:
      return (reader.readString(offset)) as P;
    case 6:
      return (reader.readLongList(offset)) as P;
    case 7:
      return (reader.readLongOrNull(offset)) as P;
    case 8:
      return (reader.readStringOrNull(offset)) as P;
    case 9:
      return (_DownloadItemstateValueEnumMap[reader.readByteOrNull(offset)] ??
              DownloadItemState.notDownloaded)
          as P;
    case 10:
      return (reader.readObjectOrNull<DownloadProfile>(
            offset,
            DownloadProfileSchema.deserialize,
            allOffsets,
          ))
          as P;
    case 11:
      return (_DownloadItemtypeValueEnumMap[reader.readByteOrNull(offset)] ??
              DownloadItemType.collection)
          as P;
    case 12:
      return (reader.readObjectOrNull<DownloadProfile>(
            offset,
            DownloadProfileSchema.deserialize,
            allOffsets,
          ))
          as P;
    case 13:
      return (reader.readStringOrNull(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

const _DownloadItembaseItemTypeEnumValueMap = {
  'noItem': 0,
  'album': 1,
  'artist': 2,
  'playlist': 3,
  'genre': 4,
  'track': 5,
  'library': 6,
  'folder': 7,
  'musicVideo': 8,
  'audioBook': 9,
  'tvEpisode': 10,
  'video': 11,
  'movie': 12,
  'trailer': 13,
  'unknown': 14,
};
const _DownloadItembaseItemTypeValueEnumMap = {
  0: BaseItemDtoType.noItem,
  1: BaseItemDtoType.album,
  2: BaseItemDtoType.artist,
  3: BaseItemDtoType.playlist,
  4: BaseItemDtoType.genre,
  5: BaseItemDtoType.track,
  6: BaseItemDtoType.library,
  7: BaseItemDtoType.folder,
  8: BaseItemDtoType.musicVideo,
  9: BaseItemDtoType.audioBook,
  10: BaseItemDtoType.tvEpisode,
  11: BaseItemDtoType.video,
  12: BaseItemDtoType.movie,
  13: BaseItemDtoType.trailer,
  14: BaseItemDtoType.unknown,
};
const _DownloadItemstateEnumValueMap = {
  'notDownloaded': 0,
  'downloading': 1,
  'failed': 2,
  'complete': 3,
  'enqueued': 4,
  'syncFailed': 5,
  'needsRedownload': 6,
  'needsRedownloadComplete': 7,
};
const _DownloadItemstateValueEnumMap = {
  0: DownloadItemState.notDownloaded,
  1: DownloadItemState.downloading,
  2: DownloadItemState.failed,
  3: DownloadItemState.complete,
  4: DownloadItemState.enqueued,
  5: DownloadItemState.syncFailed,
  6: DownloadItemState.needsRedownload,
  7: DownloadItemState.needsRedownloadComplete,
};
const _DownloadItemtypeEnumValueMap = {
  'collection': 0,
  'track': 1,
  'image': 2,
  'anchor': 3,
  'finampCollection': 4,
};
const _DownloadItemtypeValueEnumMap = {
  0: DownloadItemType.collection,
  1: DownloadItemType.track,
  2: DownloadItemType.image,
  3: DownloadItemType.anchor,
  4: DownloadItemType.finampCollection,
};

Id _downloadItemGetId(DownloadItem object) {
  return object.isarId;
}

List<IsarLinkBase<dynamic>> _downloadItemGetLinks(DownloadItem object) {
  return [object.requires, object.requiredBy, object.info, object.infoFor];
}

void _downloadItemAttach(
  IsarCollection<dynamic> col,
  Id id,
  DownloadItem object,
) {
  object.requires.attach(
    col,
    col.isar.collection<DownloadItem>(),
    r'requires',
    id,
  );
  object.requiredBy.attach(
    col,
    col.isar.collection<DownloadItem>(),
    r'requiredBy',
    id,
  );
  object.info.attach(col, col.isar.collection<DownloadItem>(), r'info', id);
  object.infoFor.attach(
    col,
    col.isar.collection<DownloadItem>(),
    r'infoFor',
    id,
  );
}

extension DownloadItemQueryWhereSort
    on QueryBuilder<DownloadItem, DownloadItem, QWhere> {
  QueryBuilder<DownloadItem, DownloadItem, QAfterWhere> anyIsarId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterWhere> anyState() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'state'),
      );
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterWhere> anyType() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'type'),
      );
    });
  }
}

extension DownloadItemQueryWhere
    on QueryBuilder<DownloadItem, DownloadItem, QWhereClause> {
  QueryBuilder<DownloadItem, DownloadItem, QAfterWhereClause> isarIdEqualTo(
    Id isarId,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(lower: isarId, upper: isarId),
      );
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterWhereClause> isarIdNotEqualTo(
    Id isarId,
  ) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: isarId, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: isarId, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: isarId, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: isarId, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterWhereClause> isarIdGreaterThan(
    Id isarId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: isarId, includeLower: include),
      );
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterWhereClause> isarIdLessThan(
    Id isarId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: isarId, includeUpper: include),
      );
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterWhereClause> isarIdBetween(
    Id lowerIsarId,
    Id upperIsarId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(
          lower: lowerIsarId,
          includeLower: includeLower,
          upper: upperIsarId,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterWhereClause> stateEqualTo(
    DownloadItemState state,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'state', value: [state]),
      );
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterWhereClause> stateNotEqualTo(
    DownloadItemState state,
  ) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'state',
                lower: [],
                upper: [state],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'state',
                lower: [state],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'state',
                lower: [state],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'state',
                lower: [],
                upper: [state],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterWhereClause> stateGreaterThan(
    DownloadItemState state, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'state',
          lower: [state],
          includeLower: include,
          upper: [],
        ),
      );
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterWhereClause> stateLessThan(
    DownloadItemState state, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'state',
          lower: [],
          upper: [state],
          includeUpper: include,
        ),
      );
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterWhereClause> stateBetween(
    DownloadItemState lowerState,
    DownloadItemState upperState, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'state',
          lower: [lowerState],
          includeLower: includeLower,
          upper: [upperState],
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterWhereClause> typeEqualTo(
    DownloadItemType type,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'type', value: [type]),
      );
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterWhereClause> typeNotEqualTo(
    DownloadItemType type,
  ) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'type',
                lower: [],
                upper: [type],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'type',
                lower: [type],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'type',
                lower: [type],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'type',
                lower: [],
                upper: [type],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterWhereClause> typeGreaterThan(
    DownloadItemType type, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'type',
          lower: [type],
          includeLower: include,
          upper: [],
        ),
      );
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterWhereClause> typeLessThan(
    DownloadItemType type, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'type',
          lower: [],
          upper: [type],
          includeUpper: include,
        ),
      );
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterWhereClause> typeBetween(
    DownloadItemType lowerType,
    DownloadItemType upperType, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'type',
          lower: [lowerType],
          includeLower: includeLower,
          upper: [upperType],
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension DownloadItemQueryFilter
    on QueryBuilder<DownloadItem, DownloadItem, QFilterCondition> {
  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition>
  baseIndexNumberIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'baseIndexNumber'),
      );
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition>
  baseIndexNumberIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'baseIndexNumber'),
      );
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition>
  baseIndexNumberEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'baseIndexNumber', value: value),
      );
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition>
  baseIndexNumberGreaterThan(int? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'baseIndexNumber',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition>
  baseIndexNumberLessThan(int? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'baseIndexNumber',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition>
  baseIndexNumberBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'baseIndexNumber',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition>
  baseItemTypeEqualTo(BaseItemDtoType value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'baseItemType', value: value),
      );
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition>
  baseItemTypeGreaterThan(BaseItemDtoType value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'baseItemType',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition>
  baseItemTypeLessThan(BaseItemDtoType value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'baseItemType',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition>
  baseItemTypeBetween(
    BaseItemDtoType lower,
    BaseItemDtoType upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'baseItemType',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition>
  fileTranscodingProfileIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'fileTranscodingProfile'),
      );
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition>
  fileTranscodingProfileIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'fileTranscodingProfile'),
      );
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition> idEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition> idGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition> idLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition> idBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition> idStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition> idEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition> idContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition> idMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'id',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition> idIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: ''),
      );
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition>
  idIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'id', value: ''),
      );
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition> isarIdEqualTo(
    Id value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'isarId', value: value),
      );
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition>
  isarIdGreaterThan(Id value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'isarId',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition>
  isarIdLessThan(Id value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'isarId',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition> isarIdBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'isarId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition>
  jsonItemIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'jsonItem'),
      );
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition>
  jsonItemIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'jsonItem'),
      );
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition>
  jsonItemEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'jsonItem',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition>
  jsonItemGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'jsonItem',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition>
  jsonItemLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'jsonItem',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition>
  jsonItemBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'jsonItem',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition>
  jsonItemStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'jsonItem',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition>
  jsonItemEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'jsonItem',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition>
  jsonItemContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'jsonItem',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition>
  jsonItemMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'jsonItem',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition>
  jsonItemIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'jsonItem', value: ''),
      );
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition>
  jsonItemIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'jsonItem', value: ''),
      );
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition> nameEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition>
  nameGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition> nameLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition> nameBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'name',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition>
  nameStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition> nameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition> nameContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition> nameMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'name',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition>
  nameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'name', value: ''),
      );
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition>
  nameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'name', value: ''),
      );
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition>
  orderedChildrenIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'orderedChildren'),
      );
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition>
  orderedChildrenIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'orderedChildren'),
      );
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition>
  orderedChildrenElementEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'orderedChildren', value: value),
      );
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition>
  orderedChildrenElementGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'orderedChildren',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition>
  orderedChildrenElementLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'orderedChildren',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition>
  orderedChildrenElementBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'orderedChildren',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition>
  orderedChildrenLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'orderedChildren', length, true, length, true);
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition>
  orderedChildrenIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'orderedChildren', 0, true, 0, true);
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition>
  orderedChildrenIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'orderedChildren', 0, false, 999999, true);
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition>
  orderedChildrenLengthLessThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'orderedChildren', 0, true, length, include);
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition>
  orderedChildrenLengthGreaterThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'orderedChildren',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition>
  orderedChildrenLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'orderedChildren',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition>
  parentIndexNumberIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'parentIndexNumber'),
      );
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition>
  parentIndexNumberIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'parentIndexNumber'),
      );
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition>
  parentIndexNumberEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'parentIndexNumber', value: value),
      );
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition>
  parentIndexNumberGreaterThan(int? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'parentIndexNumber',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition>
  parentIndexNumberLessThan(int? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'parentIndexNumber',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition>
  parentIndexNumberBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'parentIndexNumber',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition> pathIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'path'),
      );
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition>
  pathIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'path'),
      );
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition> pathEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'path',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition>
  pathGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'path',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition> pathLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'path',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition> pathBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'path',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition>
  pathStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'path',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition> pathEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'path',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition> pathContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'path',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition> pathMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'path',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition>
  pathIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'path', value: ''),
      );
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition>
  pathIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'path', value: ''),
      );
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition> stateEqualTo(
    DownloadItemState value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'state', value: value),
      );
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition>
  stateGreaterThan(DownloadItemState value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'state',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition> stateLessThan(
    DownloadItemState value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'state',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition> stateBetween(
    DownloadItemState lower,
    DownloadItemState upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'state',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition>
  syncTranscodingProfileIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'syncTranscodingProfile'),
      );
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition>
  syncTranscodingProfileIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'syncTranscodingProfile'),
      );
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition> typeEqualTo(
    DownloadItemType value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'type', value: value),
      );
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition>
  typeGreaterThan(DownloadItemType value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'type',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition> typeLessThan(
    DownloadItemType value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'type',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition> typeBetween(
    DownloadItemType lower,
    DownloadItemType upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'type',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition>
  userTranscodingProfileIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'userTranscodingProfile'),
      );
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition>
  userTranscodingProfileIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'userTranscodingProfile'),
      );
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition>
  isarViewIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'viewId'),
      );
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition>
  isarViewIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'viewId'),
      );
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition>
  isarViewIdEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'viewId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition>
  isarViewIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'viewId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition>
  isarViewIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'viewId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition>
  isarViewIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'viewId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition>
  isarViewIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'viewId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition>
  isarViewIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'viewId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition>
  isarViewIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'viewId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition>
  isarViewIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'viewId',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition>
  isarViewIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'viewId', value: ''),
      );
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition>
  isarViewIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'viewId', value: ''),
      );
    });
  }
}

extension DownloadItemQueryObject
    on QueryBuilder<DownloadItem, DownloadItem, QFilterCondition> {
  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition>
  fileTranscodingProfile(FilterQuery<DownloadProfile> q) {
    return QueryBuilder.apply(this, (query) {
      return query.object(q, r'fileTranscodingProfile');
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition>
  syncTranscodingProfile(FilterQuery<DownloadProfile> q) {
    return QueryBuilder.apply(this, (query) {
      return query.object(q, r'syncTranscodingProfile');
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition>
  userTranscodingProfile(FilterQuery<DownloadProfile> q) {
    return QueryBuilder.apply(this, (query) {
      return query.object(q, r'userTranscodingProfile');
    });
  }
}

extension DownloadItemQueryLinks
    on QueryBuilder<DownloadItem, DownloadItem, QFilterCondition> {
  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition> requires(
    FilterQuery<DownloadItem> q,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.link(q, r'requires');
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition>
  requiresLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.linkLength(r'requires', length, true, length, true);
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition>
  requiresIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.linkLength(r'requires', 0, true, 0, true);
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition>
  requiresIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.linkLength(r'requires', 0, false, 999999, true);
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition>
  requiresLengthLessThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.linkLength(r'requires', 0, true, length, include);
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition>
  requiresLengthGreaterThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.linkLength(r'requires', length, include, 999999, true);
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition>
  requiresLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.linkLength(
        r'requires',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition> requiredBy(
    FilterQuery<DownloadItem> q,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.link(q, r'requiredBy');
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition>
  requiredByLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.linkLength(r'requiredBy', length, true, length, true);
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition>
  requiredByIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.linkLength(r'requiredBy', 0, true, 0, true);
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition>
  requiredByIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.linkLength(r'requiredBy', 0, false, 999999, true);
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition>
  requiredByLengthLessThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.linkLength(r'requiredBy', 0, true, length, include);
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition>
  requiredByLengthGreaterThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.linkLength(r'requiredBy', length, include, 999999, true);
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition>
  requiredByLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.linkLength(
        r'requiredBy',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition> info(
    FilterQuery<DownloadItem> q,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.link(q, r'info');
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition>
  infoLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.linkLength(r'info', length, true, length, true);
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition>
  infoIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.linkLength(r'info', 0, true, 0, true);
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition>
  infoIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.linkLength(r'info', 0, false, 999999, true);
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition>
  infoLengthLessThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.linkLength(r'info', 0, true, length, include);
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition>
  infoLengthGreaterThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.linkLength(r'info', length, include, 999999, true);
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition>
  infoLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.linkLength(
        r'info',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition> infoFor(
    FilterQuery<DownloadItem> q,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.link(q, r'infoFor');
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition>
  infoForLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.linkLength(r'infoFor', length, true, length, true);
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition>
  infoForIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.linkLength(r'infoFor', 0, true, 0, true);
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition>
  infoForIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.linkLength(r'infoFor', 0, false, 999999, true);
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition>
  infoForLengthLessThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.linkLength(r'infoFor', 0, true, length, include);
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition>
  infoForLengthGreaterThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.linkLength(r'infoFor', length, include, 999999, true);
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterFilterCondition>
  infoForLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.linkLength(
        r'infoFor',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }
}

extension DownloadItemQuerySortBy
    on QueryBuilder<DownloadItem, DownloadItem, QSortBy> {
  QueryBuilder<DownloadItem, DownloadItem, QAfterSortBy>
  sortByBaseIndexNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'baseIndexNumber', Sort.asc);
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterSortBy>
  sortByBaseIndexNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'baseIndexNumber', Sort.desc);
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterSortBy> sortByBaseItemType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'baseItemType', Sort.asc);
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterSortBy>
  sortByBaseItemTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'baseItemType', Sort.desc);
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterSortBy> sortById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterSortBy> sortByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterSortBy> sortByJsonItem() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'jsonItem', Sort.asc);
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterSortBy> sortByJsonItemDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'jsonItem', Sort.desc);
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterSortBy> sortByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.asc);
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterSortBy> sortByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.desc);
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterSortBy>
  sortByParentIndexNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'parentIndexNumber', Sort.asc);
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterSortBy>
  sortByParentIndexNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'parentIndexNumber', Sort.desc);
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterSortBy> sortByPath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'path', Sort.asc);
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterSortBy> sortByPathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'path', Sort.desc);
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterSortBy> sortByState() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'state', Sort.asc);
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterSortBy> sortByStateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'state', Sort.desc);
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterSortBy> sortByType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'type', Sort.asc);
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterSortBy> sortByTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'type', Sort.desc);
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterSortBy> sortByIsarViewId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'viewId', Sort.asc);
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterSortBy>
  sortByIsarViewIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'viewId', Sort.desc);
    });
  }
}

extension DownloadItemQuerySortThenBy
    on QueryBuilder<DownloadItem, DownloadItem, QSortThenBy> {
  QueryBuilder<DownloadItem, DownloadItem, QAfterSortBy>
  thenByBaseIndexNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'baseIndexNumber', Sort.asc);
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterSortBy>
  thenByBaseIndexNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'baseIndexNumber', Sort.desc);
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterSortBy> thenByBaseItemType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'baseItemType', Sort.asc);
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterSortBy>
  thenByBaseItemTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'baseItemType', Sort.desc);
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterSortBy> thenByIsarId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isarId', Sort.asc);
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterSortBy> thenByIsarIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isarId', Sort.desc);
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterSortBy> thenByJsonItem() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'jsonItem', Sort.asc);
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterSortBy> thenByJsonItemDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'jsonItem', Sort.desc);
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterSortBy> thenByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.asc);
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterSortBy> thenByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.desc);
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterSortBy>
  thenByParentIndexNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'parentIndexNumber', Sort.asc);
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterSortBy>
  thenByParentIndexNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'parentIndexNumber', Sort.desc);
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterSortBy> thenByPath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'path', Sort.asc);
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterSortBy> thenByPathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'path', Sort.desc);
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterSortBy> thenByState() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'state', Sort.asc);
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterSortBy> thenByStateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'state', Sort.desc);
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterSortBy> thenByType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'type', Sort.asc);
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterSortBy> thenByTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'type', Sort.desc);
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterSortBy> thenByIsarViewId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'viewId', Sort.asc);
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QAfterSortBy>
  thenByIsarViewIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'viewId', Sort.desc);
    });
  }
}

extension DownloadItemQueryWhereDistinct
    on QueryBuilder<DownloadItem, DownloadItem, QDistinct> {
  QueryBuilder<DownloadItem, DownloadItem, QDistinct>
  distinctByBaseIndexNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'baseIndexNumber');
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QDistinct> distinctByBaseItemType() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'baseItemType');
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QDistinct> distinctById({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'id', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QDistinct> distinctByJsonItem({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'jsonItem', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QDistinct> distinctByName({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'name', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QDistinct>
  distinctByOrderedChildren() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'orderedChildren');
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QDistinct>
  distinctByParentIndexNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'parentIndexNumber');
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QDistinct> distinctByPath({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'path', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QDistinct> distinctByState() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'state');
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QDistinct> distinctByType() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'type');
    });
  }

  QueryBuilder<DownloadItem, DownloadItem, QDistinct> distinctByIsarViewId({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'viewId', caseSensitive: caseSensitive);
    });
  }
}

extension DownloadItemQueryProperty
    on QueryBuilder<DownloadItem, DownloadItem, QQueryProperty> {
  QueryBuilder<DownloadItem, int, QQueryOperations> isarIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isarId');
    });
  }

  QueryBuilder<DownloadItem, int?, QQueryOperations> baseIndexNumberProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'baseIndexNumber');
    });
  }

  QueryBuilder<DownloadItem, BaseItemDtoType, QQueryOperations>
  baseItemTypeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'baseItemType');
    });
  }

  QueryBuilder<DownloadItem, DownloadProfile?, QQueryOperations>
  fileTranscodingProfileProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'fileTranscodingProfile');
    });
  }

  QueryBuilder<DownloadItem, String, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<DownloadItem, String?, QQueryOperations> jsonItemProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'jsonItem');
    });
  }

  QueryBuilder<DownloadItem, String, QQueryOperations> nameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'name');
    });
  }

  QueryBuilder<DownloadItem, List<int>?, QQueryOperations>
  orderedChildrenProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'orderedChildren');
    });
  }

  QueryBuilder<DownloadItem, int?, QQueryOperations>
  parentIndexNumberProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'parentIndexNumber');
    });
  }

  QueryBuilder<DownloadItem, String?, QQueryOperations> pathProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'path');
    });
  }

  QueryBuilder<DownloadItem, DownloadItemState, QQueryOperations>
  stateProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'state');
    });
  }

  QueryBuilder<DownloadItem, DownloadProfile?, QQueryOperations>
  syncTranscodingProfileProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'syncTranscodingProfile');
    });
  }

  QueryBuilder<DownloadItem, DownloadItemType, QQueryOperations>
  typeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'type');
    });
  }

  QueryBuilder<DownloadItem, DownloadProfile?, QQueryOperations>
  userTranscodingProfileProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'userTranscodingProfile');
    });
  }

  QueryBuilder<DownloadItem, String?, QQueryOperations> isarViewIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'viewId');
    });
  }
}

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetDownloadedLyricsCollection on Isar {
  IsarCollection<DownloadedLyrics> get downloadedLyrics => this.collection();
}

const DownloadedLyricsSchema = CollectionSchema(
  name: r'DownloadedLyrics',
  id: 7780135185558523971,
  properties: {
    r'jsonItem': PropertySchema(
      id: 0,
      name: r'jsonItem',
      type: IsarType.string,
    ),
  },

  estimateSize: _downloadedLyricsEstimateSize,
  serialize: _downloadedLyricsSerialize,
  deserialize: _downloadedLyricsDeserialize,
  deserializeProp: _downloadedLyricsDeserializeProp,
  idName: r'isarId',
  indexes: {},
  links: {},
  embeddedSchemas: {},

  getId: _downloadedLyricsGetId,
  getLinks: _downloadedLyricsGetLinks,
  attach: _downloadedLyricsAttach,
  version: '3.1.0+1',
);

int _downloadedLyricsEstimateSize(
  DownloadedLyrics object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  {
    final value = object.jsonItem;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  return bytesCount;
}

void _downloadedLyricsSerialize(
  DownloadedLyrics object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.jsonItem);
}

DownloadedLyrics _downloadedLyricsDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = DownloadedLyrics(
    isarId: id,
    jsonItem: reader.readStringOrNull(offsets[0]),
  );
  return object;
}

P _downloadedLyricsDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readStringOrNull(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _downloadedLyricsGetId(DownloadedLyrics object) {
  return object.isarId;
}

List<IsarLinkBase<dynamic>> _downloadedLyricsGetLinks(DownloadedLyrics object) {
  return [];
}

void _downloadedLyricsAttach(
  IsarCollection<dynamic> col,
  Id id,
  DownloadedLyrics object,
) {}

extension DownloadedLyricsQueryWhereSort
    on QueryBuilder<DownloadedLyrics, DownloadedLyrics, QWhere> {
  QueryBuilder<DownloadedLyrics, DownloadedLyrics, QAfterWhere> anyIsarId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension DownloadedLyricsQueryWhere
    on QueryBuilder<DownloadedLyrics, DownloadedLyrics, QWhereClause> {
  QueryBuilder<DownloadedLyrics, DownloadedLyrics, QAfterWhereClause>
  isarIdEqualTo(Id isarId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(lower: isarId, upper: isarId),
      );
    });
  }

  QueryBuilder<DownloadedLyrics, DownloadedLyrics, QAfterWhereClause>
  isarIdNotEqualTo(Id isarId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: isarId, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: isarId, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: isarId, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: isarId, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<DownloadedLyrics, DownloadedLyrics, QAfterWhereClause>
  isarIdGreaterThan(Id isarId, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: isarId, includeLower: include),
      );
    });
  }

  QueryBuilder<DownloadedLyrics, DownloadedLyrics, QAfterWhereClause>
  isarIdLessThan(Id isarId, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: isarId, includeUpper: include),
      );
    });
  }

  QueryBuilder<DownloadedLyrics, DownloadedLyrics, QAfterWhereClause>
  isarIdBetween(
    Id lowerIsarId,
    Id upperIsarId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(
          lower: lowerIsarId,
          includeLower: includeLower,
          upper: upperIsarId,
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension DownloadedLyricsQueryFilter
    on QueryBuilder<DownloadedLyrics, DownloadedLyrics, QFilterCondition> {
  QueryBuilder<DownloadedLyrics, DownloadedLyrics, QAfterFilterCondition>
  isarIdEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'isarId', value: value),
      );
    });
  }

  QueryBuilder<DownloadedLyrics, DownloadedLyrics, QAfterFilterCondition>
  isarIdGreaterThan(Id value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'isarId',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<DownloadedLyrics, DownloadedLyrics, QAfterFilterCondition>
  isarIdLessThan(Id value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'isarId',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<DownloadedLyrics, DownloadedLyrics, QAfterFilterCondition>
  isarIdBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'isarId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<DownloadedLyrics, DownloadedLyrics, QAfterFilterCondition>
  jsonItemIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'jsonItem'),
      );
    });
  }

  QueryBuilder<DownloadedLyrics, DownloadedLyrics, QAfterFilterCondition>
  jsonItemIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'jsonItem'),
      );
    });
  }

  QueryBuilder<DownloadedLyrics, DownloadedLyrics, QAfterFilterCondition>
  jsonItemEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'jsonItem',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DownloadedLyrics, DownloadedLyrics, QAfterFilterCondition>
  jsonItemGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'jsonItem',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DownloadedLyrics, DownloadedLyrics, QAfterFilterCondition>
  jsonItemLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'jsonItem',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DownloadedLyrics, DownloadedLyrics, QAfterFilterCondition>
  jsonItemBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'jsonItem',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DownloadedLyrics, DownloadedLyrics, QAfterFilterCondition>
  jsonItemStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'jsonItem',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DownloadedLyrics, DownloadedLyrics, QAfterFilterCondition>
  jsonItemEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'jsonItem',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DownloadedLyrics, DownloadedLyrics, QAfterFilterCondition>
  jsonItemContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'jsonItem',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DownloadedLyrics, DownloadedLyrics, QAfterFilterCondition>
  jsonItemMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'jsonItem',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DownloadedLyrics, DownloadedLyrics, QAfterFilterCondition>
  jsonItemIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'jsonItem', value: ''),
      );
    });
  }

  QueryBuilder<DownloadedLyrics, DownloadedLyrics, QAfterFilterCondition>
  jsonItemIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'jsonItem', value: ''),
      );
    });
  }
}

extension DownloadedLyricsQueryObject
    on QueryBuilder<DownloadedLyrics, DownloadedLyrics, QFilterCondition> {}

extension DownloadedLyricsQueryLinks
    on QueryBuilder<DownloadedLyrics, DownloadedLyrics, QFilterCondition> {}

extension DownloadedLyricsQuerySortBy
    on QueryBuilder<DownloadedLyrics, DownloadedLyrics, QSortBy> {
  QueryBuilder<DownloadedLyrics, DownloadedLyrics, QAfterSortBy>
  sortByJsonItem() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'jsonItem', Sort.asc);
    });
  }

  QueryBuilder<DownloadedLyrics, DownloadedLyrics, QAfterSortBy>
  sortByJsonItemDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'jsonItem', Sort.desc);
    });
  }
}

extension DownloadedLyricsQuerySortThenBy
    on QueryBuilder<DownloadedLyrics, DownloadedLyrics, QSortThenBy> {
  QueryBuilder<DownloadedLyrics, DownloadedLyrics, QAfterSortBy>
  thenByIsarId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isarId', Sort.asc);
    });
  }

  QueryBuilder<DownloadedLyrics, DownloadedLyrics, QAfterSortBy>
  thenByIsarIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isarId', Sort.desc);
    });
  }

  QueryBuilder<DownloadedLyrics, DownloadedLyrics, QAfterSortBy>
  thenByJsonItem() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'jsonItem', Sort.asc);
    });
  }

  QueryBuilder<DownloadedLyrics, DownloadedLyrics, QAfterSortBy>
  thenByJsonItemDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'jsonItem', Sort.desc);
    });
  }
}

extension DownloadedLyricsQueryWhereDistinct
    on QueryBuilder<DownloadedLyrics, DownloadedLyrics, QDistinct> {
  QueryBuilder<DownloadedLyrics, DownloadedLyrics, QDistinct>
  distinctByJsonItem({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'jsonItem', caseSensitive: caseSensitive);
    });
  }
}

extension DownloadedLyricsQueryProperty
    on QueryBuilder<DownloadedLyrics, DownloadedLyrics, QQueryProperty> {
  QueryBuilder<DownloadedLyrics, int, QQueryOperations> isarIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isarId');
    });
  }

  QueryBuilder<DownloadedLyrics, String?, QQueryOperations> jsonItemProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'jsonItem');
    });
  }
}

// **************************************************************************
// IsarEmbeddedGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

const DownloadProfileSchema = Schema(
  name: r'DownloadProfile',
  id: -2481428030095603358,
  properties: {
    r'codec': PropertySchema(
      id: 0,
      name: r'codec',
      type: IsarType.byte,
      enumMap: _DownloadProfilecodecEnumValueMap,
    ),
    r'downloadLocationId': PropertySchema(
      id: 1,
      name: r'downloadLocationId',
      type: IsarType.string,
    ),
    r'stereoBitrate': PropertySchema(
      id: 2,
      name: r'stereoBitrate',
      type: IsarType.long,
    ),
  },

  estimateSize: _downloadProfileEstimateSize,
  serialize: _downloadProfileSerialize,
  deserialize: _downloadProfileDeserialize,
  deserializeProp: _downloadProfileDeserializeProp,
);

int _downloadProfileEstimateSize(
  DownloadProfile object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  {
    final value = object.downloadLocationId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  return bytesCount;
}

void _downloadProfileSerialize(
  DownloadProfile object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeByte(offsets[0], object.codec.index);
  writer.writeString(offsets[1], object.downloadLocationId);
  writer.writeLong(offsets[2], object.stereoBitrate);
}

DownloadProfile _downloadProfileDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = DownloadProfile(
    downloadLocationId: reader.readStringOrNull(offsets[1]),
  );
  object.codec =
      _DownloadProfilecodecValueEnumMap[reader.readByteOrNull(offsets[0])] ??
      FinampTranscodingCodec.aac;
  object.stereoBitrate = reader.readLong(offsets[2]);
  return object;
}

P _downloadProfileDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (_DownloadProfilecodecValueEnumMap[reader.readByteOrNull(
                offset,
              )] ??
              FinampTranscodingCodec.aac)
          as P;
    case 1:
      return (reader.readStringOrNull(offset)) as P;
    case 2:
      return (reader.readLong(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

const _DownloadProfilecodecEnumValueMap = {
  'aac': 0,
  'mp3': 1,
  'opus': 2,
  'original': 3,
};
const _DownloadProfilecodecValueEnumMap = {
  0: FinampTranscodingCodec.aac,
  1: FinampTranscodingCodec.mp3,
  2: FinampTranscodingCodec.opus,
  3: FinampTranscodingCodec.original,
};

extension DownloadProfileQueryFilter
    on QueryBuilder<DownloadProfile, DownloadProfile, QFilterCondition> {
  QueryBuilder<DownloadProfile, DownloadProfile, QAfterFilterCondition>
  codecEqualTo(FinampTranscodingCodec value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'codec', value: value),
      );
    });
  }

  QueryBuilder<DownloadProfile, DownloadProfile, QAfterFilterCondition>
  codecGreaterThan(FinampTranscodingCodec value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'codec',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<DownloadProfile, DownloadProfile, QAfterFilterCondition>
  codecLessThan(FinampTranscodingCodec value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'codec',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<DownloadProfile, DownloadProfile, QAfterFilterCondition>
  codecBetween(
    FinampTranscodingCodec lower,
    FinampTranscodingCodec upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'codec',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<DownloadProfile, DownloadProfile, QAfterFilterCondition>
  downloadLocationIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'downloadLocationId'),
      );
    });
  }

  QueryBuilder<DownloadProfile, DownloadProfile, QAfterFilterCondition>
  downloadLocationIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'downloadLocationId'),
      );
    });
  }

  QueryBuilder<DownloadProfile, DownloadProfile, QAfterFilterCondition>
  downloadLocationIdEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'downloadLocationId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DownloadProfile, DownloadProfile, QAfterFilterCondition>
  downloadLocationIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'downloadLocationId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DownloadProfile, DownloadProfile, QAfterFilterCondition>
  downloadLocationIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'downloadLocationId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DownloadProfile, DownloadProfile, QAfterFilterCondition>
  downloadLocationIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'downloadLocationId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DownloadProfile, DownloadProfile, QAfterFilterCondition>
  downloadLocationIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'downloadLocationId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DownloadProfile, DownloadProfile, QAfterFilterCondition>
  downloadLocationIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'downloadLocationId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DownloadProfile, DownloadProfile, QAfterFilterCondition>
  downloadLocationIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'downloadLocationId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DownloadProfile, DownloadProfile, QAfterFilterCondition>
  downloadLocationIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'downloadLocationId',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<DownloadProfile, DownloadProfile, QAfterFilterCondition>
  downloadLocationIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'downloadLocationId', value: ''),
      );
    });
  }

  QueryBuilder<DownloadProfile, DownloadProfile, QAfterFilterCondition>
  downloadLocationIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'downloadLocationId', value: ''),
      );
    });
  }

  QueryBuilder<DownloadProfile, DownloadProfile, QAfterFilterCondition>
  stereoBitrateEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'stereoBitrate', value: value),
      );
    });
  }

  QueryBuilder<DownloadProfile, DownloadProfile, QAfterFilterCondition>
  stereoBitrateGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'stereoBitrate',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<DownloadProfile, DownloadProfile, QAfterFilterCondition>
  stereoBitrateLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'stereoBitrate',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<DownloadProfile, DownloadProfile, QAfterFilterCondition>
  stereoBitrateBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'stereoBitrate',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension DownloadProfileQueryObject
    on QueryBuilder<DownloadProfile, DownloadProfile, QFilterCondition> {}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DownloadedTrack _$DownloadedTrackFromJson(Map json) => DownloadedTrack(
  track: BaseItemDto.fromJson(Map<String, dynamic>.from(json['track'] as Map)),
  mediaSourceInfo: MediaSourceInfo.fromJson(
    Map<String, dynamic>.from(json['mediaSourceInfo'] as Map),
  ),
  downloadId: json['downloadId'] as String,
  requiredBy: (json['requiredBy'] as List<dynamic>)
      .map((e) => e as String)
      .toList(),
  path: json['path'] as String,
  useHumanReadableNames: json['useHumanReadableNames'] as bool,
  viewId: json['viewId'] as String,
  isPathRelative: json['isPathRelative'] as bool? ?? true,
  downloadLocationId: json['downloadLocationId'] as String?,
);

Map<String, dynamic> _$DownloadedTrackToJson(DownloadedTrack instance) =>
    <String, dynamic>{
      'track': instance.track.toJson(),
      'mediaSourceInfo': instance.mediaSourceInfo.toJson(),
      'downloadId': instance.downloadId,
      'requiredBy': instance.requiredBy,
      'path': instance.path,
      'useHumanReadableNames': instance.useHumanReadableNames,
      'viewId': instance.viewId,
      'isPathRelative': instance.isPathRelative,
      'downloadLocationId': instance.downloadLocationId,
    };

DownloadStub _$DownloadStubFromJson(Map json) => DownloadStub._build(
  id: json['Id'] as String,
  type: $enumDecode(_$DownloadItemTypeEnumMap, json['Type']),
  jsonItem: json['JsonItem'] as String?,
  isarId: (json['IsarId'] as num).toInt(),
  name: json['Name'] as String,
  baseItemType: $enumDecode(_$BaseItemDtoTypeEnumMap, json['BaseItemType']),
);

Map<String, dynamic> _$DownloadStubToJson(DownloadStub instance) =>
    <String, dynamic>{
      'IsarId': instance.isarId,
      'Id': instance.id,
      'Name': instance.name,
      'BaseItemType': _$BaseItemDtoTypeEnumMap[instance.baseItemType]!,
      'Type': _$DownloadItemTypeEnumMap[instance.type]!,
      'JsonItem': instance.jsonItem,
    };

const _$DownloadItemTypeEnumMap = {
  DownloadItemType.collection: 'collection',
  DownloadItemType.track: 'track',
  DownloadItemType.image: 'image',
  DownloadItemType.anchor: 'anchor',
  DownloadItemType.finampCollection: 'finampCollection',
};

const _$BaseItemDtoTypeEnumMap = {
  BaseItemDtoType.noItem: 'noItem',
  BaseItemDtoType.album: 'album',
  BaseItemDtoType.artist: 'artist',
  BaseItemDtoType.playlist: 'playlist',
  BaseItemDtoType.genre: 'genre',
  BaseItemDtoType.track: 'track',
  BaseItemDtoType.library: 'library',
  BaseItemDtoType.folder: 'folder',
  BaseItemDtoType.musicVideo: 'musicVideo',
  BaseItemDtoType.audioBook: 'audioBook',
  BaseItemDtoType.tvEpisode: 'tvEpisode',
  BaseItemDtoType.video: 'video',
  BaseItemDtoType.movie: 'movie',
  BaseItemDtoType.trailer: 'trailer',
  BaseItemDtoType.unknown: 'unknown',
};

FinampCollection _$FinampCollectionFromJson(Map json) => FinampCollection(
  type: $enumDecode(_$FinampCollectionTypeEnumMap, json['Type']),
  library: json['Library'] == null
      ? null
      : BaseItemDto.fromJson(Map<String, dynamic>.from(json['Library'] as Map)),
  item: json['Item'] == null
      ? null
      : BaseItemDto.fromJson(Map<String, dynamic>.from(json['Item'] as Map)),
);

Map<String, dynamic> _$FinampCollectionToJson(FinampCollection instance) =>
    <String, dynamic>{
      'Type': _$FinampCollectionTypeEnumMap[instance.type]!,
      if (instance.library?.toJson() case final value?) 'Library': value,
      if (instance.item?.toJson() case final value?) 'Item': value,
    };

const _$FinampCollectionTypeEnumMap = {
  FinampCollectionType.favorites: 'favorites',
  FinampCollectionType.allPlaylists: 'allPlaylists',
  FinampCollectionType.latest5Albums: 'latest5Albums',
  FinampCollectionType.libraryImages: 'libraryImages',
  FinampCollectionType.allPlaylistsMetadata: 'allPlaylistsMetadata',
  FinampCollectionType.collectionWithLibraryFilter:
      'collectionWithLibraryFilter',
};

MediaItemId _$MediaItemIdFromJson(Map<String, dynamic> json) => MediaItemId(
  contentType: $enumDecode(_$TabContentTypeEnumMap, json['contentType']),
  parentType: $enumDecode(_$MediaItemParentTypeEnumMap, json['parentType']),
  itemId: _$JsonConverterFromJson<String, BaseItemId>(
    json['itemId'],
    const BaseItemIdConverter().fromJson,
  ),
  parentId: _$JsonConverterFromJson<String, BaseItemId>(
    json['parentId'],
    const BaseItemIdConverter().fromJson,
  ),
);

Map<String, dynamic> _$MediaItemIdToJson(MediaItemId instance) =>
    <String, dynamic>{
      'contentType': _$TabContentTypeEnumMap[instance.contentType]!,
      'parentType': _$MediaItemParentTypeEnumMap[instance.parentType]!,
      'itemId': _$JsonConverterToJson<String, BaseItemId>(
        instance.itemId,
        const BaseItemIdConverter().toJson,
      ),
      'parentId': _$JsonConverterToJson<String, BaseItemId>(
        instance.parentId,
        const BaseItemIdConverter().toJson,
      ),
    };

const _$TabContentTypeEnumMap = {
  TabContentType.albums: 'albums',
  TabContentType.artists: 'artists',
  TabContentType.playlists: 'playlists',
  TabContentType.genres: 'genres',
  TabContentType.tracks: 'tracks',
};

const _$MediaItemParentTypeEnumMap = {
  MediaItemParentType.collection: 'collection',
  MediaItemParentType.rootCollection: 'rootCollection',
  MediaItemParentType.instantMix: 'instantMix',
};

Value? _$JsonConverterFromJson<Json, Value>(
  Object? json,
  Value? Function(Json json) fromJson,
) => json == null ? null : fromJson(json as Json);

Json? _$JsonConverterToJson<Json, Value>(
  Value? value,
  Json? Function(Value value) toJson,
) => value == null ? null : toJson(value);

FinampFeatureChipsConfiguration _$FinampFeatureChipsConfigurationFromJson(
  Map<String, dynamic> json,
) => FinampFeatureChipsConfiguration(
  enabled: json['enabled'] as bool,
  features: (json['features'] as List<dynamic>)
      .map((e) => $enumDecode(_$FinampFeatureChipTypeEnumMap, e))
      .toList(),
);

Map<String, dynamic> _$FinampFeatureChipsConfigurationToJson(
  FinampFeatureChipsConfiguration instance,
) => <String, dynamic>{
  'enabled': instance.enabled,
  'features': instance.features
      .map((e) => _$FinampFeatureChipTypeEnumMap[e]!)
      .toList(),
};

const _$FinampFeatureChipTypeEnumMap = {
  FinampFeatureChipType.playCount: 'playCount',
  FinampFeatureChipType.additionalPeople: 'additionalPeople',
  FinampFeatureChipType.playbackMode: 'playbackMode',
  FinampFeatureChipType.codec: 'codec',
  FinampFeatureChipType.bitRate: 'bitRate',
  FinampFeatureChipType.bitDepth: 'bitDepth',
  FinampFeatureChipType.size: 'size',
  FinampFeatureChipType.normalizationGain: 'normalizationGain',
  FinampFeatureChipType.sampleRate: 'sampleRate',
  FinampFeatureChipType.explicit: 'explicit',
};

FinampOutputRoute _$FinampOutputRouteFromJson(Map<String, dynamic> json) =>
    FinampOutputRoute(
      name: json['name'] as String,
      connectionState: (json['connectionState'] as num).toInt(),
      isSystemRoute: json['isSystemRoute'] as bool,
      isDefault: json['isDefault'] as bool,
      isDeviceSpeaker: json['isDeviceSpeaker'] as bool,
      isBluetooth: json['isBluetooth'] as bool,
      volume: (json['volume'] as num).toDouble(),
      providerPackageName: json['providerPackageName'] as String,
      isSelected: json['isSelected'] as bool,
      deviceType: (json['deviceType'] as num).toInt(),
      description: json['description'] as String?,
      extras: json['extras'],
      iconUri: json['iconUri'] as String?,
    );

Map<String, dynamic> _$FinampOutputRouteToJson(FinampOutputRoute instance) =>
    <String, dynamic>{
      'name': instance.name,
      'connectionState': instance.connectionState,
      'isSystemRoute': instance.isSystemRoute,
      'isDefault': instance.isDefault,
      'isDeviceSpeaker': instance.isDeviceSpeaker,
      'isBluetooth': instance.isBluetooth,
      'volume': instance.volume,
      'providerPackageName': instance.providerPackageName,
      'isSelected': instance.isSelected,
      'deviceType': instance.deviceType,
      'description': instance.description,
      'extras': instance.extras,
      'iconUri': instance.iconUri,
    };
