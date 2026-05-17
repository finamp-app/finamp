import 'dart:io';

import 'package:collection/collection.dart';
import 'package:finamp/components/Buttons/cta_medium.dart';
import 'package:finamp/components/Buttons/simple_button.dart';
import 'package:finamp/components/HomeScreen/home_screen_content.dart';
import 'package:finamp/components/MusicScreen/item_wrapper.dart';
import 'package:finamp/components/MusicScreen/sort_and_filter_row.dart';
import 'package:finamp/components/SettingsScreen/finamp_settings_dropdown.dart';
import 'package:finamp/components/finamp_app_bar_back_button.dart';
import 'package:finamp/components/global_snackbar.dart';
import 'package:finamp/components/themed_bottom_sheet.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/menus/choice_menu.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/services/feedback_helper.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:finamp/services/item_by_id_provider.dart';
import 'package:finamp/services/jellyfin_api_helper.dart';
import 'package:finamp/services/music_screen_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_sticky_header/flutter_sticky_header.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../extensions/localizations.dart';

class HomeScreenSettingsScreen extends StatefulWidget {
  const HomeScreenSettingsScreen({super.key});
  static const routeName = "/settings/home-screen";
  @override
  State<HomeScreenSettingsScreen> createState() => _HomeScreenSettingsScreenState();
}

class _HomeScreenSettingsScreenState extends State<HomeScreenSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.homeScreenSettingsTitle),
        leading: FinampAppBarBackButton(),
        actions: [
          FinampSettingsHelper.makeSettingsResetButtonWithDialog(context, FinampSettingsHelper.resetHomeScreenSettings),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 150.0),
          children: [const QuickActionsSelector(), const HomeScreenSectionsSelector()],
        ),
      ),
    );
  }
}

