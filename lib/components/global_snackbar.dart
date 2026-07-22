import 'dart:async';
import 'dart:io';

import 'package:chopper/chopper.dart';
import 'package:finamp/components/themed_bottom_sheet.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/menus/components/menuEntries/dismiss_all_snackbars_menu_entry.dart';
import 'package:finamp/menus/components/menuEntries/menu_entry.dart';
import 'package:finamp/menus/components/menuEntries/view_logs_menu_entry.dart';
import 'package:finamp/menus/components/menu_item_info_header.dart';
import 'package:finamp/services/feedback_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_sticky_header/flutter_sticky_header.dart';
import 'package:http/http.dart' hide Response;
import 'package:logging/logging.dart';

import '../l10n/app_localizations_en.dart';

typedef _QueueFunction = void Function(BuildContext);

@Deprecated("Use GlobalSnackbar.error(dynamic error) instead")
void errorSnackbar(dynamic error, BuildContext context) => GlobalSnackbar.error(error);

class GlobalSnackbar {
  /// Prefer using state and localization getters.  Avoid directly accessing context.
  @Deprecated("Prefer using state and localization getters.  Avoid directly accessing context.")
  static final GlobalKey<ScaffoldMessengerState> rawMaterialAppScaffoldKey = LabeledGlobalKey("MaterialApp Scaffold");

  /// Prefer using state and localization getters.  Avoid directly accessing context.
  @Deprecated("Prefer using state and localization getters.  Avoid directly accessing context.")
  static final GlobalKey<NavigatorState> rawMaterialAppNavigatorKey = LabeledGlobalKey("MaterialApp Navigator");

  static ScaffoldMessengerState? get scaffoldState => rawMaterialAppScaffoldKey.currentState;
  static NavigatorState? get navigatorState => rawMaterialAppNavigatorKey.currentState;
  static AppLocalizations? get _contextL10n {
    final context = rawMaterialAppNavigatorKey.currentContext;
    if (context != null && context.mounted) {
      final localization = AppLocalizations.of(context);
      if (localization != null) {
        _localizationsCache = localization;
      }
      return localization;
    }
    return null;
  }

  static final englishL10n = AppLocalizationsEn();
  static AppLocalizations? _localizationsCache;

  static AppLocalizations get requireL10n => _contextL10n ?? _localizationsCache ?? englishL10n;

  static final _logger = Logger("GlobalSnackbar");

  static final List<_QueueFunction> _queue = [];

  static Timer? _timer;

  // Tracks currently displayed network error keys for dedup while any matching snackbar is visible.
  static final Set<String> _activeErrorKeys = <String>{};

  /// It is possible for some GlobalSnackbar methods to be called before app
  /// startup completes.  If this happens, we delay executing the function
  /// until the MaterialApp has been set up.
  static void _enqueue(_QueueFunction func) {
    // We want to specifically use the navigator context here because it is the innermost object of the MaterialApp and
    // has all global context present.  The scaffold context is missing most global state.
    final enqueueContext = rawMaterialAppNavigatorKey.currentContext;
    if (scaffoldState != null && (enqueueContext?.mounted ?? false)) {
      // Schedule snackbar creation for as soon as possible outside of build()
      SchedulerBinding.instance.scheduleTask(() {
        if (scaffoldState == null || !(enqueueContext?.mounted ?? false)) {
          _logger.warning("Global Snackbar context unmounted during async gap.");
          _enqueue(func);
        } else {
          func(enqueueContext!);
        }
      }, Priority.touch);
    } else {
      _queue.add(func);
      _timer ??= Timer.periodic(const Duration(seconds: 1), (timer) {
        final timerContext = rawMaterialAppNavigatorKey.currentContext;
        if (scaffoldState != null && (timerContext?.mounted ?? false)) {
          timer.cancel();
          _timer = null;
          for (var queuedFunc in _queue) {
            queuedFunc(timerContext!);
          }
          _queue.clear();
        }
      });
    }
  }

