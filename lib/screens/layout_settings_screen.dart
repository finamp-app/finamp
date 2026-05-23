import 'dart:io';
import 'dart:math';

import 'package:finamp/components/LayoutSettingsScreen/automatic_accent_color_selector.dart';
import 'package:finamp/components/LayoutSettingsScreen/use_monochrome_icon.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/screens/album_settings_screen.dart';
import 'package:finamp/screens/artist_settings_screen.dart';
import 'package:finamp/screens/customization_settings_screen.dart';
import 'package:finamp/screens/genre_settings_screen.dart';
import 'package:finamp/screens/lyrics_settings_screen.dart';
import 'package:finamp/screens/player_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../components/LayoutSettingsScreen/accent_color_selector.dart';
import '../components/LayoutSettingsScreen/amoled_theme.dart';
import '../components/LayoutSettingsScreen/content_view_type_dropdown_list_tile.dart';
import '../components/LayoutSettingsScreen/show_artist_chip_image_toggle.dart';
import '../components/LayoutSettingsScreen/show_text_on_grid_view_selector.dart';
import '../components/LayoutSettingsScreen/theme_selector.dart';
import '../components/LayoutSettingsScreen/use_cover_as_background_toggle.dart';
import '../components/finamp_app_bar_back_button.dart';
import '../extensions/localizations.dart';
import '../services/finamp_settings_helper.dart';
import 'tabs_settings_screen.dart';

class LayoutSettingsScreen extends ConsumerStatefulWidget {
  const LayoutSettingsScreen({super.key});
  static const routeName = "/settings/layout";
  @override
  ConsumerState<LayoutSettingsScreen> createState() => _LayoutSettingsScreenState();
}

class _LayoutSettingsScreenState extends ConsumerState<LayoutSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.layoutAndTheme),
        leading: FinampAppBarBackButton(),
        actions: [
          FinampSettingsHelper.makeSettingsResetButtonWithDialog(context, FinampSettingsHelper.resetLayoutSettings),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 200.0),
        children: [
          ListTile(
            leading: const Icon(TablerIcons.sparkles),
            title: Text(AppLocalizations.of(context)!.customizationSettingsTitle),
            onTap: () => Navigator.of(context).pushNamed(CustomizationSettingsScreen.routeName),
          ),
          ListTile(
            leading: const Icon(Icons.play_circle_outline),
            title: Text(AppLocalizations.of(context)!.playerScreen),
            onTap: () => Navigator.of(context).pushNamed(PlayerSettingsScreen.routeName),
          ),
          ListTile(
            leading: const Icon(TablerIcons.microphone_2),
            title: Text(AppLocalizations.of(context)!.lyricsScreen),
            onTap: () => Navigator.of(context).pushNamed(LyricsSettingsScreen.routeName),
          ),
          ListTile(
            leading: const Icon(TablerIcons.disc),
            title: Text(AppLocalizations.of(context)!.albumScreen),
            onTap: () => Navigator.of(context).pushNamed(AlbumSettingsScreen.routeName),
          ),
          ListTile(
            leading: const Icon(TablerIcons.user),
            title: Text(AppLocalizations.of(context)!.artistScreen),
            onTap: () => Navigator.of(context).pushNamed(ArtistSettingsScreen.routeName),
          ),
          ListTile(
            leading: const Icon(TablerIcons.color_swatch),
            title: Text(AppLocalizations.of(context)!.genreScreen),
            onTap: () => Navigator.of(context).pushNamed(GenreSettingsScreen.routeName),
          ),
          ListTile(
            leading: const Icon(Icons.tab),
            title: Text(AppLocalizations.of(context)!.tabs),
            onTap: () => Navigator.of(context).pushNamed(TabsSettingsScreen.routeName),
          ),
          const Divider(),
          const ThemeSelector(),
          const AmoledTheme(),
          const UseMonochromeIcon(),
          const AccentColorSelector(),
          const AutomaticAccentColorSelector(),
          const Divider(),
          const ContentViewTypeDropdownListTile(),
          const GridImageSizeSelector(),
          const ShowTextOnGridViewSelector(),
          const UseCoverAsBackgroundToggle(),
          const ShowArtistChipImageToggle(),
          const AllowSplitScreenSwitch(),
          const ShowProgressOnNowPlayingBarToggle(),
        ],
      ),
    );
  }
}

