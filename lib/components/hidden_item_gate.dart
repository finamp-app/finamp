import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:finamp/services/hidden_items_provider.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Collapses a row for a hidden item instead of removing it, for paged lists whose indices must stay stable.
class HiddenItemGate extends ConsumerWidget {
  const HiddenItemGate({super.key, required this.item, required this.child});

  final BaseItemDto? item;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = this.item;
    final remove = ref.watch(finampSettingsProvider.hiddenItemsDisplay) == HiddenItemsDisplay.remove;
    if (item != null && remove && ref.watch(isHiddenProvider(item))) {
      return const SizedBox.shrink();
    }
    return child;
  }
}