  static void dismissAllSnackbars() {
    FeedbackHelper.feedback(FeedbackType.selection);
    if (scaffoldState != null) {
      scaffoldState!.clearSnackBars();
    }
    _activeErrorKeys.clear();
    _queue.clear();
    _timer?.cancel();
    _timer = null;
  }

  /// Show a snackbar to the user using the local context
  static void showPrebuilt(SnackBar snackbar) => _enqueue((_) => _showPrebuilt(snackbar));
  static void _showPrebuilt(SnackBar snackbar) {
    scaffoldState!.showSnackBar(snackbar);
  }

  /// Show a snackbar to the user using the global context
  static void show(SnackBar Function(BuildContext scaffold) snackbar) =>
      _enqueue((context) => _show(context, snackbar));
  static void _show(BuildContext context, SnackBar Function(BuildContext scaffold) snackbar) {
    scaffoldState!.showSnackBar(snackbar(context));
  }

  /// Show a localized message to the user using the global context
  static void message(
    String Function(BuildContext scaffold) message, {
    bool isConfirmation = false,
    SnackBarAction Function(BuildContext scaffold)? action,
  }) => _enqueue((context) => _message(context, message, isConfirmation, action));
  static void _message(
    BuildContext context,
    String Function(BuildContext scaffold) message,
    bool isConfirmation,
    SnackBarAction Function(BuildContext scaffold)? action,
  ) {
    var text = message(context);
    _logger.info("Displaying message: $text");
    scaffoldState!.showSnackBar(
      SnackBar(
        content: GestureDetector(
          onLongPress: () {
            if (context.mounted) {
              showSnackbarOptionsMenu(context);
            }
          },
          onSecondaryTap: () {
            if (context.mounted) {
              showSnackbarOptionsMenu(context);
            }
          },
          child: Text(text),
        ),
        actionOverflowThreshold: 0.5,
        duration: (isConfirmation && action == null) ? const Duration(milliseconds: 1500) : const Duration(seconds: 4),
        action: action?.call(context),
        persist: false,
      ),
    );
  }

