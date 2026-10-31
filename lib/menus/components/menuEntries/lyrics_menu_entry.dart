import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/menus/components/menuEntries/menu_entry.dart';
import 'package:finamp/screens/lyrics_screen.dart';
import 'package:finamp/services/current_track_metadata_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

class LyricsMenuEntry extends ConsumerWidget implements HideableMenuEntry {
  const LyricsMenuEntry({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metadata = ref.watch(currentTrackMetadataProvider).unwrapPrevious();
    final isLoading = metadata.isLoading || metadata.isRefreshing;
    final isAvailable =
        (metadata.valueOrNull?.hasLyrics ?? false) &&
        (metadata.valueOrNull?.lyrics != null || metadata.isLoading) &&
        !metadata.hasError;

    return MenuEntry(
      icon: !isLoading && !isAvailable ? TablerIcons.microphone_2_off : TablerIcons.microphone_2,
      title: AppLocalizations.of(context)!.lyricsScreenButtonTitle,
      // Like the bottom action, keep this accessible to show loading/missing lyrics.
      onTap: () async {
        final navigator = Navigator.of(context);
        navigator.pop();
        await navigator.push(
          MaterialPageRoute<void>(
            settings: const RouteSettings(name: LyricsScreen.routeName),
            builder: (context) => const LyricsScreen(),
          ),
        );
      },
    );
  }

  @override
  bool get isVisible => true;
}
