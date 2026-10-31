import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../extensions/localizations.dart';
import '../../models/finamp_models.dart';
import '../../services/finamp_settings_helper.dart';
import '../SettingsScreen/finamp_settings_dropdown.dart';

class TrackArtistOrderSelector extends ConsumerWidget {
  const TrackArtistOrderSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      title: Text(context.l10n.trackArtistOrderTitle),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.l10n.trackArtistOrderSubtitle),
          const SizedBox(height: 8),
          FinampSettingsDropdown<TrackArtistOrder>(
            selectedValue: ref.watch(finampSettingsProvider.trackArtistOrder),
            dropdownItems: TrackArtistOrder.values
                .map((order) => DropdownMenuEntry(value: order, label: order.toLocalisedString(context.l10n)))
                .toList(),
            onSelected: (order) {
              if (order != null) FinampSetters.setTrackArtistOrder(order);
            },
          ),
        ],
      ),
    );
  }
}
