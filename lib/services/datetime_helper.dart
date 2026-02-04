import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:finamp/utils/locale_helper.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/finamp_models.dart';
import '../models/jellyfin_models.dart';

class ReleaseDateHelper {
  /// Formats the release date of a [BaseItemDto] based on the user's settings.
  static String? autoFormat(BaseItemDto? baseItem) {
    final format = FinampSettingsHelper.finampSettings.releaseDateFormat;
    final locale = getDateFormatLocaleString();

    final premiereDate = baseItem?.premiereDate != null ? DateTime.parse(baseItem!.premiereDate!) : null;
    if (premiereDate == null) {
      return baseItem?.productionYear?.toString();
    }
    switch (format) {
      case ReleaseDateFormat.year:
        return DateFormat.y(locale).format(premiereDate);
      case ReleaseDateFormat.iso:
        return premiereDate.toIso8601String().split("T").first;
      case ReleaseDateFormat.monthYear:
        return "${DateFormat.MMMM(locale).format(premiereDate)} ${DateFormat.y(locale).format(premiereDate)}";
      case ReleaseDateFormat.monthDayYear:
        return "${DateFormat.MMMM(locale).format(premiereDate)} ${DateFormat.d(locale).format(premiereDate)}, ${DateFormat.y(locale).format(premiereDate)}";
    }
  }
}

class DateTimeHelper {
  static String format(DateTime dateTime) {
    final now = DateTime.now();
    final locale = getDateFormatLocaleString();

    final isSameDay = dateTime.year == now.year && dateTime.month == now.month && dateTime.day == now.day;

    if (isSameDay) {
      final formatted = DateFormat.jm(locale).format(dateTime);
      final is12HourClock = formatted.toLowerCase().contains(RegExp(r'am|pm'));

      return is12HourClock ? formatted : (formatted.contains(':') ? formatted : '$formatted:00');
    }

    final isSameYear = dateTime.year == now.year;
    final format = isSameYear ? DateFormat.MMMMd(locale) : DateFormat.yMMMd(locale);

    return format.format(dateTime);
  }

  static String? formatFromString(String? dateString) {
    if (dateString == null) return null;

    try {
      final parsed = DateTime.parse(dateString);
      return format(parsed);
    } catch (e) {
      return null;
    }
  }

  static String formatRelativeTime({
    required BuildContext context,
    required DateTime dateTime,
    bool includeStaticDateTime = false,
  }) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);
    final l10n = AppLocalizations.of(context)!;
    final staticDateTime = includeStaticDateTime ? DateTimeHelper.format(dateTime) : null;

    String wrap(String type, int value) {
      final base = l10n.formattedRelativeTime(type, value);
      return includeStaticDateTime ? "$base ($staticDateTime)" : base;
    }

    if (diff.inMinutes < 1) {
      return l10n.formattedRelativeTime('just_now', 0);
    }
    if (diff.inMinutes < 60) {
      return wrap('minutes', diff.inMinutes);
    }
    if (diff.inHours < 24 && now.day == dateTime.day && now.month == dateTime.month && now.year == dateTime.year) {
      return wrap('hours', diff.inHours);
    }

    final nowMidnight = DateTime(now.year, now.month, now.day);
    final yesterdayMidnight = nowMidnight.subtract(const Duration(days: 1));

    if (dateTime.isAfter(yesterdayMidnight)) {
      return wrap('yesterday', 0);
    } else if (dateTime.isBefore(yesterdayMidnight)) {
      final dateTimeDay = DateTime(dateTime.year, dateTime.month, dateTime.day);
      final daysAgo = nowMidnight.difference(dateTimeDay).inDays;
      if (daysAgo < 7) {
        return wrap('days', daysAgo);
      }
    }

    final isSameYear = dateTime.year == now.year;
    final locale = getDateFormatLocaleString();
    final format = isSameYear ? DateFormat.MMMMd(locale) : DateFormat.yMMMd(locale);

    return format.format(dateTime);
  }

  static String? formatRelativeTimeFromString({
    required BuildContext context,
    String? dateString,
    bool includeStaticDateTime = false,
  }) {
    if (dateString == null) return null;

    try {
      final parsed = DateTime.parse(dateString);
      return formatRelativeTime(context: context, dateTime: parsed, includeStaticDateTime: includeStaticDateTime);
    } catch (e) {
      return null;
    }
  }

  static Stream<DateTime> get minuteTicker => Stream.periodic(const Duration(minutes: 1), (_) => DateTime.now());
}

class RelativeDateTimeText extends StatelessWidget {
  final DateTime dateTime;
  final TextStyle? style;
  final bool includeStaticDateTime;
  final bool disableTextScaling;

  const RelativeDateTimeText({
    required this.dateTime,
    this.style,
    this.includeStaticDateTime = false,
    this.disableTextScaling = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DateTime>(
      stream: DateTimeHelper.minuteTicker,
      initialData: DateTime.now(),
      builder: (context, snapshot) {
        final text = DateTimeHelper.formatRelativeTime(
          context: context,
          dateTime: dateTime,
          includeStaticDateTime: includeStaticDateTime,
        );
        return Text(text, style: style, textScaler: disableTextScaling ? TextScaler.noScaling : null);
      },
    );
  }
}

class RelativeDateTimeTextFromString extends StatelessWidget {
  final String? dateString;
  final TextStyle? style;
  final String? fallback;
  final bool includeStaticDateTime;
  final bool disableTextScaling;

  const RelativeDateTimeTextFromString({
    required this.dateString,
    this.style,
    this.fallback,
    this.includeStaticDateTime = false,
    this.disableTextScaling = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    DateTime? parsed;

    try {
      parsed = DateTime.parse(dateString!);
    } catch (_) {}

    final String fallbackText = fallback ?? AppLocalizations.of(context)!.unknown;

    if (parsed == null) {
      return Text(fallbackText, style: style, textScaler: disableTextScaling ? TextScaler.noScaling : null);
    }

    return RelativeDateTimeText(
      dateTime: parsed,
      style: style,
      includeStaticDateTime: includeStaticDateTime,
      disableTextScaling: disableTextScaling,
    );
  }
}