class QuickActionsSelector extends ConsumerWidget {
  const QuickActionsSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quickActions = ref.watch(finampSettingsProvider.homeScreenConfiguration).actions;
    return Padding(
      padding: const EdgeInsets.only(bottom: 28.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.max,
        children: [
          ListTile(title: Text(context.l10n.quickActions), subtitle: Text(context.l10n.quickActionsSubtitle)),
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            proxyDecorator: (child, _, _) => Material(type: MaterialType.transparency, child: child),
            itemBuilder: (context, index) {
              final action = quickActions[index];
              return Padding(
                key: ValueKey("quick-action-$action-$index"),
                padding: const EdgeInsets.only(bottom: 8.0, left: 12.0, right: 12.0),
                child: ListTile(
                  tileColor: Color.alphaBlend(
                    ColorScheme.of(context).primary.withOpacity(0.05),
                    ColorScheme.of(context).surface,
                  ),
                  title: Padding(padding: const EdgeInsets.only(left: 4.0), child: Text(action.getTitle(context))),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                  visualDensity: VisualDensity(horizontal: -4, vertical: -4),
                  contentPadding: EdgeInsets.only(left: 6.0),
                  leading: ReorderableDragStartListener(
                    index: index,
                    key: ValueKey("drag-handle-quick-action-$action-$index"),
                    child: const Icon(Icons.drag_handle),
                  ),
                  subtitle: Row(
                    mainAxisSize: MainAxisSize.max,
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Visibility(
                        maintainAnimation: true,
                        maintainSize: true,
                        maintainState: true,
                        visible: action.action.editable,
                        child: SimpleButton.small(
                          text: context.l10n.editAction,
                          icon: TablerIcons.edit,
                          onPressed: () => editQuickAction(context, index),
                        ),
                      ),
                      SimpleButton.small(
                        text: context.l10n.removeAction,
                        icon: TablerIcons.trash,
                        onPressed: () {
                          final newHomeScreenConfig = FinampSettingsHelper.finampSettings.homeScreenConfiguration
                              .copyWith(
                                actions: [...quickActions.sublist(0, index), ...quickActions.sublist(index + 1)],
                              );
                          FinampSetters.setHomeScreenConfiguration(newHomeScreenConfig);
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
            itemCount: quickActions.length,
            onReorder: (originalIndex, newIndex) {
              if (originalIndex < newIndex) {
                newIndex -= 1;
              }
              final action = quickActions[originalIndex];
              final newActions = [...quickActions];
              newActions.removeAt(originalIndex);
              newActions.insert(newIndex, action);
              final newHomeScreenConfig = FinampSettingsHelper.finampSettings.homeScreenConfiguration.copyWith(
                actions: newActions,
              );
              FinampSetters.setHomeScreenConfiguration(newHomeScreenConfig);
            },
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4.0, left: 16.0, right: 16.0),
            child: CTAMedium(
              text: context.l10n.addNewAction,
              icon: TablerIcons.plus,
              onPressed: () async {
                final selectedAction = await showQuickActionPresetPickerMenu(context, null);
                if (selectedAction != null) {
                  final newHomeScreenConfig = FinampSettingsHelper.finampSettings.homeScreenConfiguration.copyWith(
                    actions: [...quickActions, selectedAction],
                  );
                  FinampSetters.setHomeScreenConfiguration(newHomeScreenConfig);
                }
              },
              disabled: quickActions.length >= FinampQuickActions.values.length,
            ),
          ),
        ],
      ),
    );
  }
}

const quickActionPickerMenuRouteName = "/quick-action-preset-picker-menu";

Future<void> editQuickAction(BuildContext context, int index) async {
  if (!context.mounted) return;
  final quickActions = FinampSettingsHelper.finampSettings.homeScreenConfiguration.actions;
  final selectedAction = await showQuickActionPresetPickerMenu(context, quickActions[index]);
  if (selectedAction != null) {
    final newHomeScreenConfig = FinampSettingsHelper.finampSettings.homeScreenConfiguration.copyWith(
      actions: [...quickActions]..[index] = selectedAction,
    );
    FinampSetters.setHomeScreenConfiguration(newHomeScreenConfig);
  }
}

Future<QuickActionConfig?> showQuickActionPresetPickerMenu(BuildContext context, QuickActionConfig? initialValue) {
  return showThemedBottomSheet<QuickActionConfig?>(
    context: context,
    routeName: quickActionPickerMenuRouteName,
    minDraggableHeight: 0.25,
    buildWrapper: (context, _, buildChildren) {
      return QuickActionConfigMenu(buildChildren: buildChildren, initialValue: initialValue);
    },
  );
}

class QuickActionConfigMenu extends ConsumerStatefulWidget {
  final ScrollBuilder buildChildren;
  final QuickActionConfig? initialValue;

  const QuickActionConfigMenu({super.key, required this.buildChildren, this.initialValue});

  @override
  QuickActionConfigMenuState createState() => QuickActionConfigMenuState();
}

class QuickActionConfigMenuState extends ConsumerState<QuickActionConfigMenu> {
  FinampQuickActions? selected;
  final ValueNotifier<BaseItemDto?> notifier = ValueNotifier(null);

  @override
  void initState() {
    if (widget.initialValue?.action.editable ?? false) {
      selected = widget.initialValue?.action;
    }
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> menuItems;
    final double stackHeight;
    if (selected == null) {
      menuItems = _buildSelector();
      // header + menu entries
      stackHeight = 42.0 + menuItems.length * ((Platform.isAndroid || Platform.isIOS) ? 72.0 : 64.0);
    } else {
      final searchHeight = MediaQuery.sizeOf(context).height * 0.5;
      menuItems = _buildItemSelector(height: searchHeight);
      // header + menu entries
      stackHeight = 42.0 + searchHeight;
    }

    final menu = [
      SliverStickyHeader(
        header: Padding(
          padding: const EdgeInsets.only(top: 10.0, bottom: 8.0, left: 16.0, right: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 2.0,
            children: [
              Text(switch (selected) {
                FinampQuickActions.playSpecificItem => context.l10n.selectAnItem,
                _ => AppLocalizations.of(context)!.homeScreenQuickActionPickerMenuTitle,
              }, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
        ),
        sliver: MenuMask(
          height: MenuMaskHeight(36.0),
          child: SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            sliver: SliverList.list(children: menuItems),
          ),
        ),
      ),
    ];
    return widget.buildChildren(stackHeight, menu);
  }

  List<Widget> _buildSelector() {
    return FinampQuickActions.values.map<Widget>((quickAction) {
      return Consumer(
        builder: (context, ref, child) {
          return ChoiceMenuOption(
            title: QuickActionConfig(action: quickAction).getTitle(context),
            description: quickAction.getDescription(context),
            badges: [
              // // similar mode is recommended
              // if (preset == RadioMode.similar && radioModeOptionAvailabilityStatus.isAvailable)
              //   Icon(TablerIcons.star, size: 14.0),
            ],
            enabled: true,
            icon: quickAction.getIcon(),
            isInactive: false,
            isSelected: quickAction == widget.initialValue?.action,
            onSelect: () async {
              //TODO ideally rebuild with check and then pop after delay
              // FeedbackHelper.feedback(FeedbackType.selection);
              // await Future<void>.delayed(const Duration(milliseconds: 400));
              // Navigator.of(context).pop(preset);
              if (quickAction.editable) {
                setState(() {
                  selected = quickAction;
                });
              } else {
                if (context.mounted) {
                  FeedbackHelper.feedback(FeedbackType.selection);
                  Navigator.of(context).pop(QuickActionConfig(action: quickAction));
                }
              }
            },
          );
        },
      );
    }).toList();
  }

  List<Widget> _buildItemSelector({required double height}) {
    // This is currently the only editable type
    assert(selected == FinampQuickActions.playSpecificItem);
    return [
      ChoiceMenuOption(
        title: context.l10n.back,
        enabled: true,
        icon: TablerIcons.chevron_left,
        isInactive: false,
        isSelected: false,
        onSelect: () => setState(() {
          selected = null;
        }),
      ),
      GlobalSearchBox(notifier, height: height, initialItem: widget.initialValue?.itemId, showTracks: true),
      SizedBox(height: 8.0),
      ValueListenableBuilder(
        valueListenable: notifier,
        builder: (context, value, _) {
          return CTAMedium(
            text: context.l10n.save,
            icon: TablerIcons.device_floppy,
            disabled: value == null,
            onPressed: () {
              if (context.mounted && value != null) {
                FeedbackHelper.feedback(FeedbackType.selection);
                Navigator.of(context).pop(
                  QuickActionConfig(
                    action: FinampQuickActions.playSpecificItem,
                    itemId: value.id,
                    itemName: value.name,
                  ),
                );
              }
            },
          );
        },
      ),
    ];
  }
}

class HomeScreenSectionsSelector extends ConsumerWidget {
  const HomeScreenSectionsSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sections = ref.watch(finampSettingsProvider.homeScreenConfiguration).sections;
    return Padding(
      padding: const EdgeInsets.only(bottom: 28.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(title: Text(context.l10n.sectionsMenu), subtitle: Text(context.l10n.sectionMenuSubtitle)),
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: sections.length,
            onReorderStart: (_) => FeedbackHelper.feedback(FeedbackType.light),
            proxyDecorator: (child, _, _) => Material(type: MaterialType.transparency, child: child),
            onReorder: (originalIndex, newIndex) {
              if (originalIndex < newIndex) newIndex -= 1;
              final section = sections[originalIndex];
              final newSections = [...sections];
              newSections.removeAt(originalIndex);
              newSections.insert(newIndex, section);
              final newHomeScreenConfig = FinampSettingsHelper.finampSettings.homeScreenConfiguration.copyWith(
                sections: newSections,
              );
              FinampSetters.setHomeScreenConfiguration(newHomeScreenConfig);
            },
            itemBuilder: (context, index) {
              final section = sections[index];
              return Padding(
                key: ValueKey("section-$section-$index"),
                padding: const EdgeInsets.only(bottom: 8.0, left: 12.0, right: 12.0),
                child: ListTile(
                  tileColor: Color.alphaBlend(
                    ColorScheme.of(context).primary.withOpacity(0.05),
                    ColorScheme.of(context).surface,
                  ),
                  title: Padding(padding: const EdgeInsets.only(left: 4.0), child: Text(section.getTitle(context))),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                  visualDensity: VisualDensity(horizontal: -4, vertical: -4),
                  contentPadding: EdgeInsets.only(left: 6.0),
                  leading: ReorderableDragStartListener(
                    index: index,
                    key: ValueKey("drag-handle-section-$section-$index"),
                    child: const Icon(Icons.drag_handle),
                  ),
                  subtitle: Row(
                    mainAxisSize: MainAxisSize.max,
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      SimpleButton.small(
                        text: context.l10n.editSection,
                        icon: TablerIcons.edit,
                        onPressed: () => editHomeScreenSection(context, index),
                      ),
                      SimpleButton.small(
                        text: context.l10n.removeSection,
                        icon: TablerIcons.trash,
                        onPressed: () {
                          FeedbackHelper.feedback(FeedbackType.warning);
                          final newHomeScreenConfig = FinampSettingsHelper.finampSettings.homeScreenConfiguration
                              .copyWith(sections: [...sections.sublist(0, index), ...sections.sublist(index + 1)]);
                          FinampSetters.setHomeScreenConfiguration(newHomeScreenConfig);
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4.0, left: 16.0, right: 16.0),
            child: CTAMedium(
              text: context.l10n.addNewSection,
              icon: TablerIcons.plus,
              onPressed: () async {
                //TODO dismissing the bottom sheet will be handles like selecting custom section
                final selectedPreset = await showSectionPresetPickerMenu(context);
                if (selectedPreset != null) {
                  final newSectionInfo = HomeScreenSectionConfiguration.fromPreset(selectedPreset);
                  final newHomeScreenConfig = FinampSettingsHelper.finampSettings.homeScreenConfiguration.copyWith(
                    sections: [...sections, newSectionInfo],
                  );
                  FinampSetters.setHomeScreenConfiguration(newHomeScreenConfig);
                } else if (context.mounted) {
                  final sections = List.of(FinampSettingsHelper.finampSettings.homeScreenConfiguration.sections);
                  final defaultSection = HomeScreenSectionConfiguration(
                    type: HomeScreenSectionType.tabView,
                    itemId: currentLibraryPlaceholder,
                    contentType: ContentType.tracks,
                    sortAndFilterConfiguration: SortAndFilterConfiguration(
                      sortBy: SortBy.sortName,
                      sortOrder: SortOrder.ascending,
                      filters: <ItemFilter>{},
                    ),
                  );
                  final newSection = await showHomeScreenSectionConfigurationMenu(context, defaultSection);
                  if (newSection != null) {
                    sections.add(newSection);
                    final newHomeScreenConfig = FinampSettingsHelper.finampSettings.homeScreenConfiguration.copyWith(
                      sections: sections,
                    );
                    FinampSetters.setHomeScreenConfiguration(newHomeScreenConfig);
                  }
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

Future<HomeScreenSectionConfiguration?> showHomeScreenSectionConfigurationMenu(
  BuildContext context,
  HomeScreenSectionConfiguration initialState,
) {
  return showThemedBottomSheet<HomeScreenSectionConfiguration?>(
    context: context,
    routeName: HomeScreenSectionConfigurationMenu.routeName,
    minDraggableHeight: HomeScreenSectionConfigurationMenu.initialSheetExtent,
    buildWrapper: (context, dragController, childBuilder) {
      return HomeScreenSectionConfigurationMenu(
        initialState: initialState,
        childBuilder: childBuilder,
        dragController: dragController,
      );
    },
  );
}

Future<void> editHomeScreenSection(BuildContext context, int index) async {
  if (!context.mounted) return;
  final sections = List.of(FinampSettingsHelper.finampSettings.homeScreenConfiguration.sections);
  final newSection = await showHomeScreenSectionConfigurationMenu(context, sections[index]);
  if (newSection != null) {
    sections[index] = newSection;
    final newHomeScreenConfig = FinampSettingsHelper.finampSettings.homeScreenConfiguration.copyWith(
      sections: sections,
    );
    FinampSetters.setHomeScreenConfiguration(newHomeScreenConfig);
  }
}

const Duration homeScreenSectionConfigurationMenuDefaultAnimationDuration = Duration(milliseconds: 500);
const Curve homeScreenSectionConfigurationMenuDefaultInCurve = Curves.easeOutCubic;
const Curve homeScreenSectionConfigurationMenuDefaultOutCurve = Curves.easeInCubic;

class HomeScreenSectionConfigurationMenu extends ConsumerStatefulWidget {
  static const routeName = "/home-screen-section-menu";

  static const initialSheetExtent = 0.85;

  const HomeScreenSectionConfigurationMenu({
    super.key,
    required this.childBuilder,
    required this.dragController,
    required this.initialState,
  });

  final ScrollBuilder childBuilder;
  final DraggableScrollableController dragController;
  final HomeScreenSectionConfiguration initialState;

  @override
  ConsumerState<HomeScreenSectionConfigurationMenu> createState() => _HomeScreenSectionConfigurationMenuState();
}

// TODO we should probably build separate sub-widgets for tabview/collections?
class _HomeScreenSectionConfigurationMenuState extends ConsumerState<HomeScreenSectionConfigurationMenu> {
  late HomeScreenSectionType selectedSectionType;

  // TODO the tab types should probably just be separate widgets.

  String tabTitle = "";
  LibraryOrItemId selectedLibrary = currentLibraryPlaceholder;
  ContentType tabContent = ContentType.tracks;
  StaticSortAndFilterController tabSortController = StaticSortAndFilterController(
    startingConfig: SortAndFilterConfiguration.defaultSort,
    contentType: ContentType.tracks,
    skipResolving: true,
  );

  String collectionTitle = "";
  BaseItemDto? selectedCollection;
  ContentType? collectionContent;
  StaticSortAndFilterController collectionSortController = StaticSortAndFilterController(
    startingConfig: SortAndFilterConfiguration.defaultSort,
    contentType: ContentType.tracks,
    skipResolving: true,
  );

  final ValueNotifier<BaseItemDto?> searchListener = ValueNotifier(null);

  @override
  void initState() {
    super.initState();

    final initialTitle = tabTitle =
        widget.initialState.customSectionTitle ??
        (widget.initialState.presetType != null
            // Widget context is not available yet
            ? widget.initialState.getTitle(GlobalSnackbar.materialAppScaffoldKey.currentContext!)
            : "");

    selectedSectionType = widget.initialState.type;

    switch (widget.initialState.type) {
      case HomeScreenSectionType.tabView:
        selectedLibrary = widget.initialState.itemId;
        tabContent = widget.initialState.contentType;
        tabSortController.updateConfiguration(widget.initialState.sortAndFilterConfiguration);
        tabTitle = initialTitle;
      case HomeScreenSectionType.collection:
        collectionSortController.updateConfiguration(widget.initialState.sortAndFilterConfiguration);
        collectionTitle = initialTitle;
      case HomeScreenSectionType.queues:
        break;
    }

    searchListener.addListener(() {
      setState(() {
        selectedCollection = searchListener.value;
        collectionTitle = searchListener.value?.name ?? "";
        if (searchListener.value != null) {
          switch (BaseItemDtoType.fromItem(searchListener.value!)) {
            case BaseItemDtoType.playlist:
            case BaseItemDtoType.album:
              collectionContent = ContentType.inPlaylist;
            case BaseItemDtoType.artist:
            case BaseItemDtoType.genre:
              collectionContent = ContentType.tracks;
            case BaseItemDtoType.collection:
              collectionContent = ContentType.mixed;
            case _:
              throw UnimplementedError();
          }
          if (searchListener.value!.id == widget.initialState.itemId) {
            collectionSortController.updateConfiguration(widget.initialState.sortAndFilterConfiguration);
          } else {
            collectionSortController.updateConfiguration(
              collectionContent == ContentType.inPlaylist
                  ? SortAndFilterConfiguration.defaultInAlbumSort
                  : SortAndFilterConfiguration.defaultSort,
            );
          }
        } else {
          collectionContent = null;
        }
        collectionSortController.updateContentType(collectionContent ?? ContentType.tracks);
      });
    });
  }

  @override
  void dispose() {
    searchListener.dispose();
    super.dispose();
  }

  SortAndFilterController? get activeSortController => switch (selectedSectionType) {
    HomeScreenSectionType.tabView => tabSortController,
    HomeScreenSectionType.collection => collectionSortController,
    HomeScreenSectionType.queues => null,
  };

  String get activeTitle => switch (selectedSectionType) {
    HomeScreenSectionType.tabView => tabTitle,
    HomeScreenSectionType.collection => collectionTitle,
    HomeScreenSectionType.queues => context.l10n.queues,
  };

  HomeScreenSectionConfiguration? get currentSectionInfo {
    final id = selectedSectionType == HomeScreenSectionType.collection ? selectedCollection?.id : selectedLibrary;
    final type = switch (selectedSectionType) {
      HomeScreenSectionType.tabView => tabContent,
      HomeScreenSectionType.collection => collectionContent,
      HomeScreenSectionType.queues => ContentType.home,
    };
    if (id == null || type == null) return null;

    SortAndFilterConfiguration currentConfig;
    if (activeSortController == null) {
      // TODO allow sort config on queues section
      currentConfig = SortAndFilterConfiguration.defaultSort;
    } else {
      currentConfig = ref.watch(resolveSortProvider(activeSortController!));
    }

    return HomeScreenSectionConfiguration(
      type: selectedSectionType,
      customSectionTitle: activeTitle == "" ? null : activeTitle,
      itemId: id,
      contentType: type,
      sortAndFilterConfiguration: currentConfig,
    );
  }

  bool get savingEnabled {
    final section = currentSectionInfo;
    if (section == null) return false;
    switch (section.type) {
      case HomeScreenSectionType.tabView:
        return section.customSectionTitle != null;
      case HomeScreenSectionType.collection:
        return section.customSectionTitle != null;
      case HomeScreenSectionType.queues:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Normal track menu entries, excluding headers
    final menuEntries = [
      SectionPreview(sectionInfo: currentSectionInfo),
      SizedBox(height: 16.0),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        spacing: 4.0,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4.0),
            child: Text(context.l10n.sectionType, style: Theme.of(context).textTheme.bodyMedium),
          ),
          FinampSettingsDropdown<HomeScreenSectionType>(
            dropdownItems: HomeScreenSectionType.values
                .map((e) => DropdownMenuEntry<HomeScreenSectionType>(value: e, label: e.toLocalisedString(context)))
                .toList(),
            selectedValue: selectedSectionType,
            onSelected: (selectedActionType) {
              if (selectedActionType != null) {
                setState(() {
                  selectedSectionType = selectedActionType;
                });
              }
            },
          ),
        ],
      ),
      if (selectedSectionType == HomeScreenSectionType.collection) ...[
        SizedBox(height: 20.0),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          spacing: 4.0,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4.0),
              child: Text(context.l10n.featuredCollection, style: Theme.of(context).textTheme.bodyMedium),
            ),
            GlobalSearchBox(
              searchListener,
              height:
                  MediaQuery.sizeOf(context).height *
                  (widget.dragController.isAttached
                      ? widget.dragController.size
                      : HomeScreenSectionConfigurationMenu.initialSheetExtent) *
                  0.25,
              initialItem: widget.initialState.type == HomeScreenSectionType.collection
                  ? widget.initialState.itemId as BaseItemId
                  : null,
              showTracks: false,
            ),
          ],
        ),
      ],
      if (selectedSectionType == HomeScreenSectionType.tabView) ...[
        SizedBox(height: 20.0),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          spacing: 4.0,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4.0),
              child: Text(context.l10n.tabType, style: Theme.of(context).textTheme.bodyMedium),
            ),
            FinampSettingsDropdown<ContentType>(
              dropdownItems: ContentType.values
                  .whereNot(
                    (contentType) => contentType == ContentType.home || contentType == ContentType.genericArtists,
                  )
                  .map((e) => DropdownMenuEntry<ContentType>(value: e, label: e.toLocalisedString(context)))
                  .toList(),
              selectedValue: tabContent,
              onSelected: (selectedTabType) {
                if (selectedTabType != null) {
                  setState(() {
                    tabContent = selectedTabType;
                    tabSortController.updateContentType(selectedTabType);
                  });
                }
              },
            ),
          ],
        ),
        SizedBox(height: 20.0),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          spacing: 4.0,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4.0),
              child: Text(context.l10n.library, style: Theme.of(context).textTheme.bodyMedium),
            ),
            Consumer(
              builder: (_, ref, _) {
                final views = ref.watch(JellyfinApiHelper.viewsProvider).value;
                return FinampSettingsDropdown<LibraryOrItemId?>(
                  dropdownItems: [
                    DropdownMenuEntry<LibraryOrItemId?>(
                      value: currentLibraryPlaceholder,
                      label: context.l10n.currentLibrary,
                      leadingIcon: const Icon(TablerIcons.bolt),
                    ),
                    if (views != null) ...views.map((e) => DropdownMenuEntry<BaseItemId?>(value: e.id, label: e.name!)),
                    if (views == null) DropdownMenuEntry<BaseItemId?>(value: null, label: context.l10n.loading),
                  ],
                  selectedValue: selectedLibrary,
                  onSelected: (selectedLibraryId) {
                    if (selectedLibraryId != null) {
                      setState(() {
                        selectedLibrary = selectedLibraryId;
                      });
                    }
                  },
                );
              },
            ),
            SizedBox(height: 20.0),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              spacing: 4.0,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 4.0),
                  child: Text(context.l10n.sectionTitle, style: Theme.of(context).textTheme.bodyMedium),
                ),
                TextField(
                  controller: TextEditingController(text: tabTitle)
                    ..selection = TextSelection.fromPosition(TextPosition(offset: tabTitle.length)),
                  decoration: InputDecoration(
                    hintText: context.l10n.egFavoriteTracks,
                    filled: true,
                    fillColor: Color.alphaBlend(
                      ColorScheme.of(context).onSurface.withOpacity(0.1),
                      ColorScheme.of(context).surface,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                    floatingLabelBehavior: FloatingLabelBehavior.never,
                    border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.circular(8)),
                  ),
                  onChanged: (newValue) {
                    setState(() {
                      tabTitle = newValue;
                    });
                  },
                ),
              ],
            ),
          ],
        ),
      ],
      SizedBox(height: 20.0),
      // sort and filter configuration
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        spacing: 4.0,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4.0),
            child: Text(context.l10n.sortBy, style: Theme.of(context).textTheme.bodyMedium),
          ),
          if (selectedSectionType != HomeScreenSectionType.queues)
            SortAndFilterRow(
              tabType: selectedSectionType == HomeScreenSectionType.collection
                  ? collectionContent ?? ContentType.tracks
                  : tabContent,
              controller: activeSortController!,
            ),
        ],
      ),
      SizedBox(height: 24.0),
      if (tabTitle == "" && selectedSectionType == HomeScreenSectionType.tabView)
        Text(
          context.l10n.customSectionTitleRequired,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.error),
        ),
      SizedBox(height: 8.0),
      CTAMedium(
        text: context.l10n.save,
        icon: TablerIcons.device_floppy,
        disabled: !savingEnabled,
        onPressed: () {
          Navigator.of(context).pop(currentSectionInfo);
        },
      ),
      SizedBox(height: 20.0),
    ];
    // TODO calculate real size or otherwise fix.
    final stackHeight = 200.0;

    return widget.childBuilder(stackHeight, [
      SliverStickyHeader(
        header: Padding(
          padding: const EdgeInsets.only(top: 10.0, bottom: 8.0, left: 16.0, right: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 2.0,
            children: [Text(context.l10n.editHomeScreenSection, style: Theme.of(context).textTheme.titleMedium)],
          ),
        ),
        sliver: MenuMask(
          height: MenuMaskHeight(32.0),
          child: SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            sliver: SliverList.list(children: menuEntries),
          ),
        ),
      ),
    ]);
  }
}

