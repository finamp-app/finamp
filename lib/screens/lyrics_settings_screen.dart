import 'package:finamp/components/SettingsScreen/finamp_settings_dropdown.dart';
import 'package:finamp/components/finamp_app_bar_back_button.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../extensions/localizations.dart';
import '../models/finamp_models.dart';
import '../services/finamp_settings_helper.dart';

class LyricsSettingsScreen extends StatefulWidget {
  const LyricsSettingsScreen({super.key});
  static const routeName = "/settings/lyrics";
  @override
  State<LyricsSettingsScreen> createState() => _LyricsSettingsScreenState();
}

class _LyricsSettingsScreenState extends State<LyricsSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.lyricsScreen),
        leading: FinampAppBarBackButton(),
        actions: [
          FinampSettingsHelper.makeSettingsResetButtonWithDialog(context, FinampSettingsHelper.resetLyricsSettings),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 200.0),
        children: const [
          ShowLyricsTimestampsToggle(),
          ShowLyricsScreenAlbumPreludeToggle(),
          LyricsAlignmentSelector(),
          LyricsFontSizeSelector(),
        ],
      ),
    );
  }
}

class ShowLyricsTimestampsToggle extends ConsumerWidget {
  const ShowLyricsTimestampsToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SwitchListTile.adaptive(
      title: Text(AppLocalizations.of(context)!.showLyricsTimestampsTitle),
      subtitle: Text(AppLocalizations.of(context)!.showLyricsTimestampsSubtitle),
      value: ref.watch(finampSettingsProvider.showLyricsTimestamps),
      onChanged: FinampSetters.setShowLyricsTimestamps,
    );
  }
}

class LyricsAlignmentSelector extends ConsumerWidget {
  const LyricsAlignmentSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      title: Text(AppLocalizations.of(context)!.lyricsAlignmentTitle),
      subtitle: Column(
        spacing: 4.0,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppLocalizations.of(context)!.lyricsAlignmentSubtitle),
          FinampSettingsDropdown<LyricsAlignment>(
            dropdownItems: LyricsAlignment.values
                .map(
                  (e) => DropdownMenuEntry<LyricsAlignment>(
                    value: e,
                    label: e.toLocalisedString(context.l10n),
                    leadingIcon: switch (e) {
                      LyricsAlignment.start => Icon(
                        Directionality.of(context) == TextDirection.rtl
                            ? TablerIcons.align_right
                            : TablerIcons.align_left,
                      ),
                      LyricsAlignment.center => const Icon(TablerIcons.align_center),
                      LyricsAlignment.end => Icon(
                        Directionality.of(context) == TextDirection.rtl
                            ? TablerIcons.align_left
                            : TablerIcons.align_right,
                      ),
                    },
                  ),
                )
                .toList(),
            selectedValue: ref.watch(finampSettingsProvider.lyricsAlignment),
            onSelected: FinampSetters.setLyricsAlignment.ifNonNull,
          ),
        ],
      ),
    );
  }
}

class LyricsFontSizeSelector extends ConsumerWidget {
  const LyricsFontSizeSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      title: Text(AppLocalizations.of(context)!.lyricsFontSizeTitle),
      subtitle: Column(
        spacing: 4.0,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppLocalizations.of(context)!.lyricsFontSizeSubtitle),
          FinampSettingsDropdown<LyricsFontSize>(
            dropdownItems: LyricsFontSize.values
                .map((e) => DropdownMenuEntry<LyricsFontSize>(value: e, label: e.toLocalisedString(context.l10n)))
                .toList(),
            selectedValue: ref.watch(finampSettingsProvider.lyricsFontSize),
            onSelected: FinampSetters.setLyricsFontSize.ifNonNull,
          ),
        ],
      ),
    );
  }
}

class ShowLyricsScreenAlbumPreludeToggle extends ConsumerWidget {
  const ShowLyricsScreenAlbumPreludeToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SwitchListTile.adaptive(
      title: Text(AppLocalizations.of(context)!.showLyricsScreenAlbumPreludeTitle),
      subtitle: Text(AppLocalizations.of(context)!.showLyricsScreenAlbumPreludeSubtitle),
      value: ref.watch(finampSettingsProvider.showLyricsScreenAlbumPrelude),
      onChanged: FinampSetters.setShowLyricsScreenAlbumPrelude,
    );
  }
}
