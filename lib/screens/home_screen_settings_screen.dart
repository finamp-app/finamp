import 'package:finamp/components/Buttons/cta_medium.dart';
import 'package:finamp/components/Buttons/simple_button.dart';
import 'package:finamp/components/HomeScreen/home_screen_content.dart';
import 'package:finamp/components/MusicScreen/item_card.dart';
import 'package:finamp/components/MusicScreen/item_wrapper.dart';
import 'package:finamp/components/finamp_app_bar_back_button.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/services/feedback_helper.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:finamp/services/item_by_id_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../components/HomeScreen/home_section_editor.dart';
import '../components/HomeScreen/quick_action_editor.dart';
import '../extensions/localizations.dart';
import '../services/music_providers.dart';

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
                  title: Padding(padding: const EdgeInsets.only(left: 4.0), child: Text(action.getTitle(context.l10n))),
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
                      SimpleButton.small(
                        text: action.action.editable ? context.l10n.editAction : context.l10n.swapAction,
                        icon: action.action.editable ? TablerIcons.edit : TablerIcons.selector,
                        onPressed: () => editQuickAction(context, index),
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
                  title: Padding(
                    padding: const EdgeInsets.only(left: 4.0),
                    child: Text(section.getTitle(context.l10n)),
                  ),
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
                    base: TabsHomeSection(libraryId: currentLibraryPlaceholder, contentType: ContentType.tracks),
                    sortConfig: SortAndFilterConfiguration(
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

class SectionPreview extends ConsumerWidget {
  const SectionPreview({super.key, required this.sectionInfo});

  final HomeScreenSectionConfiguration? sectionInfo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasTitle = (sectionInfo?.customSectionTitle ?? "") != "" || sectionInfo?.presetType != null;

    final sectionTitle = hasTitle ? sectionInfo!.getTitle(context.l10n) : context.l10n.preview;

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
        SizedBox(
          height: calculateItemCollectionCardHeight(
            ref: ref,
            sectionInfo: sectionInfo,
            itemType: sectionInfo == null ? BaseItemDtoType.track : null,
            forHomeScreen: true,
          ),
          child: sectionInfo != null
              ? HomeScreenSectionContent(sectionInfo: sectionInfo!)
              : Center(child: Text(context.l10n.sectionConfigInvalid)),
        ),
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

    final dropdown = _getDropdown();

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
          decoration: InputDecoration(
            hintText: MaterialLocalizations.of(context).searchFieldLabel,
            filled: true,
            fillColor: Color.alphaBlend(
              ColorScheme.of(context).onSurface.withOpacity(0.1),
              ColorScheme.of(context).surface,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            floatingLabelBehavior: FloatingLabelBehavior.never,
            border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.circular(8)),
          ),
          onSubmitted: (value) => setState(() {
            searchTerm = value;
            widget.notifier.value = null;
          }),
        ),
        if (dropdown != null) Padding(padding: EdgeInsets.only(top: 12), child: dropdown),
        ValueListenableBuilder(
          valueListenable: widget.notifier,
          builder: (_, value, _) {
            if (value == null) return SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: 10.0),
              child: ItemWrapper(
                item: value,
                // override default on-tap since we don't want to allow navigating away
                onTap: () => openItemMenu(context: context, item: value),
                isGrid: false,
              ),
            );
          },
        ),
      ],
    );
  }

  Widget? _getDropdown() {
    if (searchTerm == "") {
      return null;
    }

    final items = ref.watch(globalSearchProvider(searchTerm, includeTracks: widget.showTracks));

    if (items.isLoading) {
      return _placeholderText(
        context,
        Row(
          spacing: 15.0,
          children: [
            SizedBox(
              width: kMinInteractiveDimension * 0.65,
              height: kMinInteractiveDimension * 0.65,
              child: CircularProgressIndicator(strokeWidth: 1, color: DefaultTextStyle.of(context).style.color),
            ),
            Text(context.l10n.loading),
          ],
        ),
      );
    }

    if (items.value == null || items.value!.isEmpty) {
      return _placeholderText(context, Text(context.l10n.noSearchResults));
    }

    final dropdownEntries = items.value!.map((collection) {
      final label = collection.name ?? context.l10n.unnamedCollection;
      return DropdownMenuEntry<BaseItemDto>(
        value: collection,
        label: label,
        labelWidget: Row(
          spacing: 10.0,
          children: [
            Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis)),
            Text("(${BaseItemDtoType.fromItem(collection).localized(context.l10n)})"),
          ],
        ),
        enabled: true,
        style: ButtonStyle(
          padding: WidgetStateProperty.all<EdgeInsets>(const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0)),
        ),
      );
    }).toList();

    return DropdownMenu<BaseItemDto>(
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
      expandedInsets: const EdgeInsets.all(0.0),
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
  }

  Widget _placeholderText(BuildContext context, Widget child) {
    return Container(
      width: double.infinity,
      alignment: AlignmentDirectional.centerStart,
      height: kMinInteractiveDimension,
      padding: EdgeInsets.only(left: 8.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8.0),
        color: Color.alphaBlend(
          ColorScheme.of(context).primary.withOpacity(0.075),
          ColorScheme.of(context).onSurface.withOpacity(0.1),
        ),
      ),
      child: child,
    );
  }
}
