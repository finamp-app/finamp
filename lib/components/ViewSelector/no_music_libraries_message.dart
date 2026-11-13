import 'package:balanced_text/balanced_text.dart';
import 'package:finamp/components/Buttons/simple_button.dart';
import 'package:finamp/components/LogsScreen/export_logs_button.dart';
import 'package:finamp/components/LogsScreen/share_logs_button.dart';
import 'package:finamp/components/SettingsScreen/logout_list_tile.dart';
import 'package:finamp/extensions/localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

class NoMusicLibrariesMessage extends StatelessWidget {
  const NoMusicLibrariesMessage({super.key, required this.onRefresh});

  final void Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Column(
              children: [
                Text(
                  context.l10n.noMusicLibrariesTitle,
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 32),
                BalancedText(context.l10n.noMusicLibrariesBody, textAlign: TextAlign.center),
                SizedBox(height: 16),
                SimpleButton(icon: TablerIcons.refresh, onPressed: onRefresh, text: context.l10n.refresh),
                SizedBox(height: 32),
                BalancedText(context.l10n.noMusicLibrariesLogsCTA, textAlign: TextAlign.center),
                SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [ShareLogsButton(), SizedBox(width: 8), ExportLogsButton()],
                ),

                SizedBox(height: 64),
                BalancedText(context.l10n.noMusicLibrariesLogout, textAlign: TextAlign.center),
                SizedBox(height: 16),
                SimpleButton(
                  text: context.l10n.logOut,
                  icon: TablerIcons.logout,
                  iconColor: Colors.red,
                  textColor: Colors.red,
                  onPressed: () => showLogoutUserDialog(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