const sectionPresetPickerMenuRouteName = "/section-preset-picker-menu";

Future<HomeScreenSectionPresetType?> showSectionPresetPickerMenu(
  BuildContext context, {
  int? editingSectionIndex,
}) async {
  final List<Widget> menuItems = HomeScreenSectionPresetType.values
      .map<Widget>((presetType) {
        return Consumer(
          builder: (context, ref, child) {
            final currentSections = ref.watch(finampSettingsProvider.homeScreenConfiguration).sections;
            return ChoiceMenuOption(
              title: HomeScreenSectionConfiguration.getTitleForPreset(context: context, presetType: presetType),
              description: HomeScreenSectionConfiguration.getDescriptionForPreset(
                context: context,
                presetType: presetType,
              ),
              badges: [
                // // similar mode is recommended
                // if (preset == RadioMode.similar && radioModeOptionAvailabilityStatus.isAvailable)
                //   Icon(TablerIcons.star, size: 14.0),
              ],
              enabled: true,
              icon: TablerIcons.settings_star,
              isInactive: false,
              isSelected: editingSectionIndex != null && currentSections[editingSectionIndex].presetType == presetType,
              onSelect: () async {
                //TODO ideally rebuild with check and then pop after delay
                // FeedbackHelper.feedback(FeedbackType.selection);
                // await Future<void>.delayed(const Duration(milliseconds: 400));
                // Navigator.of(context).pop(preset);
                if (context.mounted) {
                  FeedbackHelper.feedback(FeedbackType.selection);
                  Navigator.of(context).pop(presetType);
                }
              },
            );
          },
        );
      })
      .followedBy(<Widget>[
        Divider(height: 8.0, thickness: 1.5, indent: 20.0, endIndent: 20.0, radius: BorderRadius.circular(2.0)),
        Consumer(
          builder: (context, ref, child) {
            final currentSections = ref.watch(finampSettingsProvider.homeScreenConfiguration).sections;
            return ChoiceMenuOption(
              title: AppLocalizations.of(context)!.homeScreenSectionCustomSectionTitle,
              description: AppLocalizations.of(context)!.homeScreenSectionCustomSectionDescription,
              icon: TablerIcons.adjustments,
              isSelected: editingSectionIndex != null && currentSections[editingSectionIndex].presetType == null,
              enabled: true,
              onSelect: () async {
                //TODO ideally rebuild with check and then pop after delay
                // FeedbackHelper.feedback(FeedbackType.selection);
                // await Future<void>.delayed(const Duration(milliseconds: 400));
                // if (context.mounted) {
                //   Navigator.of(context).pop();
                // }
                if (context.mounted) {
                  FeedbackHelper.feedback(FeedbackType.selection);
                  Navigator.of(context).pop(null);
                }
              },
            );
          },
        ),
      ])
      .toList();

  return await showThemedBottomSheet<HomeScreenSectionPresetType?>(
    context: context,
    routeName: sectionPresetPickerMenuRouteName,
    minDraggableHeight: 0.25,
    buildSlivers: (context) {
      var menu = [
        SliverStickyHeader(
          header: Padding(
            padding: const EdgeInsets.only(top: 10.0, bottom: 8.0, left: 16.0, right: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2.0,
              children: [
                Text(
                  AppLocalizations.of(context)!.homeScreenSectionPresetPickerMenuTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
          sliver: MenuMask(
            height: MenuMaskHeight(36.0),
            child: SliverList.list(children: menuItems),
          ),
        ),
      ];
      // header + menu entries
      var stackHeight = 42.0 + menuItems.length * ((Platform.isAndroid || Platform.isIOS) ? 72.0 : 64.0);
      return (stackHeight, menu);
    },
  );
}

class SectionPreview extends ConsumerWidget {
  const SectionPreview({super.key, required this.sectionInfo});

  final HomeScreenSectionConfiguration? sectionInfo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasTitle = (sectionInfo?.customSectionTitle ?? "") != "" || sectionInfo?.presetType != null;

    final sectionTitle = hasTitle ? sectionInfo!.getTitle(context) : context.l10n.preview;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.max,
      spacing: 4.0,
      children: [
        Text(
          sectionTitle,
          style: hasTitle
              ? TextTheme.of(context).titleSmall?.copyWith(
                  fontWeight: FontWeight.w500,
                  fontSize: 18,
                  color: Theme.brightnessOf(context) == Brightness.light ? Colors.black : Colors.white,
                )
              : Theme.of(context).textTheme.bodyMedium,
        ),
        sectionInfo != null
            ? HomeScreenSectionContent(sectionInfo: sectionInfo!)
            : SizedBox(height: 120, child: Center(child: Text(context.l10n.sectionConfigInvalid))),
      ],
    );
  }
}

class GlobalSearchBox extends ConsumerStatefulWidget {
  const GlobalSearchBox(this.notifier, {super.key, required this.height, this.initialItem, required this.showTracks});

  final ValueNotifier<BaseItemDto?> notifier;
  final BaseItemId? initialItem;
  final double height;
  final bool showTracks;

  @override
  ConsumerState<GlobalSearchBox> createState() => _GlobalSearchBoxState();
}

class _GlobalSearchBoxState extends ConsumerState<GlobalSearchBox> {
  final TextEditingController controller = TextEditingController();

  String searchTerm = "";

  @override
  void initState() {
    if (widget.initialItem != null) {
      ref.read(itemByIdProvider(widget.initialItem!).future).then((value) {
        if (widget.notifier.value == null) {
          widget.notifier.value = value;
        }
      });
    }
    super.initState();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(finampSettingsProvider.isOffline)) {
      return Text(context.l10n.searchNotAvailibleWhileOffline);
    }

    return Column(
      children: [
        TextField(
          controller: controller,
          autocorrect: false, // avoid autocorrect
          enableSuggestions: true, // keep suggestions which can be manually selected
          autofocus: true,
          keyboardType: TextInputType.text,
          textInputAction: TextInputAction.search,
          /*onChanged: (value) {
        if (debounce?.isActive ?? false) debounce!.cancel();
        debounce = Timer(const Duration(milliseconds: 400), () {
          onUpdateSearchQuery?.call(value);
        });
      },*/
          onSubmitted: (value) => setState(() {
            searchTerm = value;
            widget.notifier.value = null;
          }),
          decoration: InputDecoration(
            border: InputBorder.none,
            hintText: MaterialLocalizations.of(context).searchFieldLabel,
            contentPadding: EdgeInsets.only(left: 4.0, top: 8.0, bottom: 8.0),
            isDense: true,
          ),
        ),
        _getDropdown(),
        ValueListenableBuilder(
          valueListenable: widget.notifier,
          builder: (_, value, _) {
            if (value == null) return SizedBox.shrink();
            return ItemWrapper(item: value);
          },
        ),
      ],
    );
  }

  Widget _getDropdown() {
    if (searchTerm == "") {
      return SizedBox.shrink();
    }

    final items = ref.watch(globalSearchProvider(searchTerm, includeTracks: widget.showTracks));

    if (items.isLoading) {
      return Text(context.l10n.loading);
    }

    if (items.value == null || items.value!.isEmpty) {
      return Text(context.l10n.noSearchResults);
    }

    final dropdownEntries = items.value!.map((collection) {
      final label = collection.name ?? context.l10n.unnamedCollection;
      return DropdownMenuEntry<BaseItemDto>(
        value: collection,
        label: label,
        // TODO localizable item type name
        labelWidget: Row(
          spacing: 10.0,
          children: [
            Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis)),
            Text("(${BaseItemDtoType.fromItem(collection).name})"),
          ],
        ),
        enabled: true,
        style: ButtonStyle(
          padding: WidgetStateProperty.all<EdgeInsets>(const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0)),
        ),
      );
    }).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        return DropdownMenu<BaseItemDto>(
          width: constraints.maxWidth,
          menuHeight: widget.height,
          dropdownMenuEntries: dropdownEntries,
          hintText: context.l10n.collectionDropdownHint,
          //errorText: collections.isEmpty ? "You don't have any Jellyfin collections yet*" : null,
          //initialSelection: selectedCollectionId,
          enableFilter: true,
          enableSearch: true,
          requestFocusOnTap: true,
          onSelected: (selectedCollection) {
            widget.notifier.value = selectedCollection;
          },
          textStyle: Theme.of(context).textTheme.bodyMedium,
          trailingIcon: const Icon(TablerIcons.chevron_down),
          selectedTrailingIcon: const Icon(TablerIcons.chevron_up),
          menuStyle: MenuStyle(
            shape: WidgetStateProperty.all<RoundedRectangleBorder>(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
            ),
            backgroundColor: WidgetStateProperty.all<Color>(
              Color.alphaBlend(ColorScheme.of(context).onSurface.withOpacity(0.2), ColorScheme.of(context).surface),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0), borderSide: BorderSide.none),
            filled: true,
            fillColor: Color.alphaBlend(
              ColorScheme.of(context).primary.withOpacity(0.075),
              ColorScheme.of(context).onSurface.withOpacity(0.1),
            ),
            visualDensity: VisualDensity(horizontal: -4.0, vertical: -4.0),
            errorBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
            isDense: true,
            contentPadding: EdgeInsets.only(left: 8.0),
          ),
        );
      },
    );
  }
}
