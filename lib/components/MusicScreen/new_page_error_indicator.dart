import 'package:flutter/material.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../../extensions/localizations.dart';
import '../../l10n/app_localizations.dart';
import '../Buttons/cta_medium.dart';

class NewPageErrorIndicator extends StatelessWidget {
  const NewPageErrorIndicator({super.key, required this.onTap});

  final void Function() onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 32.0),
    child: Column(
      children: [
        Text(AppLocalizations.of(context)!.retryPageLoad, style: TextStyle(fontSize: 16), textAlign: TextAlign.center),
        const SizedBox(height: 8),
        CTAMedium(icon: TablerIcons.refresh, text: context.l10n.retry, onPressed: onTap),
        const SizedBox(height: 50),
      ],
    ),
  );
}

class FirstPageErrorIndicator extends StatelessWidget {
  const FirstPageErrorIndicator({super.key, required this.onTap});

  final void Function() onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 32.0),
    child: Column(
      children: [
        Text(context.l10n.anErrorHasOccured, style: TextStyle(fontSize: 24), textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(AppLocalizations.of(context)!.retryPageLoad, style: TextStyle(fontSize: 16), textAlign: TextAlign.center),
        const SizedBox(height: 8),
        CTAMedium(icon: TablerIcons.refresh, text: context.l10n.retry, onPressed: onTap),
        const SizedBox(height: 50),
      ],
    ),
  );
}
