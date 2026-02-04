import 'package:intl/intl.dart';
import 'package:intl/src/intl_helpers.dart';

import '../services/finamp_settings_helper.dart';

String getDateFormatLocaleString() {
  final locale = FinampSettingsHelper.finampSettings.locale;
  var localeString = locale != null
      ? (locale.countryCode != null
            ? "${locale.languageCode.toLowerCase()}_${locale.countryCode?.toUpperCase()}"
            : locale.toString())
      : null;
  // Fall back to english date formating if using a language with no data, like klingon.
  // We need to use the internal intl helper method verifiedLocale to preserve the full fallback behavior of DateFormat.
  return verifiedLocale(localeString, DateFormat.localeExists, (failedLocale) => 'en_US')!;
}
