import 'dart:collection';

import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:flutter/material.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:locale_names/locale_names.dart';

import '../padded_custom_scrollview.dart';

class LanguageList extends ConsumerWidget {
  const LanguageList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locales = SplayTreeMap<String?, Locale>.fromIterable(
      AppLocalizations.supportedLocales,
      key: (element) => (element as Locale).toLanguageTag(),
      value: (element) => element as Locale,
    );
    final localeFromSettings = ref.watch(finampSettingsProvider.locale);

    return RadioGroup<Locale?>(
      groupValue: localeFromSettings,
      onChanged: FinampSetters.setLocale,
      child: PaddedCustomScrollview(
        slivers: [
          const SliverList(delegate: SliverChildListDelegate.fixed([LanguageListTile(), Divider()])),
          SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final locale = locales.values.elementAt(index);

              return LanguageListTile(locale: locale);
            }, childCount: locales.length),
          ),
        ],
      ),
    );
  }
}

class LanguageListTile extends ConsumerWidget {
  const LanguageListTile({super.key, this.locale});

  final Locale? locale; // null if system language

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localeFromSettings = ref.watch(finampSettingsProvider.locale);
    return RadioListTile<Locale?>(
      title: Text(locale?.nativeDisplayLanguageScript ?? AppLocalizations.of(context)!.system),
      subtitle: locale != null
          ? Text(
              localeFromSettings != null
                  ? "${locale!.displayLanguageScriptIn(localeFromSettings)}${locale!.countryCode != null ? " (${locale!.displayCountryIn(localeFromSettings)})" : ""}"
                  : "${locale!.defaultDisplayLanguageScript}${locale!.countryCode != null ? " (${locale!.defaultDisplayCountry})" : ""}",
            )
          : null,
      value: locale,
    );
  }
}
