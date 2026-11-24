import 'package:finamp/components/SettingsScreen/finamp_settings_dropdown.dart';
import 'package:finamp/components/finamp_app_bar_back_button.dart';
import 'package:finamp/components/global_snackbar.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:finamp/services/hidden_items.dart';
import 'package:finamp/services/hidden_items_provider.dart';
import 'package:finamp/services/item_by_id_provider.dart';
import 'package:finamp/services/permission_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

class HiddenItemsSettingsScreen extends ConsumerWidget {
  const HiddenItemsSettingsScreen({super.key});

  static const routeName = "/settings/hidden-items";

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final localIds = ref.watch(localHiddenIdsProvider);
    final serverIds = ref.watch(serverHiddenIdsProvider).valueOrNull ?? const {};
    final allHidden = ref.watch(hiddenIdsProvider);
    final serverHidden = ref.read(serverHiddenIdsProvider.notifier);
    // A hidden album's row covers its tracks, which Jellyfin reports as tagged along with it.
    final hiddenIds = [
      ...localIds,
      ...serverIds.difference(localIds),
    ].where((id) => !allHidden.contains(serverHidden.albumOf(id))).toList();
    final isAdmin = ref.watch(isServerAdminProvider).valueOrNull ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.hiddenItemsSettingsTitle),
        leading: const FinampAppBarBackButton(),
        actions: [
          FinampSettingsHelper.makeSettingsResetButtonWithDialog(
            context,
            FinampSettingsHelper.resetHiddenItemsSettings,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 200.0),
        children: [
          _DropdownTile<HiddenItemsDisplay>(
            title: l10n.hiddenItemsDisplayTitle,
            value: ref.watch(finampSettingsProvider.hiddenItemsDisplay),
            labels: {
              HiddenItemsDisplay.remove: l10n.hiddenItemsDisplayRemove,
              HiddenItemsDisplay.greyOut: l10n.hiddenItemsDisplayGreyOut,
            },
            onSelected: FinampSetters.setHiddenItemsDisplay,
          ),
          if (isAdmin)
            _DropdownTile<HideScope>(
              title: l10n.hideScopeSettingTitle,
              value: ref.watch(finampSettingsProvider.hideScope),
              labels: {
                HideScope.ask: l10n.hideScopeAsk,
                HideScope.thisDevice: l10n.hideScopeThisDevice,
                HideScope.everyone: l10n.hideScopeEveryone,
              },
              onSelected: FinampSetters.setHideScope,
            ),
          const Divider(),
          ListTile(
            title: Text(l10n.hiddenItemsListTitle(hiddenIds.length), style: Theme.of(context).textTheme.titleMedium),
          ),
          for (final id in hiddenIds)
            _HiddenItemTile(id: id, inLocal: localIds.contains(id), hasTag: serverIds.contains(id)),
        ],
      ),
    );
  }
}

class _DropdownTile<T> extends StatelessWidget {
  const _DropdownTile({required this.title, required this.value, required this.labels, required this.onSelected});

  final String title;
  final T value;
  final Map<T, String> labels;
  final void Function(T) onSelected;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title),
      // Below the title so long options like "Only on this device" aren't cut off.
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: FinampSettingsDropdown<T>(
          dropdownItems: [
            for (final MapEntry(:key, :value) in labels.entries) DropdownMenuEntry<T>(value: key, label: value),
          ],
          selectedValue: value,
          onSelected: (selected) {
            if (selected != null) onSelected(selected);
          },
        ),
      ),
    );
  }
}

class _HiddenItemTile extends ConsumerWidget {
  const _HiddenItemTile({required this.id, required this.inLocal, required this.hasTag});

  final BaseItemId id;
  final bool inLocal;
  final bool hasTag;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final item = ref.watch(itemByIdProvider(id)).valueOrNull;
    final unhide = resolveUnhideAction(
      isAdmin: ref.watch(canEditMetadataProvider),
      isOffline: ref.watch(finampSettingsProvider.isOffline),
      inLocal: inLocal,
      hasTag: hasTag,
      albumHidden: item?.albumId != null && ref.watch(hiddenIdsProvider).contains(item!.albumId),
    );
    return ListTile(
      leading: Icon(
        item != null && BaseItemDtoType.fromItem(item) == BaseItemDtoType.album ? TablerIcons.disc : TablerIcons.music,
      ),
      title: Text(item?.name ?? l10n.hiddenItemUnavailable),
      subtitle: Text(hasTag ? l10n.hiddenForEveryone : l10n.hiddenOnThisDevice),
      trailing: TextButton(
        onPressed: unhide.blocked != null
            ? null
            : () async {
                try {
                  if (unhide.clearLocal) await ref.read(localHiddenIdsProvider.notifier).unhide(id);
                  if (unhide.clearTag) await ref.read(serverHiddenIdsProvider.notifier).setHidden(id, false);
                } catch (e) {
                  GlobalSnackbar.error(e);
                }
              },
        child: Text(l10n.unhideItem),
      ),
    );
  }
}
