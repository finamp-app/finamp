import 'dart:async';
import 'dart:io';

import 'package:finamp/components/finamp_app_bar_back_button.dart';
import 'package:finamp/components/finamp_icon.dart';
import 'package:finamp/extensions/color_extensions.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/menus/components/icon_button_with_semantics.dart';
import 'package:finamp/menus/music_screen_drawer.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/screens/settings_screen.dart';
import 'package:finamp/screens/tabs_settings_screen.dart';
import 'package:finamp/services/downloads_service.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:finamp/services/finamp_user_helper.dart';
import 'package:finamp/services/jellyfin_api_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:get_it/get_it.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:simple_gesture_detector/simple_gesture_detector.dart';

class FinampMusicScreenHeader extends ConsumerWidget implements PreferredSizeWidget {
  final List<TabContentType> sortedTabs;
  final TabController? tabController;
  final VoidCallback? onSearch;
  final VoidCallback? onStopSearch;
  final TextEditingController textEditingController;
  final bool isSearching;
  final bool backButtonInsteadOfTabs;
  final String? title;
  final void Function(String)? onUpdateSearchQuery;
  final void Function() refreshTab;

  FinampMusicScreenHeader({
    super.key,
    required this.sortedTabs,
    required this.tabController,
    required this.textEditingController,
    required this.isSearching,
    required this.refreshTab,
    this.backButtonInsteadOfTabs = false,
    this.title,
    this.onSearch,
    this.onStopSearch,
    this.onUpdateSearchQuery,
  });

  final finampUserHelper = GetIt.instance<FinampUserHelper>();
  final jellyfinApiHelper = GetIt.instance<JellyfinApiHelper>();

  double get _upperToolbarHeight => kToolbarHeight - 12;

  @override
  Size get preferredSize => Size.fromHeight(
    _upperToolbarHeight +
        ((Platform.isLinux || Platform.isWindows || Platform.isMacOS) ? 12.0 : 0) +
        (backButtonInsteadOfTabs ? 0 : 42),
  ); // Standard height

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Timer? debounce;

    final activeTabBackgroundColor = ColorScheme.of(context).primaryContainer;
    final inactiveTabBackgroundColor = ColorScheme.of(context).surface;
    Color activeTabTextColor = AtContrast.getContrastiveTintedTextColor(onBackground: activeTabBackgroundColor);
    Color inactiveTabTextColor = AtContrast.getContrastiveTintedTextColor(onBackground: inactiveTabBackgroundColor);

    final statusIcon = ref.watch(finampSettingsProvider.isOffline)
        ? TablerIcons.plug_connected_x
        : ref.watch(FinampUserHelper.finampCurrentUserProvider).valueOrNull?.isLocal ?? false
        ? TablerIcons.server_bolt
        : null; // hide icon by default (remote connection)

