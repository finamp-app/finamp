import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:finamp/services/feedback_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../../components/Buttons/simple_button.dart';

/// A toggle button shown on the player screen to quickly enable/disable transcoding.
///
/// Only meaningful for streamed (non-downloaded) tracks. The button visually
/// indicates the current state and toggles [FinampSettings.shouldTranscode],
/// which triggers a queue reload via [DataSourceService].
class TranscodeToggleButton extends ConsumerWidget {
  const TranscodeToggleButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shouldTranscode = ref.watch(finampSettingsProvider.shouldTranscode);
    final l10n = AppLocalizations.of(context)!;

    return SimpleButton(
      text: l10n.transcodeToggleButtonTitle,
      icon: shouldTranscode ? TablerIcons.transform : TablerIcons.transform,
      iconColor: shouldTranscode
          ? Theme.of(context).colorScheme.primary
          : null,
      onPressed: () {
        FeedbackHelper.feedback(FeedbackType.light);
        FinampSetters.setShouldTranscode(!shouldTranscode);
      },
    );
  }
}