  /// Show an unlocalized error message to the user
  static void error(dynamic event) => _enqueue((context) => _error(context, event));
  static void _error(BuildContext context, dynamic event) {
    // Suppress common transient network error "Failed host lookup"
    bool suppressError = false;
    if (event is SocketException || event is ClientException) {
      suppressError =
          event.toString().contains("Failed host lookup") || event.toString().contains("HTTP connection timed out");
    } else if (event is TimeoutException) {
      suppressError = true;
    } else if (event is Response && event.error is SocketException) {
      suppressError = event.error.toString().contains("Failed host lookup");
    } else {
      suppressError =
          event.toString().contains("Failed host lookup") ||
          event.toString().contains("Could not fetch the response for GET");
    }

    if (suppressError) {
      _logger.fine("Suppressed error: $event", event);
      return;
    }

    _logger.warning("Displaying error: $event", event);
    String errorText;
    if (event is Response) {
      if (event.statusCode == 401) {
        errorText = AppLocalizations.of(context)!.responseError401(event.error.toString(), event.statusCode);
      } else {
        errorText = AppLocalizations.of(context)!.responseError(event.error.toString(), event.statusCode);
      }
    } else {
      errorText = event.toString();
    }
    // Only dedup NETWORK errors. Dedup is based on error "type", not URL/content.
    bool isNetworkError =
        event is SocketException ||
        event is ClientException ||
        (event is Response && (event.error is SocketException || event.error is ClientException));

    String? dedupKey;
    if (isNetworkError) {
      if (event is Response) {
        // Use status code + underlying error type (avoid including URL or body)
        final underlying = event.error;
        dedupKey = "network:${event.statusCode}:${underlying.runtimeType}";
      } else {
        dedupKey = "network:${event.runtimeType}";
      }

      if (_activeErrorKeys.contains(dedupKey)) {
        _logger.fine("Duplicate network error suppressed: $dedupKey");
        return;
      }
      _activeErrorKeys.add(dedupKey); // add to active keys
    }

    // give immediate feedback that something went wrong
    FeedbackHelper.feedback(FeedbackType.warning);
    final controller = scaffoldState!.showSnackBar(
      SnackBar(
        content: GestureDetector(
          onLongPress: () {
            if (context.mounted) {
              showSnackbarOptionsMenu(context);
            }
          },
          onSecondaryTap: () {
            if (context.mounted) {
              showSnackbarOptionsMenu(context);
            }
          },
          child: Text(AppLocalizations.of(context)!.anErrorHasOccured),
        ),
        action: SnackBarAction(
          label: MaterialLocalizations.of(context).moreButtonTooltip,
          onPressed: () => showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(AppLocalizations.of(context)!.error),
              content: Text(errorText),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(MaterialLocalizations.of(context).closeButtonLabel),
                ),
              ],
            ),
          ),
        ),
        duration: const Duration(seconds: 4),
        persist: false,
      ),
    );

    // When this snackbar fully closes (timeout or swipe), clear the key if it matches, allowing future identical errors.
    if (dedupKey != null) {
      controller.closed.then((reason) {
        if (_activeErrorKeys.remove(dedupKey)) {
          _logger.fine("Removed active error key after dismissal: $dedupKey (reason: $reason)");
        }
      });
    }
  }

  /// Show a localized message to the user using the global context
  static void popup(
    (String, String) Function(BuildContext scaffold) message, {
    bool isConfirmation = false,
    SnackBarAction Function(BuildContext scaffold)? action,
  }) => _enqueue((context) => _popup(context, message, isConfirmation, action));
  static void _popup(
    BuildContext context,
    (String, String) Function(BuildContext scaffold) message,
    bool isConfirmation,
    SnackBarAction Function(BuildContext scaffold)? action,
  ) {
    var text = message(context);
    _logger.info("Displaying message: $text");
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(text.$1),
        content: Text(text.$2),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(MaterialLocalizations.of(context).closeButtonLabel),
          ),
        ],
      ),
    );
  }

  static const snackbarOptionsRoute = "/snackbar-options";
  static Future<void> showSnackbarOptionsMenu(BuildContext context) async {
    FeedbackHelper.feedback(FeedbackType.selection);

    // Normal menu entries, excluding headers
    List<HideableMenuEntry> getMenuEntries(BuildContext context) {
      return [DismissAllSnackbarsMenuEntry(), ViewLogsMenuEntry()];
    }

    (double, List<Widget>) getMenuProperties(BuildContext context) {
      final menuEntries = getMenuEntries(context);
      final stackHeight = ThemedBottomSheet.calculateStackHeight(
        context: context,
        menuEntries: menuEntries,
        extraHeight: -infoHeaderFullExtent,
      );

      List<Widget> menu = [
        SliverStickyHeader(
          header: SnackbarOptionsMenuHeader(),
          sliver: MenuMask(
            height: SnackbarOptionsMenuHeader.defaultHeight,
            child: SliverPadding(
              padding: const EdgeInsets.only(left: 8.0),
              sliver: SliverList(delegate: SliverChildListDelegate(menuEntries)),
            ),
          ),
        ),
      ];

      return (stackHeight, menu);
    }

    await showThemedBottomSheet<void>(
      context: context,
      routeName: snackbarOptionsRoute,
      minDraggableHeight: 0.15,
      buildSlivers: getMenuProperties,
    );
  }
}

class SnackbarOptionsMenuHeader extends StatelessWidget {
  const SnackbarOptionsMenuHeader({super.key});

  static const defaultHeight = MenuMaskHeight(36.0);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6.0, bottom: 16.0),
      child: Center(
        child: Text(
          AppLocalizations.of(context)!.snackbarOptionsMenuTitle,
          style: TextStyle(
            color: Theme.of(context).textTheme.bodyLarge!.color!,
            fontSize: 18,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
