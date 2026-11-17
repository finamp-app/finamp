import 'package:finamp/components/confirmation_prompt_dialog.dart';
import 'package:finamp/components/global_snackbar.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/menus/components/menuEntries/menu_entry.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:finamp/services/hidden_items.dart';
import 'package:finamp/services/hidden_items_provider.dart';
import 'package:finamp/services/permission_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
      hasTag: (ref.watch(serverHiddenIdsProvider).value?.contains(baseItem.id) ?? false) || hasHiddenTag(baseItem),
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
      final scope = await showDialog<HideScope>(context: context, builder: (_) => const _HideScopeDialog());
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

    try {
      await apply(hidden);
    } catch (_) {
      return;
    }
    final name = baseItem.name ?? "";
    GlobalSnackbar.message(
      (context) => hidden
          ? AppLocalizations.of(context)!.itemHiddenMessage(name)
          : AppLocalizations.of(context)!.itemUnhiddenMessage(name),
      action: (context) =>
          SnackBarAction(label: AppLocalizations.of(context)!.undo, onPressed: () => apply(!hidden).ignore()),
    );
  }

  @override
  bool get isVisible => _isHideable(baseItem);
}

class _HideScopeDialog extends StatelessWidget {
  const _HideScopeDialog();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    Widget option(HideScope scope, IconData icon, String title, String subtitle) => ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      onTap: () => Navigator.of(context).pop(scope),
    );
    return SimpleDialog(
      title: Text(l10n.hideScopeDialogTitle),
      children: [
        option(
          HideScope.thisDevice,
          TablerIcons.device_mobile,
          l10n.hideScopeThisDevice,
          l10n.hideScopeThisDeviceSubtitle,
        ),
        option(HideScope.everyone, TablerIcons.server, l10n.hideScopeEveryone, l10n.hideScopeEveryoneSubtitle),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
          child: Text(l10n.hideScopeRememberedNote, style: Theme.of(context).textTheme.bodySmall),
        ),
      ],
    );
  }
}
