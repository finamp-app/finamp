import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_sticky_header/flutter_sticky_header.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../../extensions/localizations.dart';
import '../../l10n/app_localizations.dart';
import '../../menus/choice_menu.dart';
import '../../models/finamp_models.dart';
import '../../models/jellyfin_models.dart';
import '../../screens/home_screen_settings_screen.dart';
import '../../services/feedback_helper.dart';
import '../../services/finamp_settings_helper.dart';
import '../../services/finamp_user_helper.dart';
import '../Buttons/cta_medium.dart';
import '../MusicScreen/sort_and_filter_row.dart';
import '../SettingsScreen/finamp_settings_dropdown.dart';
import '../global_snackbar.dart';
import '../themed_bottom_sheet.dart';

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

enum _SectionType {
  tab,
  collection,
  queue;

  String toLocalisedString(AppLocalizations l10n) {
    switch (this) {
      case queue:
        return l10n.queues;
      case tab:
        return l10n.tabView;
      case collection:
        return l10n.collection;
    }
  }
}

// TODO we should probably build separate sub-widgets for tabview/collections?
class _HomeScreenSectionConfigurationMenuState extends ConsumerState<HomeScreenSectionConfigurationMenu> {
  late _SectionType selectedSectionType;

  // TODO the tab types should probably just be separate widgets.

  String tabTitle = "";
  LibraryId tabLibrary = currentLibraryPlaceholder;
  ContentType tabContent = ContentType.tracks;
  StaticSortAndFilterController tabSortController = StaticSortAndFilterController(
    startingConfig: SortAndFilterConfiguration.defaultSort,
    contentType: ContentType.tracks,
    skipResolving: true,
  );

