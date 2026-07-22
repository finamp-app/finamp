import 'package:collection/collection.dart';
import 'package:finamp/components/confirmation_prompt_dialog.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/services/finamp_user_helper.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:rxdart/rxdart.dart';

import '../models/finamp_models.dart';
import '../models/jellyfin_models.dart';

part 'finamp_settings_helper.g.dart';

@Riverpod(keepAlive: true)
Stream<FinampSettings> finampSettings(Ref ref) {
  return Hive.box<FinampSettings>("FinampSettings")
      .watch()
      .map<FinampSettings>((event) => event.value! as FinampSettings)
      .startWith(FinampSettingsHelper.finampSettings);
}

class FinampSettingsHelper {
  static ValueListenable<Box<FinampSettings>> get finampSettingsListener =>
      Hive.box<FinampSettings>("FinampSettings").listenable(keys: ["FinampSettings"]);

  // This shouldn't be null as FinampSettings is created on startup.
  // This decision will probably come back to haunt me later.
  static FinampSettings get finampSettings => Hive.box<FinampSettings>("FinampSettings").get("FinampSettings")!;

  /// Deletes the downloadLocation at the given index.
  static void deleteDownloadLocation(String id) {
    FinampSettings finampSettingsTemp = finampSettings;
    finampSettingsTemp.downloadLocationsMap.remove(id);
    Hive.box<FinampSettings>("FinampSettings").put("FinampSettings", finampSettingsTemp);
  }

  /// Add a new download location to FinampSettings
  static void addDownloadLocation(DownloadLocation downloadLocation) async {
    FinampSettings finampSettingsTemp = finampSettings;
    finampSettingsTemp.downloadLocationsMap[downloadLocation.id] = downloadLocation;
    await Hive.box<FinampSettings>("FinampSettings").put("FinampSettings", finampSettingsTemp);
  }

  static void overwriteFinampSettings(FinampSettings newFinampSettings) {
    Hive.box<FinampSettings>("FinampSettings").put("FinampSettings", newFinampSettings);
  }

  static void resetTabsSettings() {
    FinampSettings finampSettingsTemp = finampSettings;
    finampSettingsTemp.tabOrder = DefaultSettings.tabOrder;
    finampSettingsTemp.showTabs = Map.fromEntries(DefaultSettings.tabOrder.map((e) => MapEntry(e, true)));
    Hive.box<FinampSettings>("FinampSettings").put("FinampSettings", finampSettingsTemp);
  }

  static void resetCustomizationSettings() {
    FinampSettings finampSettingsTemp = finampSettings;

    finampSettingsTemp.playbackSpeedVisibility = DefaultSettings.playbackSpeedVisibility;
    finampSettingsTemp.showStopButtonOnMediaNotification = DefaultSettings.showStopButtonOnMediaNotification;
    finampSettingsTemp.showSeekControlsOnMediaNotification = DefaultSettings.showSeekControlsOnMediaNotification;
    finampSettingsTemp.oneLineMarqueeTextButton = DefaultSettings.oneLineMarqueeTextButton;
    finampSettingsTemp.tileAdditionalInfoType = DefaultSettings.tileAdditionalInfoType;

    Hive.box<FinampSettings>("FinampSettings").put("FinampSettings", finampSettingsTemp);
  }

  static void resetPlayerScreenSettings() {
    FinampSettings finampSettingsTemp = finampSettings;

    finampSettingsTemp.featureChipsConfiguration = DefaultSettings.featureChipsConfiguration;
    finampSettingsTemp.playerScreenCoverMinimumPadding = DefaultSettings.playerScreenCoverMinimumPadding;
    finampSettingsTemp.suppressPlayerPadding = DefaultSettings.suppressPlayerPadding;
    finampSettingsTemp.prioritizeCoverFactor = DefaultSettings.prioritizeCoverFactor;
    finampSettingsTemp.hidePlayerBottomActions = DefaultSettings.hidePlayerBottomActions;

    Hive.box<FinampSettings>("FinampSettings").put("FinampSettings", finampSettingsTemp);
  }

  static void resetLyricsSettings() {
    FinampSettings finampSettingsTemp = finampSettings;

    finampSettingsTemp.showLyricsTimestamps = DefaultSettings.showLyricsTimestamps;
    finampSettingsTemp.showLyricsScreenAlbumPrelude = DefaultSettings.showLyricsScreenAlbumPrelude;
    finampSettingsTemp.lyricsAlignment = DefaultSettings.lyricsAlignment;
    finampSettingsTemp.lyricsFontSize = DefaultSettings.lyricsFontSize;

    Hive.box<FinampSettings>("FinampSettings").put("FinampSettings", finampSettingsTemp);
  }

