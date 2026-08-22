import 'package:balanced_text/balanced_text.dart';
import 'package:finamp/components/Buttons/simple_button.dart';
import 'package:finamp/components/confirmation_prompt_dialog.dart';
import 'package:finamp/components/themed_bottom_sheet.dart';
import 'package:finamp/components/toggleable_list_tile.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/menus/quick_connect_authorization_menu.dart';
import 'package:finamp/services/feedback_helper.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:finamp/services/server_client_discovery_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_sticky_header/flutter_sticky_header.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

const serverSharingPanelRouteName = "/server-sharing-panel";

Future<void> showServerSharingPanel({required BuildContext context}) async {
  FeedbackHelper.feedback(FeedbackType.selection);

  await showThemedBottomSheet<void>(
    context: context,
    routeName: serverSharingPanelRouteName,
    minDraggableHeight: 0.45,
    buildSlivers: (context) {
      var menu = [
        SliverStickyHeader(
          header: ServerSharingPanelHeader(),
          sliver: MenuMask(
            height: ServerSharingPanelHeader.defaultHeight,
            child: SliverToBoxAdapter(child: ServerSharingMenuControls()),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.only(left: 32.0, right: 32.0, top: 16.0),
          sliver: SliverList(
            delegate: SliverChildListDelegate.fixed([
              BalancedText(
                AppLocalizations.of(context)!.serverSharingMenuDescription,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 24.0),
              BalancedText(
                AppLocalizations.of(context)!.serverSharingMenuDetails,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ]),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 20.0),
            child: SimpleButton(
              text: AppLocalizations.of(context)!.quickConnectAuthorizationMenuPrompt,
              icon: TablerIcons.lock_bolt,
              onPressed: () async {
                Navigator.of(context).pop();
                await showQuickConnectAuthorizationMenu(context: context);
              },
            ),
          ),
        ),
        SliverPadding(padding: EdgeInsets.only(bottom: 40.0)),
      ];
      var stackHeight = MediaQuery.heightOf(context) * 0.45;
      return (stackHeight, menu);
    },
  );
}

class ServerSharingMenuControls extends ConsumerStatefulWidget {
  const ServerSharingMenuControls({super.key});

  @override
  _ServerSharingMenuControlsState createState() => _ServerSharingMenuControlsState();
}

class _ServerSharingMenuControlsState extends ConsumerState<ServerSharingMenuControls> {
  final serverDiscoveryEmulationService = JellyfinServerClientDiscovery();

  late bool serverSharingEnabled;
  late Key toggleableListTileKey;

  @override
  void initState() {
    super.initState();
    serverSharingEnabled = false;
    toggleableListTileKey = UniqueKey();

    AppLifecycleListener(
      onRestart: () {},
      onHide: () {
        // If the app is hidden, we stop advertising the server
        setServerSharing(false);
        toggleableListTileKey = UniqueKey();
      },
      onShow: () {},
      onPause: () {},
    );
  }

  @override
  void dispose() {
    serverSharingEnabled = false;
    serverDiscoveryEmulationService.dispose();
    super.dispose();
  }

  bool setServerSharing(bool newState) {
    if (newState) {
      serverDiscoveryEmulationService.advertiseServer();
    } else {
      serverDiscoveryEmulationService.stopAdvertising();
    }
    if (mounted) {
      setState(() {
        serverSharingEnabled = serverDiscoveryEmulationService.isAdvertising;
      });
    }
    return serverDiscoveryEmulationService.isAdvertising;
  }

  @override
  Widget build(BuildContext context) {
    final bool isOffline = ref.watch(finampSettingsProvider.isOffline);

    return ToggleableListTile(
      leading: Padding(
        padding: const EdgeInsets.only(left: 8.0, top: 8.0, bottom: 8.0),
        child: const Icon(TablerIcons.access_point, size: 36.0),
      ),
      title: serverSharingEnabled
          ? AppLocalizations.of(context)!.serverSharingMenuControlTitleSharingEnabled
          : AppLocalizations.of(context)!.serverSharingMenuControlTitleSharingDisabled,
      subtitle: serverSharingEnabled
          ? AppLocalizations.of(context)!.serverSharingMenuControlSubtitleSharingEnabled
          : AppLocalizations.of(context)!.serverSharingMenuControlSubtitleSharingDisabled,
      trailing: Switch.adaptive(
        value: serverSharingEnabled,
        onChanged: (value) {
          setServerSharing(value);
        },
        padding: const EdgeInsets.symmetric(horizontal: 0.0, vertical: -8.0),
      ),
      state: serverSharingEnabled,
      onToggle: (bool currentState) async {
        if (!currentState && isOffline) {
          await showDialog<ConfirmationPromptDialog>(
            context: context,
            builder: (context) => ConfirmationPromptDialog(
              promptText: AppLocalizations.of(context)!.serverSharingMenuConfirmationDialogText,
              confirmButtonText: AppLocalizations.of(
                context,
              )!.serverSharingMenuConfirmationDialogConfirmationButtonLabel,
              onConfirmed: () => setServerSharing(true),
            ),
          );
        } else {
          setServerSharing(!currentState);
        }
      },
    );
  }
}

class ServerSharingPanelHeader extends StatelessWidget {
  const ServerSharingPanelHeader({super.key});

  static const defaultHeight = MenuMaskHeight(36.0);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6.0, bottom: 16.0),
      child: Center(
        child: Text(
          AppLocalizations.of(context)!.serverSharingMenuTitle,
          style: TextStyle(
            color: Theme.of(context).textTheme.bodyLarge!.color!,
            fontSize: 18,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