    return Column(
      spacing: 8.0,
      children: [
        SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 12.0,
              right: 6.0,
              top: (Platform.isLinux || Platform.isWindows || Platform.isMacOS) ? 12.0 : 0.0,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              mainAxisSize: MainAxisSize.max,
              children: [
                if (backButtonInsteadOfTabs)
                  SizedBox(width: _upperToolbarHeight + 6, height: _upperToolbarHeight, child: FinampAppBarBackButton())
                else
                  SimpleGestureDetector(
                    onTap: () {
                      // open drawer
                      // Scaffold.of(context).openDrawer();
                      showFinampMainMenu(context: context);
                    },
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        FinampIcon(
                          36,
                          36,
                          overrideColor: ref.watch(finampSettingsProvider.isOffline)
                              ? TextTheme.of(context).bodyMedium?.color?.withOpacity(0.6)
                              : null,
                        ),
                        Positioned(bottom: -4, right: -2, child: Icon(statusIcon, size: 16)),
                        Consumer(
                          builder: (context, ref, _) {
                            if (ref.watch(pollingDownloadsSyncingProvider)) {
                              return Positioned(
                                bottom: statusIcon != null ? -6 : 1,
                                right: statusIcon != null ? -4 : 3,
                                child: SizedBox.square(
                                  dimension: statusIcon != null ? 20.0 : 10.0,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1,
                                    valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.onSurface),
                                  ),
                                ),
                              );
                            } else {
                              return SizedBox.shrink();
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                const SizedBox(width: 8),
                if (isSearching) ...[
                  Expanded(
                    child: TextField(
                      controller: textEditingController,
                      autocorrect: false, // avoid autocorrect
                      enableSuggestions: true, // keep suggestions which can be manually selected
                      autofocus: true,
                      keyboardType: TextInputType.text,
                      textInputAction: TextInputAction.search,
                      onChanged: (value) {
                        if (debounce?.isActive ?? false) debounce!.cancel();
                        debounce = Timer(const Duration(milliseconds: 400), () {
                          onUpdateSearchQuery?.call(value);
                        });
                      },
                      onSubmitted: (value) => onUpdateSearchQuery?.call(value),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: MaterialLocalizations.of(context).searchFieldLabel,
                        contentPadding: EdgeInsets.only(left: 4.0, top: 8.0, bottom: 8.0),
                        isDense: true,
                      ),
                    ),
                  ),
                  IconButtonWithSemantics(
                    icon: TablerIcons.x,
                    label: AppLocalizations.of(context)!.clear,
                    onPressed: () {
                      onStopSearch?.call();
                    },
                    visualDensity: VisualDensity(horizontal: 0, vertical: -4),
                  ),
                ] else ...[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: () {
                            if (title == null) {
                              showFinampMainMenu(context: context);
                            }
                          },
                          child: FutureBuilder(
                            future: PackageInfo.fromPlatform(),
                            builder: (context, asyncSnapshot) {
                              final appName = asyncSnapshot.data?.appName ?? AppLocalizations.of(context)!.finamp;
                              return Text(
                                title ?? finampUserHelper.currentUser?.currentView?.name ?? appName,
                                style: TextStyle(fontSize: 22),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!Platform.isIOS && !Platform.isAndroid)
                    IconButtonWithSemantics(
                      label: "Refresh*",
                      icon: TablerIcons.refresh,
                      iconSize: 28.0,
                      onPressed: () {
                        refreshTab();
                      },
                    ),
                  IconButtonWithSemantics(
                    label: "Search*",
                    icon: TablerIcons.search,
                    iconSize: 28.0,
                    onPressed: () {
                      if (onSearch != null) {
                        onSearch!();
                      }
                    },
                  ),
                ],
                IconButtonWithSemantics(
                  label: "Menu*",
                  icon: TablerIcons.dots,
                  iconSize: 28.0,
                  onPressed: () {
                    // Scaffold.of(context).openDrawer();
                    showFinampMainMenu(context: context);
                  },
                  onLongPress: () {
                    Navigator.pushNamed(context, SettingsScreen.routeName);
                  },
                ),
              ],
            ),
          ),
        ),
        if (!backButtonInsteadOfTabs)
          TabBar(
            controller: tabController,
            indicator: BoxDecoration(borderRadius: BorderRadius.circular(8.0), color: activeTabBackgroundColor),
            indicatorPadding: EdgeInsets.zero,
            splashBorderRadius: BorderRadius.circular(8.0),
            labelColor: activeTabTextColor,
            // unselectedLabelColor: Colors.red, //!!! the label color is specified below, along with the font
            labelPadding: EdgeInsets.symmetric(horizontal: 4.0),
            dividerHeight: 0.0,
            dividerColor: Colors.transparent,
            padding: EdgeInsets.only(top: 2.0, bottom: 2.0, left: 12.0, right: 6.0),
            tabs: sortedTabs.map((tabType) {
              final textStyle = tabController?.index == sortedTabs.indexOf(tabType)
                  ? null
                  : TextTheme.of(context).bodyMedium!.copyWith(color: inactiveTabTextColor);
              return Tab(
                height: 32.0,
                child: GestureDetector(
                  onLongPress: () {
                    Navigator.pushNamed(context, TabsSettingsScreen.routeName);
                  },
                  onSecondaryTap: () {
                    Navigator.pushNamed(context, TabsSettingsScreen.routeName);
                  },
                  child: Container(
                    /*decoration: ShapeDecoration(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                        side: BorderSide(
                          color: tabController?.index == sortedTabs.indexOf(tabType)
                              ? Theme.of(context).colorScheme.primaryContainer
                              : ColorScheme.of(context).outlineVariant,
                          strokeAlign: 1.0,
                          width: 1.5,
                        ),
                      ),
                    ),*/
                    padding: tabType == TabContentType.home
                        ? EdgeInsets.only(left: 4, right: 8, top: 3, bottom: 3)
                        : EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    constraints: const BoxConstraints(minWidth: 50),
                    alignment: Alignment.center,
                    child: tabType == TabContentType.home
                        ? Row(
                            spacing: 4.0,
                            children: [
                              if (ref.watch(finampSettingsProvider.isOffline))
                                SizedBox.shrink()
                              else
                                switch (ref.watch(currentUserInfoProvider)) {
                                  AsyncData(:final value)
                                      when value != null && value.jellyfinUser?.primaryImageTag != null =>
                                    Padding(
                                      padding: const EdgeInsets.all(1.5),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(9999),
                                        child: Image.network(
                                          GetIt.instance<JellyfinApiHelper>()
                                              .getUserImageUrl(
                                                baseUrl: Uri.parse(finampUserHelper.currentUser!.baseURL),
                                                user: value.jellyfinUser!,
                                              )
                                              .toString(),
                                          fit: BoxFit.fitHeight,
                                        ),
                                      ),
                                    ),
                                  AsyncData(:final value)
                                      when value == null || value.jellyfinUser?.primaryImageTag == null =>
                                    SizedBox.shrink(),
                                  AsyncLoading() => SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: activeTabTextColor),
                                  ),
                                  _ => SizedBox.shrink(),
                                },
                              Text(tabType.toLocalisedString(context), style: textStyle),
                            ],
                          )
                        : Text(tabType.toLocalisedString(context), style: textStyle),
                  ),
                ),
              );
            }).toList(),
            isScrollable: true,
            tabAlignment: TabAlignment.start,
          ),
      ],
    );
  }
}

final pollingDownloadsSyncingProvider = Provider((Ref ref) {
  final downloadsService = GetIt.instance<DownloadsService>();
  // Schedule this provider to be re-polled in 4 seconds
  Timer(Duration(seconds: 4), ref.invalidateSelf);
  // TODO do we want to show downloading separate from syncing?
  return downloadsService.syncBuffer.isRunning ||
      downloadsService.deleteBuffer.isRunning ||
      downloadsService.downloadTaskQueue.isRunning;
});