  static void resetAlbumSettings() {
    FinampSettings finampSettingsTemp = finampSettings;

    finampSettingsTemp.showCoversOnAlbumScreen = DefaultSettings.showCoversOnAlbumScreen;

    Hive.box<FinampSettings>("FinampSettings").put("FinampSettings", finampSettingsTemp);
  }

  static void resetArtistSettings() {
    FinampSettings finampSettingsTemp = finampSettings;

    finampSettingsTemp.artistItemSectionsOrder = DefaultSettings.artistItemSectionsOrder;
    finampSettingsTemp.showArtistsTracksSection = DefaultSettings.showArtistsTracksSection;
    finampSettingsTemp.artistItemSectionFilterChipOrder = DefaultSettings.artistItemSectionFilterChipOrder;

    Hive.box<FinampSettings>("FinampSettings").put("FinampSettings", finampSettingsTemp);
  }

  static void resetGenreSettings() {
    FinampSettings finampSettingsTemp = finampSettings;

    finampSettingsTemp.genreItemSectionsOrder = DefaultSettings.genreItemSectionsOrder;
    finampSettingsTemp.genreItemSectionFilterChipOrder = DefaultSettings.genreItemSectionFilterChipOrder;
    finampSettingsTemp.genreFilterArtistScreens = DefaultSettings.genreFilterArtistScreens;
    finampSettingsTemp.genreFilterPlaylists = DefaultSettings.genreFilterPlaylists;
    finampSettingsTemp.genreListsInheritSorting = DefaultSettings.genreListsInheritSorting;

    Hive.box<FinampSettings>("FinampSettings").put("FinampSettings", finampSettingsTemp);
  }

  static void resetLayoutSettings() {
    FinampSettings finampSettingsTemp = finampSettings;

    FinampSetters.setThemeMode(DefaultSettings.themeMode);
    FinampSetters.setAmoledTheme(DefaultSettings.amoledTheme);
    FinampSetters.setAccentColor(DefaultSettings.accentColor);
    FinampSetters.setSystemAccentColor(DefaultSettings.accentColor);
    FinampSetters.setUseSystemAccentColor(DefaultSettings.useSystemAccentColor);
    FinampSetters.setContentViewType(DefaultSettings.contentViewType);
    finampSettingsTemp.gridImageSize = DefaultSettings.gridImageSize;
    finampSettingsTemp.homeScreenImageSize = DefaultSettings.homeScreenImageSize;
    finampSettingsTemp.showTextOnGridView = DefaultSettings.showTextOnGridView;
    FinampSetters.setUseCoverAsBackground(DefaultSettings.useCoverAsBackground);
    finampSettingsTemp.showArtistChipImage = DefaultSettings.showArtistChipImage;
    finampSettingsTemp.allowSplitScreen = DefaultSettings.allowSplitScreen;
    finampSettingsTemp.showProgressOnNowPlayingBar = DefaultSettings.showProgressOnNowPlayingBar;
    finampSettingsTemp.autoSwitchItemCurationType = DefaultSettings.autoSwitchItemCurationType;
    finampSettingsTemp.useMonochromeIcon = DefaultSettings.useMonochromeIcon;

    Hive.box<FinampSettings>("FinampSettings").put("FinampSettings", finampSettingsTemp);
  }

  static void resetHomeScreenSettings() {
    FinampSettings finampSettingsTemp = finampSettings;

    finampSettingsTemp.homeScreenConfiguration = DefaultSettings.homeScreenConfiguration;

    Hive.box<FinampSettings>("FinampSettings").put("FinampSettings", finampSettingsTemp);
  }

  static void resetTranscodingSettings() {
    FinampSettings finampSettingsTemp = finampSettings;

    finampSettingsTemp.shouldTranscode = DefaultSettings.shouldTranscode;
    FinampSetters.setTranscodeBitrate(DefaultSettings.transcodeBitrate);
    finampSettingsTemp.transcodingStreamingFormat = DefaultSettings.transcodingStreamingFormat;
    finampSettingsTemp.shouldTranscodeDownloads = DefaultSettings.shouldTranscodeDownloads;
    finampSettingsTemp.downloadTranscodingCodec =
        FinampTranscodingCodec.opus; // starts uninitilized, idk what value this should be
    finampSettingsTemp.downloadTranscodeBitrate = 128000; // starts uninitilized, idk what value this should be
    finampSettingsTemp.multichannelHandlingSetting = DefaultSettings.multichannelHandlingSetting;

    Hive.box<FinampSettings>("FinampSettings").put("FinampSettings", finampSettingsTemp);
  }

