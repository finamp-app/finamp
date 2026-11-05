import 'package:finamp/extensions/localizations.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/services/item_by_id_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shows the server-provided album overview when one is available.
class AlbumOverview extends ConsumerWidget {
  const AlbumOverview({super.key, required this.albumId});

  final BaseItemId albumId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(itemByIdProvider(albumId)).valueOrNull?.overview;
    if (overview == null || overview.trim().isEmpty) return const SizedBox.shrink();

    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: () => showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(context.l10n.albumInformation),
            content: SingleChildScrollView(child: SelectableText(overview)),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(context.l10n.close))],
          ),
        ),
        icon: const Icon(Icons.info_outline),
        label: Text(context.l10n.albumInformation),
      ),
    );
  }
}
