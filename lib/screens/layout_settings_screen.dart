import 'package:finamp/components/LayoutSettingsScreen/automatic_accent_color_selector.dart';
import 'package:finamp/components/LayoutSettingsScreen/use_monochrome_icon.dart';
import 'package:finamp/components/SettingsScreen/finamp_settings_dropdown.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/models/finamp_models.dart';
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
import '../components/LayoutSettingsScreen/content_view_type_dropdown_list_tile.dart';
import '../components/LayoutSettingsScreen/show_artist_chip_image_toggle.dart';
import '../components/finamp_app_bar_back_button.dart';
import '../components/LayoutSettingsScreen/show_text_on_grid_view_selector.dart';
import '../components/LayoutSettingsScreen/theme_selector.dart';
import '../components/LayoutSettingsScreen/use_cover_as_background_toggle.dart';
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
  var currentSize = FinampSettingsHelper.finampSettings.gridImageSize;

  @override
  Widget build(BuildContext context) {
    ref.watch(finampSettingsProvider.gridImageSize);
    return Column(
      children: [
        ListTile(title: Text("Grid Tile Size*"), subtitle: Text("Select the size of items in the grid*")),
        Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Slider(
              min: 0,
              max: GridImageSizePresets.values.length - 1,
              value: GridImageSizePresets.values.indexOf(currentSize).toDouble(),
              divisions: GridImageSizePresets.values.length - 1,
              label: "${currentSize.name} (? columns)",
              onChanged: (value) {
                setState(() {
                  currentSize = GridImageSizePresets.values[value.toInt()];
                });
              },
              onChangeEnd: (value) {
                FinampSetters.setGridImageSize(GridImageSizePresets.values[value.toInt()]);
              },
              autofocus: false,
              focusNode: FocusNode(skipTraversal: true, canRequestFocus: false),
            ),
            Text("${currentSize.name} (? columns)", style: Theme.of(context).textTheme.titleLarge),
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