  static void resetDownloadSettings() {
    FinampSettings finampSettingsTemp = finampSettings;

    finampSettingsTemp.requireWifiForDownloads = DefaultSettings.requireWifiForDownloads;
    finampSettingsTemp.trackOfflineFavorites = DefaultSettings.trackOfflineFavorites;
    finampSettingsTemp.resyncOnStartup = DefaultSettings.resyncOnStartup;
    finampSettingsTemp.preferQuickSyncs = DefaultSettings.preferQuickSyncs;
    finampSettingsTemp.shouldRedownloadTranscodes = DefaultSettings.shouldRedownloadTranscodes;
    finampSettingsTemp.showDownloadsWithUnknownLibrary = DefaultSettings.showDownloadsWithUnknownLibrary;
    finampSettingsTemp.downloadWorkers = DefaultSettings.downloadWorkers;
    finampSettingsTemp.maxConcurrentDownloads = DefaultSettings.maxConcurrentDownloads;
    finampSettingsTemp.downloadSizeWarningCutoff = DefaultSettings.downloadSizeWarningCutoff;

    Hive.box<FinampSettings>("FinampSettings").put("FinampSettings", finampSettingsTemp);
  }

  static void resetAudioServiceSettings() {
    FinampSetters.setAndroidStopForegroundOnPause(DefaultSettings.androidStopForegroundOnPause);
    FinampSetters.setTrackShuffleItemCount(DefaultSettings.trackShuffleItemCount);
    FinampSetters.setAudioFadeInDuration(DefaultSettings.audioFadeInDuration);
    FinampSetters.setAudioFadeOutDuration(DefaultSettings.audioFadeOutDuration);
    FinampSetters.setBufferSizeMegabytes(DefaultSettings.bufferSizeMegabytes);
    FinampSetters.setBufferDuration(Duration(seconds: DefaultSettings.bufferDurationSeconds));
    FinampSetters.setBufferDisableSizeConstraints(DefaultSettings.bufferDisableSizeConstraints);
    FinampSetters.setAutoloadLastQueueOnStartup(DefaultSettings.autoLoadLastQueueOnStartup);
    FinampSetters.setAutoReloadQueue(DefaultSettings.autoReloadQueue);
    FinampSetters.setClearQueueOnStopEvent(DefaultSettings.clearQueueOnStopEvent);
    FinampSetters.setAutoplayRestoredQueue(DefaultSettings.autoplayRestoredQueue);
    FinampSetters.setDuckOnAudioInterruption(DefaultSettings.duckOnAudioInterruption);
    FinampSetters.setForceAudioOffloadingOnAndroid(DefaultSettings.forceAudioOffloadingOnAndroid);
  }

  static void resetPlaybackReportingSettings() {
    FinampSetters.setPeriodicPlaybackSessionUpdateFrequencySeconds(
      DefaultSettings.periodicPlaybackSessionUpdateFrequencySeconds,
    ); // DOES NOT update UI
    FinampSetters.setEnablePlayon(DefaultSettings.enablePlayon);
    FinampSetters.setReportQueueToServer(DefaultSettings.reportQueueToServer);
    FinampSetters.setPlayOnStaleDelay(DefaultSettings.playOnStaleDelay);
    FinampSetters.setAudioFadeInDuration(DefaultSettings.audioFadeInDuration);
    FinampSetters.setAudioFadeOutDuration(DefaultSettings.audioFadeOutDuration);
    FinampSetters.setPlayOnReconnectionDelay(DefaultSettings.playOnReconnectionDelay);
    FinampSetters.setRpcEnabled(DefaultSettings.rpcEnabled);
    FinampSetters.setRpcIcon(DefaultSettings.rpcIcon);
  }

