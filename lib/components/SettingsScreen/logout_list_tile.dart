import 'dart:io';

import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/services/queue_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';

import '../../screens/splash_screen.dart';
import '../../services/finamp_settings_helper.dart';
import '../../services/jellyfin_api_helper.dart';
import '../../services/music_player_background_task.dart';
import '../global_snackbar.dart';

class LogoutListTile extends ConsumerWidget {
  const LogoutListTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: Icon(Icons.logout, color: ref.watch(finampSettingsProvider.isOffline) ? null : Colors.red),
      title: Text(
        AppLocalizations.of(context)!.logOut,
        style: ref.watch(finampSettingsProvider.isOffline) ? null : const TextStyle(color: Colors.red),
      ),
      subtitle: ref.watch(finampSettingsProvider.isOffline)
          ? Text(AppLocalizations.of(context)!.notAvailableInOfflineMode)
          : Text(AppLocalizations.of(context)!.logoutButtonSubtitle, style: const TextStyle(color: Colors.red)),
      enabled: !ref.watch(finampSettingsProvider.isOffline),
      onTap: () {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(AppLocalizations.of(context)!.areYouSure),
            actions: [
              TextButton(
                child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
                onPressed: () => Navigator.of(context).pop(),
              ),
              TextButton(
                child: Text(MaterialLocalizations.of(context).okButtonLabel),
                onPressed: () async {
                  try {
                    final audioHandler = GetIt.instance<MusicPlayerBackgroundTask>();
                    final queueService = GetIt.instance<QueueService>();

                    // We don't want audio to be playing after we log out.
                    // We check if the audio service is running on iOS because
                    // stop() never completes if the service is not running.
                    if (!Platform.isIOS || (audioHandler.playbackState.valueOrNull?.playing ?? false)) {
                      // Fully drop any remote-control connection: the session
                      // belongs to the account being logged out.
                      await queueService.stopAndClearQueue(disconnectRemote: true);
                    }

                    final jellyfinApiHelper = GetIt.instance<JellyfinApiHelper>();

                    await jellyfinApiHelper.logoutCurrentUser().onError((_, __) {});

                    if (!context.mounted) return;

                    await Navigator.of(context).pushNamedAndRemoveUntil(SplashScreen.routeName, (route) => false);
                  } catch (e) {
                    GlobalSnackbar.error(e);
                    return;
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
