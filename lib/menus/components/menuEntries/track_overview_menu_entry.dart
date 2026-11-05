import 'package:finamp/extensions/localizations.dart';
import 'package:finamp/menus/components/menuEntries/menu_entry.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/services/item_by_id_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TrackOverviewMenuEntry extends ConsumerWidget implements HideableMenuEntry {
  const TrackOverviewMenuEntry({super.key, required this.itemId});

  final BaseItemId itemId;

  @override
  bool get isVisible => true;

  @override
  Widget build(BuildContext context, WidgetRef ref) => MenuEntry(
    title: context.l10n.trackInformation,
    icon: Icons.info_outline,
    onTap: () => showDialog<void>(
      context: context,
      builder: (context) => Consumer(
        builder: (context, ref, child) {
          final item = ref.watch(itemByIdProvider(itemId));
          return AlertDialog(
            title: Text(context.l10n.trackInformation),
            content: item.when(
              loading: () => const SizedBox(height: 48, child: Center(child: CircularProgressIndicator.adaptive())),
              error: (error, stack) => Text(context.l10n.itemInformationError),
              data: (item) {
                final overview = item?.overview;
                if (overview == null || overview.trim().isEmpty) return Text(context.l10n.noItemInformation);
                return SingleChildScrollView(child: SelectableText(overview));
              },
            ),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(context.l10n.close))],
          );
        },
      ),
    ),
  );
}
