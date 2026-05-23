import 'package:finamp/components/AlbumScreen/download_dialog.dart';
import 'package:finamp/components/MusicScreen/music_screen_tab_view.dart';
import 'package:finamp/components/confirmation_prompt_dialog.dart';
import 'package:finamp/components/delete_prompts.dart';
import 'package:finamp/components/global_snackbar.dart';
import 'package:finamp/extensions/localizations.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/services/downloads_service.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:finamp/services/finamp_user_helper.dart';
import 'package:finamp/services/permission_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:get_it/get_it.dart';

class DownloadButton extends ConsumerWidget {
  const DownloadButton({
    super.key,
    required this.item,
    this.children,
    this.childrenCount,
    this.isLibrary = false,
    this.downloadDisabled = false,
    this.customTooltip,
    this.allowServerDelete = true,
    this.warningMessage,
    this.downloadOnly = false,
  });

  final DownloadStub item;
  final List<BaseItemDto>? children;
  final int? childrenCount;
  final bool isLibrary;
  final bool downloadDisabled;
  final String? customTooltip;
  final String? warningMessage;
  final bool allowServerDelete;
  final bool downloadOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final childrenLength = childrenCount ?? children?.length;
    final downloadsService = GetIt.instance<DownloadsService>();
    DownloadItemStatus? status = ref.watch(downloadsService.statusProvider((item, childrenLength)));
    var isOffline = ref.watch(finampSettingsProvider.isOffline);
    bool canDeleteFromServer = false;
    if (item.type.requiresItem) {
      canDeleteFromServer = ref.watch(canDeleteFromServerProvider(item.baseItem!));
    }
    canDeleteFromServer = canDeleteFromServer && allowServerDelete;
    String? parentTooltip;
    if (status == null) {
      return const SizedBox.shrink();
    }
    if (status.isIncidental) {
      var parent = downloadsService.getFirstRequiringItem(item);
      if (parent != null) {
        var parentName = AppLocalizations.of(context)!.itemTypeSubtitle(parent.baseItemType.name, parent.name);
        parentTooltip = AppLocalizations.of(context)!.incidentalDownloadTooltip(parentName);
      }
    }
    BaseItemId viewId;
    if (isLibrary) {
      viewId = BaseItemId(item.id);
    } else {
      final finampUserHelper = GetIt.instance<FinampUserHelper>();
      viewId = finampUserHelper.currentUser!.currentViewId!;
    }

    var downloadButton = Opacity(
      opacity: downloadDisabled ? 0.4 : 1.0,
      child: IconButton(
        icon: status == DownloadItemStatus.notNeeded
            ? const Icon(TablerIcons.download)
            : const Icon(TablerIcons.lock), //TODO get better icon
        onPressed: () async {
          if (downloadDisabled) {
            sendDisabledDownloadMessageToSnackbar(customTooltip);
            return;
          }
          final warning = warningMessage ?? (isLibrary ? context.l10n.downloadLibraryPrompt(item.name) : null);
          if (warning != null) {
            await showDialog<void>(
              context: context,
              builder: (context) => ConfirmationPromptDialog(
                promptText: warning,
                confirmButtonText: AppLocalizations.of(context)!.addButtonLabel,
                onConfirmed: () => DownloadDialog.show(context, item, viewId),
              ),
            );
          } else {
            int? trackCount = switch (item.baseItemType) {
              BaseItemDtoType.album || BaseItemDtoType.playlist => children?.length,
              BaseItemDtoType.artist ||
              BaseItemDtoType.genre => children?.fold<int>(0, (count, item) => count + (item.childCount ?? 0)),
              _ => null,
            };
            await DownloadDialog.show(context, item, viewId, trackCount: trackCount);
          }
        },
        tooltip: customTooltip ?? parentTooltip,
      ),
    );
    var deleteButton = Opacity(
      opacity: downloadDisabled ? 0.4 : 1.0,
      child: IconButton(
        icon: const Icon(TablerIcons.trash),
        tooltip: AppLocalizations.of(context)!.deleteFromTargetConfirmButton(""),
        onPressed: () {
          if (downloadDisabled) {
            sendDisabledDownloadMessageToSnackbar(customTooltip);
            return;
          }
          askBeforeDeleteDownloadFromDevice(context, item);
        },
      ),
    );
    var syncButton = IconButton(
      icon: const Icon(Icons.sync),
      tooltip: AppLocalizations.of(context)!.syncDownloads,
      onPressed: () {
        downloadsService.resync(item, viewId);
      },
      color: (status.outdated && !downloadDisabled) ? Colors.orange : null,
    );
    var serverDeleteButton = Opacity(
      opacity: downloadDisabled ? 0.4 : 1.0,
      child: IconButton(
        icon: const Icon(TablerIcons.trash_x),
        tooltip: AppLocalizations.of(context)!.deleteFromTargetConfirmButton("server"),
        onPressed: () {
          if (downloadDisabled) {
            sendDisabledDownloadMessageToSnackbar(customTooltip);
            return;
          }
          askBeforeDeleteFromServerAndDevice(
            context,
            item,
            popIt: true,
            refresh: () => musicScreenRefreshStream.add(null),
          ); // trigger a refresh of the music screen
        },
      ),
    );

