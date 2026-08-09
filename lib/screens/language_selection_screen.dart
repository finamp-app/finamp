import 'package:flutter/material.dart';

import 'package:finamp/components/finamp_app_bar_back_button.dart';
import 'package:finamp/l10n/app_localizations.dart';

import '../components/LanguageSelectionScreen/language_list.dart';

class LanguageSelectionScreen extends StatelessWidget {
  const LanguageSelectionScreen({super.key});

  static const routeName = "/settings/language";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.language), leading: FinampAppBarBackButton()),
      body: const LanguageList(),
    );
  }
}