  String collectionTitle = "";
  BaseItemDto? selectedCollection;
  ContentType? collectionContent;
  LibraryId collectionLibrary = currentLibraryPlaceholder;
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
            ? widget.initialState.getTitle(GlobalSnackbar.requireL10n)
            : "");

    switch (widget.initialState.base) {
      case QueuesHomeSection section:
        selectedSectionType = _SectionType.queue;
      case TabsHomeSection section:
        selectedSectionType = _SectionType.tab;
        tabLibrary = section.libraryId;
        tabContent = section.contentType;
        tabSortController.updateConfiguration(widget.initialState.sortConfig);
        tabTitle = initialTitle;
      case CollectionHomeSection section:
        selectedSectionType = _SectionType.collection;
        collectionSortController.updateConfiguration(widget.initialState.sortConfig);
        collectionTitle = initialTitle;
        collectionLibrary = section.libraryId;
    }
    ;

    searchListener.addListener(() {
      setState(() {
        selectedCollection = searchListener.value;
        collectionTitle = searchListener.value?.name ?? "";
        if (searchListener.value != null) {
          switch (BaseItemDtoType.fromItem(searchListener.value!)) {
            case BaseItemDtoType.playlist:
            case BaseItemDtoType.album:
              collectionContent = ContentType.inPlaylist;
              // This shouldn't be used, but just in case there's no reason to filter
              collectionLibrary = allLibraryPlaceholder;
            case BaseItemDtoType.artist:
            case BaseItemDtoType.genre:
              collectionContent = ContentType.tracks;
              collectionLibrary = currentLibraryPlaceholder;
            case BaseItemDtoType.collection:
              collectionContent = ContentType.mixed;
              // This shouldn't be used, but just in case there's no reason to filter
              collectionLibrary = allLibraryPlaceholder;
            case _:
              throw UnsupportedError("Global search should not have returned an item of this type");
          }
          if (widget.initialState.base case CollectionHomeSection section
              when section.itemId == searchListener.value!.id) {
            collectionSortController.updateConfiguration(widget.initialState.sortConfig);
            collectionContent = section.contentType;
            collectionLibrary = section.libraryId;
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
    _SectionType.tab => tabSortController,
    _SectionType.collection => collectionSortController,
    _SectionType.queue => null,
  };

  String get activeTitle => switch (selectedSectionType) {
    _SectionType.tab => tabTitle,
    _SectionType.collection => collectionTitle,
    _SectionType.queue => context.l10n.queues,
  };

  HomeScreenSectionConfiguration? get currentSectionInfo {
    if (selectedSectionType == _SectionType.collection && (collectionContent == null || selectedCollection == null)) {
      return null;
    }

    SortAndFilterConfiguration currentConfig;
    if (activeSortController == null) {
      // TODO allow sort config on queues section
      currentConfig = const SortAndFilterConfiguration(
        sortBy: SortBy.datePlayed,
        sortOrder: SortOrder.descending,
        filters: {},
      );
    } else {
      currentConfig = ref.watch(resolveSortProvider(activeSortController!));
    }

    return HomeScreenSectionConfiguration(
      base: switch (selectedSectionType) {
        _SectionType.tab => TabsHomeSection(libraryId: tabLibrary, contentType: tabContent),
        _SectionType.collection => CollectionHomeSection(
          itemId: selectedCollection!.id,
          libraryId: collectionLibrary,
          contentType: collectionContent!,
        ),
        _SectionType.queue => QueuesHomeSection(),
      },
      customSectionTitle: activeTitle == "" ? null : activeTitle,
      sortConfig: currentConfig,
    );
  }

  bool get savingEnabled {
    final section = currentSectionInfo;
    if (section == null) return false;
    switch (section.base) {
      case QueuesHomeSection():
        return true;
      case TabsHomeSection():
        return section.customSectionTitle != null;
      case CollectionHomeSection():
        return section.customSectionTitle != null;
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
          FinampSettingsDropdown<_SectionType>(
            dropdownItems: _SectionType.values
                .map((e) => DropdownMenuEntry<_SectionType>(value: e, label: e.toLocalisedString(context.l10n)))
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
      if (selectedSectionType == _SectionType.collection) ...[
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
              initialItem: switch (widget.initialState.base) {
                CollectionHomeSection section => section.itemId,
                _ => null,
              },
              showTracks: false,
            ),
          ],
        ),
        if (selectedCollection != null &&
            [
              BaseItemDtoType.artist,
              BaseItemDtoType.genre,
              BaseItemDtoType.collection,
            ].contains(BaseItemDtoType.fromItem(selectedCollection!))) ...[
          SizedBox(height: 20.0),
          Padding(
            padding: const EdgeInsets.only(left: 4.0, bottom: 4.0),
            child: Text(context.l10n.itemTypeFilterHeader, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Builder(
            builder: (context) {
              final type = BaseItemDtoType.fromItem(selectedCollection!);
              final allowedSelections = switch (type) {
                BaseItemDtoType.artist => [
                  ContentType.tracks,
                  ContentType.inPerformingArtistAlbums,
                  ContentType.inAlbumArtistAlbums,
                ],
                BaseItemDtoType.genre => [
                  ContentType.tracks,
                  ContentType.genericArtists,
                  ContentType.playlists,
                  ContentType.albums,
                ],
                BaseItemDtoType.collection => [
                  ContentType.tracks,
                  ContentType.genericArtists,
                  ContentType.playlists,
                  ContentType.albums,
                  ContentType.genres,
                  ContentType.mixed,
                ],
                _ => throw "???",
              };
              return FinampSettingsDropdown<ContentType?>(
                dropdownItems: allowedSelections
                    .map(
                      (e) => DropdownMenuEntry<ContentType?>(
                        value: e,
                        label: switch (e) {
                          ContentType.mixed => context.l10n.allTypes,
                          _ => e.toLocalisedString(context.l10n),
                        },
                      ),
                    )
                    .toList(),
                selectedValue: collectionContent,
                onSelected: (selectedContentType) {
                  if (selectedContentType != null) {
                    setState(() {
                      collectionContent = selectedContentType;
                    });
                  }
                },
              );
            },
          ),
        ],
        if (selectedCollection != null &&
            [
              BaseItemDtoType.artist,
              BaseItemDtoType.genre,
            ].contains(BaseItemDtoType.fromItem(selectedCollection!))) ...[
          SizedBox(height: 20.0),
          Padding(
            padding: const EdgeInsets.only(left: 4.0),
            child: Text(context.l10n.library, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Consumer(
            builder: (_, ref, _) {
              final views = ref.watch(FinampUserHelper.finampCurrentUserProvider)?.views.values;
              return FinampSettingsDropdown<LibraryId?>(
                dropdownItems: [
                  DropdownMenuEntry<LibraryId?>(
                    value: currentLibraryPlaceholder,
                    label: context.l10n.currentLibrary,
                    leadingIcon: const Icon(TablerIcons.bolt),
                  ),
                  if (BaseItemDtoType.fromItem(selectedCollection!) != BaseItemDtoType.genre)
                    DropdownMenuEntry<LibraryId?>(
                      value: allLibraryPlaceholder,
                      label: context.l10n.allLibraries,
                      leadingIcon: const Icon(TablerIcons.bolt),
                    ),
                  if (views != null)
                    ...views.map((e) => DropdownMenuEntry<LibraryId?>(value: e.id as LibraryId, label: e.name!)),
                  if (views == null) DropdownMenuEntry<LibraryId?>(value: null, label: context.l10n.loading),
                ],
                selectedValue: collectionLibrary,
                onSelected: (selectedLibraryId) {
                  if (selectedLibraryId != null) {
                    setState(() {
                      collectionLibrary = selectedLibraryId;
                    });
                  }
                },
              );
            },
          ),
        ],
      ],
      if (selectedSectionType == _SectionType.tab) ...[
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
                  .where((contentType) => contentType.directlyDisplayable)
                  .map((e) => DropdownMenuEntry<ContentType>(value: e, label: e.toLocalisedString(context.l10n)))
                  .toList(),
              selectedValue: tabContent,
              onSelected: (selectedTabType) {
                if (selectedTabType != null) {
                  setState(() {
                    tabContent = selectedTabType;
                    tabSortController.updateContentType(selectedTabType);
                    if (selectedTabType == ContentType.playlists) {
                      tabLibrary = allLibraryPlaceholder;
                    }
                    if (selectedTabType == ContentType.genres && tabLibrary == allLibraryPlaceholder) {
                      tabLibrary = currentLibraryPlaceholder;
                    }
                  });
                }
              },
            ),
          ],
        ),
        SizedBox(height: 20.0),
        if (tabContent != ContentType.playlists)
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
                  final views = ref.watch(FinampUserHelper.finampCurrentUserProvider)?.views.values;
                  return FinampSettingsDropdown<LibraryId?>(
                    dropdownItems: [
                      DropdownMenuEntry<LibraryId?>(
                        value: currentLibraryPlaceholder,
                        label: context.l10n.currentLibrary,
                        leadingIcon: const Icon(TablerIcons.bolt),
                      ),
                      if (tabContent != ContentType.genres)
                        DropdownMenuEntry<LibraryId?>(
                          value: allLibraryPlaceholder,
                          label: context.l10n.allLibraries,
                          leadingIcon: const Icon(TablerIcons.bolt),
                        ),
                      if (views != null)
                        ...views.map((e) => DropdownMenuEntry<LibraryId?>(value: e.id as LibraryId, label: e.name!)),
                      if (views == null) DropdownMenuEntry<LibraryId?>(value: null, label: context.l10n.loading),
                    ],
                    selectedValue: tabLibrary,
                    onSelected: (selectedLibraryId) {
                      if (selectedLibraryId != null) {
                        setState(() {
                          tabLibrary = selectedLibraryId;
                        });
                      }
                    },
                  );
                },
              ),
            ],
          ),
      ],
      if (selectedSectionType == _SectionType.tab ||
          (selectedSectionType == _SectionType.collection &&
              selectedCollection != null &&
              BaseItemDtoType.fromItem(selectedCollection!) != BaseItemDtoType.album)) ...[
        SizedBox(height: 20.0),
        // sort and filter configuration
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          spacing: 4.0,
          children: [
            SortAndFilterEmbeddedMenu(
              tabType: selectedSectionType == _SectionType.collection
                  ? collectionContent ?? ContentType.tracks
                  : tabContent,
              controller: activeSortController!,
              removeOnly: false,
            ),
          ],
        ),
      ],
      if (selectedSectionType == _SectionType.tab) ...[
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
                tabTitle = newValue;
              },
            ),
          ],
        ),
      ],
      SizedBox(height: 24.0),
      if (tabTitle == "" && selectedSectionType == _SectionType.tab)
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
      SizedBox(height: 350.0),
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
              title: HomeScreenSectionConfiguration.getTitleForPreset(l10n: context.l10n, presetType: presetType),
              description: HomeScreenSectionConfiguration.getDescriptionForPreset(
                l10n: context.l10n,
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