    var deleteFromServerCombo = PopupMenuButton<Null>(
      enableFeedback: true,
      icon: const Icon(TablerIcons.dots_vertical),
      onOpened: () => {},
      itemBuilder: (context) {
        return [
          PopupMenuItem(
            value: null,
            child: Opacity(
              opacity: downloadDisabled ? 0.4 : 1.0,
              child: ListTile(
                leading: Icon(Icons.delete_outline),
                title: Text(AppLocalizations.of(context)!.deleteFromTargetConfirmButton("")),
                enabled: true,
                onTap: () {
                  if (downloadDisabled) {
                    sendDisabledDownloadMessageToSnackbar(customTooltip);
                    return;
                  }
                  askBeforeDeleteDownloadFromDevice(context, item);
                },
              ),
            ),
          ),
          PopupMenuItem(
            value: null,
            child: Opacity(
              opacity: downloadDisabled ? 0.4 : 1.0,
              child: ListTile(
                leading: Icon(Icons.delete_forever),
                title: Text(AppLocalizations.of(context)!.deleteFromTargetConfirmButton("server")),
                enabled: true,
                onTap: () {
                  if (downloadDisabled) {
                    sendDisabledDownloadMessageToSnackbar(customTooltip);
                    return;
                  }
                  askBeforeDeleteFromServerAndDevice(
                    context,
                    item,
                    popIt: true,
                    refresh: () => musicScreenRefreshStream.add(null),
                  ); // trigger a refresh of the music screen
                },
              ),
            ),
          ),
        ];
      },
    );

    if (downloadOnly) {
      if (!status.isRequired && !isOffline) {
        return downloadButton;
      } else {
        return const SizedBox.shrink();
      }
    }

    if (isOffline) {
      if (status.isRequired) {
        return deleteButton;
      } else {
        return const SizedBox.shrink();
      }
    }

    List<Widget> buttons;
    if (canDeleteFromServer) {
      if (status.isRequired) {
        buttons = [deleteFromServerCombo];
      } else {
        buttons = [serverDeleteButton, downloadButton];
      }
    } else {
      if (status.isRequired) {
        buttons = [deleteButton];
      } else {
        buttons = [downloadButton];
      }
    }
    if (status != DownloadItemStatus.notNeeded &&
        //    ((item.baseItemType != BaseItemDtoType.album &&
        //            item.baseItemType != BaseItemDtoType.track) ||
        //        status.outdated) &&
        !isLibrary) {
      buttons.insert(
        0,
        syncButton,
      ); //!!! force sync button for now, so users can easily refresh albums which they know to have changed
    }

    if (buttons.length == 1) {
      return buttons.first;
    } else {
      return Row(mainAxisSize: MainAxisSize.min, children: buttons);
    }
  }
}

void sendDisabledDownloadMessageToSnackbar(String? customTooltip) {
  GlobalSnackbar.message((context) => customTooltip ?? AppLocalizations.of(context)!.notAvailable);
}
