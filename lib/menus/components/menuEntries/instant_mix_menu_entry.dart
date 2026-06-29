import 'package:finamp/components/global_snackbar.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/menus/components/menuEntries/menu_entry.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/services/audio_service_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:get_it/get_it.dart';
import '../../../services/finamp_settings_helper.dart';

/// Start Jellyfin Instant Mix for any item type
class InstantMixMenuEntry extends ConsumerWidget implements HideableMenuEntry {
  final BaseItemDto baseItem;

  const InstantMixMenuEntry({super.key, required this.baseItem});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audioServiceHelper = GetIt.instance<AudioServiceHelper>();

    return Visibility(
      visible: !ref.watch(finampSettingsProvider.isOffline),
      child: MenuEntry(
        icon: TablerIcons.compass,
        title: AppLocalizations.of(context)!.instantMix,
        onTap: () async {
          Navigator.pop(context); // close menu
          await audioServiceHelper.startInstantMixForItem(baseItem);

          GlobalSnackbar.message((context) => AppLocalizations.of(context)!.startingInstantMix, isConfirmation: true);
        },
      ),
    );
  }

  @override
  bool get isVisible => !FinampSettingsHelper.finampSettings.isOffline;
}