class AllowSplitScreenSwitch extends ConsumerWidget {
  const AllowSplitScreenSwitch({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SwitchListTile.adaptive(
      title: Text(AppLocalizations.of(context)!.allowSplitScreenTitle),
      subtitle: Text(AppLocalizations.of(context)!.allowSplitScreenSubtitle),
      value: ref.watch(finampSettingsProvider.allowSplitScreen),
      onChanged: FinampSetters.setAllowSplitScreen,
    );
  }
}

class ShowProgressOnNowPlayingBarToggle extends ConsumerWidget {
  const ShowProgressOnNowPlayingBarToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SwitchListTile.adaptive(
      title: Text(AppLocalizations.of(context)!.showProgressOnNowPlayingBarTitle),
      subtitle: Text(AppLocalizations.of(context)!.showProgressOnNowPlayingBarSubtitle),
      value: ref.watch(finampSettingsProvider.showProgressOnNowPlayingBar),
      onChanged: FinampSetters.setShowProgressOnNowPlayingBar,
    );
  }
}

class GridImageSizeSelector extends ConsumerStatefulWidget {
  const GridImageSizeSelector({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() {
    return _GridImageSizeSelectorState();
  }
}

class _GridImageSizeSelectorState extends ConsumerState<GridImageSizeSelector> {
  // We'll just assume the setting can only be changed by this widget
  double? colCount;

  @override
  Widget build(BuildContext context) {
    final predictedGridWidth =
        MediaQuery.widthOf(context) -
        MediaQuery.paddingOf(context).left -
        MediaQuery.paddingOf(context).right -
        10 -
        (ref.watch(finampSettingsProvider.showFastScroller) ? 22 : 0);

    // Always allow scaling items down to 45 px wide as the smallest reasonable value.  Desktop platforms are guaranteed
    // 25 options even if they go below this to increase flexibility and because they can handle the more precise slider
    final maxAvailable = max((predictedGridWidth / 45).ceil(), Platform.isAndroid || Platform.isIOS ? 0 : 25);

    colCount ??= predictedGridWidth / FinampSettingsHelper.finampSettings.gridImageSize;
    colCount = colCount!.clamp(1, maxAvailable.toDouble());

    String numLabel;
    if (colCount!.round() * 20 == (colCount! * 20).round()) {
      numLabel = "${colCount!.round()}";
    } else {
      numLabel = "~${colCount!.round()}";
    }
    final sizeLabel = AppLocalizations.of(context)!.fixedGridTileSizeEnum(switch (predictedGridWidth / colCount!) {
      < 80 => "verySmall",
      < 125 => "small",
      < 190 => "medium",
      < 300 => "large",
      _ => "veryLarge",
    });

    return Column(
      children: [
        ListTile(title: Text(context.l10n.gridImageSizeTitle), subtitle: Text(context.l10n.gridImageSizeSubtitle)),
        Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Slider(
              min: 1,
              max: maxAvailable.toDouble(),
              value: colCount!,
              label: numLabel,
              divisions: Platform.isAndroid || Platform.isIOS ? maxAvailable - 1 : null,
              onChanged: (value) {
                setState(() {
                  colCount = value;
                });
              },
              onChangeEnd: (value) {
                final pixels = predictedGridWidth / value;
                FinampSetters.setGridImageSize(pixels.toInt());
              },
              autofocus: false,
              focusNode: FocusNode(skipTraversal: true, canRequestFocus: false),
            ),
            Text(context.l10n.gridImageSizeLabel(sizeLabel, numLabel), style: Theme.of(context).textTheme.titleLarge),
          ],
        ),
      ],
    );
  }
}

class AutoSwitchItemCurationTypeToggle extends ConsumerWidget {
  const AutoSwitchItemCurationTypeToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SwitchListTile.adaptive(
      title: Text(AppLocalizations.of(context)!.autoSwitchItemCurationTypeTitle),
      subtitle: Text(AppLocalizations.of(context)!.autoSwitchItemCurationTypeSubtitle),
      value: ref.watch(finampSettingsProvider.autoSwitchItemCurationType),
      onChanged: FinampSetters.setAutoSwitchItemCurationType,
    );
  }
}

enum FixedGridTileSize {
  small,
  medium,
  large,
  veryLarge;

  static FixedGridTileSize fromInt(int size) => switch (size) {
    100 => small,
    150 => medium,
    230 => large,
    360 => veryLarge,
    _ => medium,
  };

  int get toInt => switch (this) {
    small => 100,
    medium => 150,
    large => 230,
    veryLarge => 360,
  };
}
