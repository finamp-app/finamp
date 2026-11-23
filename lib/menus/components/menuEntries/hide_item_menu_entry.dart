import 'dart:io';

import 'package:finamp/components/confirmation_prompt_dialog.dart';
import 'package:finamp/components/global_snackbar.dart';
import 'package:finamp/components/themed_bottom_sheet.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/menus/choice_menu.dart';
import 'package:finamp/menus/components/menuEntries/menu_entry.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:finamp/services/hidden_items.dart';
import 'package:finamp/services/hidden_items_provider.dart';
import 'package:finamp/services/permission_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_sticky_header/flutter_sticky_header.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

class HideItemMenuEntry extends ConsumerWidget implements HideableMenuEntry {
  final BaseItemDto baseItem;

  const HideItemMenuEntry({super.key, required this.baseItem});

  static bool _isHideable(BaseItemDto item) =>
      [BaseItemDtoType.track, BaseItemDtoType.album].contains(BaseItemDtoType.fromItem(item));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final isHidden = ref.watch(isHiddenProvider(baseItem));
    final canEditServer = ref.watch(canEditMetadataProvider);
    final isOffline = ref.watch(finampSettingsProvider.isOffline);

    if (!isHidden) {
      return Visibility(
        visible: _isHideable(baseItem),
        child: MenuEntry(
          icon: TablerIcons.eye_off,
          title: l10n.hideItem,
          onTap: () => _hide(context, ref, isOffline: isOffline),
        ),
      );
    }

    final unhide = resolveUnhideAction(
      isAdmin: canEditServer,
      isOffline: isOffline,
      inLocal: ref.watch(localHiddenIdsProvider).contains(baseItem.id),
      hasTag: ref.watch(serverHiddenIdsProvider).valueOrNull?.contains(baseItem.id) ?? false,
      albumHidden: baseItem.albumId != null && ref.watch(hiddenIdsProvider).contains(baseItem.albumId),
    );
    return Visibility(
      visible: _isHideable(baseItem),
      child: MenuEntry(
        icon: TablerIcons.eye,
        title: l10n.unhideItem,
        enabled: unhide.blocked == null,
        tooltip: switch (unhide.blocked) {
          UnhideBlocked.serverAdminOnly => l10n.unhideBlockedServerAdminOnly,
          UnhideBlocked.offline => l10n.unhideBlockedOffline,
          UnhideBlocked.hiddenViaAlbum => l10n.unhideBlockedHiddenViaAlbum,
          null => null,
        },
        onTap: () async {
          Navigator.pop(context);
          await _setHidden(ref, false, local: unhide.clearLocal, server: unhide.clearTag);
        },
      ),
    );
  }

  Future<void> _hide(BuildContext context, WidgetRef ref, {required bool isOffline}) async {
    // Wait for the real answer: deciding on a still-loading admin status shows admins the non-admin notice.
    final isAdmin = !isOffline && await ref.read(isServerAdminProvider.future);
    if (!context.mounted) return;
    final settings = FinampSettingsHelper.finampSettings;
    var action = resolveHideAction(
      isAdmin: isAdmin,
      isOffline: isOffline,
      scope: settings.hideScope,
      localNoticeShown: settings.hideLocalNoticeShown,
    );
    if (action == HideAction.askScope) {
      final scope = await showHideScopeMenu(context, item: baseItem);
      if (scope == null) return;
      FinampSetters.setHideScope(scope);
      action = scope == HideScope.everyone ? HideAction.hideOnServer : HideAction.hideLocal;
    } else if (action == HideAction.showLocalNotice) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => ConfirmationPromptDialog(
          promptText: AppLocalizations.of(dialogContext)!.hideLocalNotice,
          confirmButtonText: AppLocalizations.of(dialogContext)!.hideItem,
        ),
      );
      if (confirmed != true) return;
      FinampSetters.setHideLocalNoticeShown(true);
      action = HideAction.hideLocal;
    }
    if (context.mounted) Navigator.pop(context);
    final server = action == HideAction.hideOnServer;
    await _setHidden(ref, true, local: !server, server: server);
  }

  Future<void> _setHidden(WidgetRef ref, bool hidden, {required bool local, required bool server}) async {
    final localIds = ref.read(localHiddenIdsProvider.notifier);
    final serverIds = ref.read(serverHiddenIdsProvider.notifier);
    Future<void> apply(bool value) async {
      try {
        if (local) await (value ? localIds.hide(baseItem.id) : localIds.unhide(baseItem.id));
        if (server) await serverIds.setHidden(baseItem.id, value);
      } catch (e) {
        GlobalSnackbar.error(e);
        rethrow;
      }
    }

    final applied = apply(hidden);
    // Server hides apply instantly in the app, so confirm now rather than after the server answers;
    // apply() reports a failure itself.
    final name = baseItem.name ?? "";
    GlobalSnackbar.message(
      (context) => hidden
          ? AppLocalizations.of(context)!.itemHiddenMessage(name)
          : AppLocalizations.of(context)!.itemUnhiddenMessage(name),
      action: (context) =>
          SnackBarAction(label: AppLocalizations.of(context)!.undo, onPressed: () => apply(!hidden).ignore()),
    );
    await applied.catchError((_) {});
  }

  @override
  bool get isVisible => _isHideable(baseItem);
}

/// Asks an admin whether to hide [item] on this device or for everyone. Returns null if dismissed.
Future<HideScope?> showHideScopeMenu(BuildContext context, {BaseItemDto? item}) {
  return showThemedBottomSheet<HideScope>(
    context: context,
    item: item,
    routeName: "/hide-scope-menu",
    minDraggableHeight: 0.25,
    buildSlivers: (context) {
      final l10n = AppLocalizations.of(context)!;
      final options = HideScopeOptions(onSelect: (scope) => Navigator.of(context).pop(scope));
      final menu = [
        SliverStickyHeader(
          header: Padding(
            padding: const EdgeInsets.only(top: 10.0, bottom: 8.0, left: 16.0, right: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2.0,
              children: [
                Text(l10n.hideScopeDialogTitle, style: Theme.of(context).textTheme.titleMedium),
                Text(l10n.hideScopeRememberedNote, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          sliver: MenuMask(
            height: MenuMaskHeight(36.0),
            child: SliverToBoxAdapter(child: options),
          ),
        ),
      ];
      // header + options, sized like the radio mode menu
      final stackHeight = 60.0 + HideScopeOptions.count * ((Platform.isAndroid || Platform.isIOS) ? 72.0 : 64.0);
      return (stackHeight, menu);
    },
  );
}

/// The two hide scopes, laid out like other choice menus.
class HideScopeOptions extends StatelessWidget {
  const HideScopeOptions({super.key, required this.onSelect});

  static const count = 2;

  final void Function(HideScope) onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ChoiceMenuOption(
          title: l10n.hideScopeThisDevice,
          description: l10n.hideScopeThisDeviceSubtitle,
          icon: TablerIcons.device_mobile,
          isSelected: false,
          onSelect: () => onSelect(HideScope.thisDevice),
        ),
        ChoiceMenuOption(
          title: l10n.hideScopeEveryone,
          description: l10n.hideScopeEveryoneSubtitle,
          icon: TablerIcons.server,
          isSelected: false,
          onSelect: () => onSelect(HideScope.everyone),
        ),
      ],
    );
  }
}