  static void resetNormalizationSettings() {
    FinampSettings finampSettingsTemp = finampSettings;

    finampSettingsTemp.volumeNormalizationActive = DefaultSettings.volumeNormalizationActive;
    FinampSetters.setVolumeNormalizationIOSBaseGain(
      DefaultSettings.volumeNormalizationIOSBaseGain,
    ); // DOES NOT update UI
    finampSettingsTemp.volumeNormalizationMode = DefaultSettings.volumeNormalizationMode;

    Hive.box<FinampSettings>("FinampSettings").put("FinampSettings", finampSettingsTemp);
  }

  static void resetInteractionsSettings() {
    FinampSettings finampSettingsTemp = finampSettings;

    finampSettingsTemp.itemSwipeActionLeftToRight = DefaultSettings.itemSwipeActionLeftToRight;
    finampSettingsTemp.itemSwipeActionRightToLeft = DefaultSettings.itemSwipeActionRightToLeft;
    finampSettingsTemp.startInstantMixForIndividualTracks = DefaultSettings.startInstantMixForIndividualTracks;
    finampSettingsTemp.applyFilterOnGenreChipTap = DefaultSettings.applyFilterOnGenreChipTap;
    FinampSetters.setAutoExpandPlayerScreen(DefaultSettings.autoExpandPlayerScreen);
    FinampSetters.setShowFastScroller(DefaultSettings.showFastScroller);
    FinampSetters.setKeepScreenOnOption(DefaultSettings.keepScreenOnOption);
    FinampSetters.setKeepScreenOnWhilePluggedIn(DefaultSettings.keepScreenOnWhilePluggedIn);
    FinampSetters.setPreferAddingToFavoritesOverPlaylists(DefaultSettings.preferAddingToFavoritesOverPlaylists);
    FinampSetters.setPreferNextUpPrepending(DefaultSettings.preferNextUpPrepending);
    FinampSetters.setRememberLastUsedPlaybackActionRowPage(DefaultSettings.rememberLastUsedPlaybackActionRowPage);
    FinampSetters.setPreviousTracksPersistenceMode(DefaultSettings.previousTracksPersistenceMode);

    Hive.box<FinampSettings>("FinampSettings").put("FinampSettings", finampSettingsTemp);
  }

  static void resetNetworkSettings() {
    GetIt.instance<FinampUserHelper>().currentUser?.update(
      newIsLocal: DefaultSettings.isLocal,
      newLocalAddress: DefaultSettings.localNetworkAddress,
      newPreferLocalNetwork: DefaultSettings.preferLocalNetwork,
    );
    FinampSetters.setAutoOffline(DefaultSettings.autoOffline);
  }

  static void resetAccessibilitySettings() {
    FinampSetters.setUseHighContrastColors(DefaultSettings.useHighContrastColors);
    FinampSetters.setDisableGesture(DefaultSettings.disableGesture);
    FinampSetters.setEnableVibration(DefaultSettings.enableVibration);
  }

  static void resetLocale() {
    FinampSetters.setLocale(DefaultSettings.locale);
  }

  static void resetAllSettings() {
    resetTranscodingSettings();
    resetDownloadSettings();
    resetAudioServiceSettings();
    resetNormalizationSettings();
    resetInteractionsSettings();
    resetPlaybackReportingSettings();
    resetLayoutSettings();
    resetCustomizationSettings();
    resetPlayerScreenSettings();
    resetLyricsSettings();
    resetAlbumSettings();
    resetArtistSettings();
    resetGenreSettings();
    resetTabsSettings();
    resetNetworkSettings();
    resetLocale();
  }

  static IconButton makeSettingsResetButtonWithDialog(
    BuildContext context,
    void Function() resetFunction, {
    bool isGlobal = false,
  }) {
    return IconButton(
      onPressed: () async {
        await showDialog(
          context: context,
          builder: (context) => ConfirmationPromptDialog(
            promptText: isGlobal
                ? AppLocalizations.of(context)!.resetSettingsPromptGlobal
                : AppLocalizations.of(context)!.resetSettingsPromptLocal,
            confirmButtonText: isGlobal
                ? AppLocalizations.of(context)!.resetSettingsPromptGlobalConfirm
                : AppLocalizations.of(context)!.reset,
            onConfirmed: resetFunction,
          ),
        );
      },
      icon: const Icon(Icons.refresh),
      tooltip: AppLocalizations.of(context)!.resetToDefaults,
    );
  }
}

extension ApplyIfNonNull<K, V> on K Function(V) {
  void ifNonNull(V? value) {
    if (value != null) {
      this(value);
    }
  }
}
