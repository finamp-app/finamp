import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:finamp/components/AlbumScreen/track_list_tile.dart';
import 'package:finamp/components/MusicScreen/music_screen_tab_view.dart';
import 'package:finamp/components/album_image.dart';
import 'package:finamp/components/finamp_app_bar_back_button.dart';
import 'package:finamp/components/global_snackbar.dart';
import 'package:finamp/components/padded_custom_scrollview.dart';
import 'package:finamp/components/print_duration.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/menus/components/icon_button_with_semantics.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/services/album_screen_provider.dart';
import 'package:finamp/services/downloads_service.dart';
import 'package:finamp/services/feedback_helper.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:finamp/services/finamp_user_helper.dart';
import 'package:finamp/services/jellyfin_api_helper.dart';
import 'package:finamp/services/permission_providers.dart';
import 'package:finamp/services/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_sticky_header/flutter_sticky_header.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:get_it/get_it.dart';

class PlaylistEditScreen extends ConsumerStatefulWidget {
  const PlaylistEditScreen({super.key, required this.playlist});

  static const routeName = "/music/playlist/edit";
  final BaseItemDto playlist;

  @override
  ConsumerState<PlaylistEditScreen> createState() => _PlaylistEditScreenState();
}

class _PlaylistEditScreenState extends ConsumerState<PlaylistEditScreen> {
  // UI constants
  static const double _coverSize = 130.0; // kept for reuse
  static const double _wrapSpacing = 12.0; // kept for reuse

  late BaseItemDto playlist;
  bool _isLoading = true;

  String? _name;
  bool? _publicVisibility;
  bool _isUpdating = false;
  List<BaseItemDto> playlistTracks = [];
  List<BaseItemDto> removedTracks = [];

  File? newAlbumImage;

  // Dirty tracking baselines
  late String _initialName;
  late bool _initialVisibility;
  late List<String> _initialTrackIdsOrder;

  bool get _haveTracksChanged {
    final currentOrder = playlistTracks.map((t) => t.id.raw).toList();
    if (currentOrder.length != _initialTrackIdsOrder.length) return true;
    for (var i = 0; i < currentOrder.length; i++) {
      if (currentOrder[i] != _initialTrackIdsOrder[i]) return true;
    }
    if (removedTracks.isNotEmpty) return true;
    return false;
  }

  bool get _hasMetadataChanged => _name != _initialName || (_publicVisibility ?? false) != _initialVisibility;
  bool get _hasCoverChanged => newAlbumImage != null;
  bool get _isDirty => _haveTracksChanged || _hasMetadataChanged || _hasCoverChanged;

  Future<bool> _confirmDiscardChanges() async {
    if (!_isDirty) return true;
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: Text(AppLocalizations.of(context)!.discardChangesTitle),
            content: Text(AppLocalizations.of(context)!.discardChangesDescription),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(AppLocalizations.of(context)!.genericCancel),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(AppLocalizations.of(context)!.discardChangesConfirmButton),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _resetDirtyBaseline() {
    _initialName = _name ?? '';
    _initialVisibility = _publicVisibility ?? false;
    _initialTrackIdsOrder = playlistTracks.map((t) => t.id.raw).toList();
    newAlbumImage = null;
    removedTracks.clear();
  }

  final _jellyfinApiHelper = GetIt.instance<JellyfinApiHelper>();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    playlist = widget.playlist;
    _isLoading = true;
    _name = playlist.name;
    _fetchPublicVisibility();
    final tracksAsync = ref.read(getDefaultSortedPlaylistTracksProvider(playlist));
    final (allTracks, playableTracks) = tracksAsync.valueOrNull ?? (<BaseItemDto>[], <BaseItemDto>[]);
    playlistTracks = List.from(allTracks);
    if (tracksAsync.hasValue) {
      setState(() => _isLoading = false);
    } else {
      // wait for playlist tracks, then mark loading as false
      ref.listenManual<AsyncValue<(List<BaseItemDto>, List<BaseItemDto>)>>(
        getDefaultSortedPlaylistTracksProvider(playlist),
        (_, tracksAsyncLoaded) {
          if (mounted) {
            final (allTracksLoaded, playableTracksLoaded) =
                tracksAsyncLoaded.valueOrNull ?? (<BaseItemDto>[], <BaseItemDto>[]);
            setState(() {
              playlistTracks = List.from(allTracksLoaded);
              _initialTrackIdsOrder = playlistTracks.map((t) => t.id.raw).toList();
              _isLoading = false;
            });
          }
        },
      );
    }
    _initialName = _name ?? '';
    _initialVisibility = _publicVisibility ?? false;
    _initialTrackIdsOrder = playlistTracks.map((t) => t.id.raw).toList();
  }

  Future<File?> filePicker() async {
    final result = await FilePicker.pickFiles(type: FileType.image);
    if (result == null) return null;
    return File(result.files.single.path!);
  }

  Future<void> _fetchPublicVisibility() async {
    if (_publicVisibility != null) return;
    final resultPlaylist = await _jellyfinApiHelper.getPlaylist(playlist.id!);
    setState(() {
      _publicVisibility = resultPlaylist.openAccess;
      _initialVisibility = _publicVisibility ?? false;
    });
  }

  Future<void> _saveOrUpdatePlaylist() async {
    final formState = _formKey.currentState;
    if (formState != null && formState.validate()) {
      setState(() => _isUpdating = true);
      formState.save();
      try {
        if (_hasMetadataChanged) {
          // Jellyfin can't handle updating both the track list and name at the same time, so make two separate requests
          await _jellyfinApiHelper.updatePlaylist(
            newPlaylist: NewPlaylist(
              isPublic: _publicVisibility,
              name: _name,
              userId: GetIt.instance<FinampUserHelper>().currentUserId,
            ),
            itemId: playlist.id,
          );
          // update local BaseItemDto to reflect changes for already loaded playlist screen
          playlist.name = _name;
        }
        if (_haveTracksChanged) {
          await _jellyfinApiHelper.updatePlaylist(
            newPlaylist: NewPlaylist(
              ids: playlistTracks.map((track) => track.id).toList(),
              userId: GetIt.instance<FinampUserHelper>().currentUserId,
            ),
            itemId: playlist.id,
          );
        }
        if (_hasCoverChanged) {
          await _jellyfinApiHelper.setItemPrimaryImage(itemId: playlist.id!, imageFile: newAlbumImage!);
        }
        musicScreenRefreshStream.add(null); // refresh playlist content
        ref.invalidate(getAlbumOrPlaylistTracksProvider(playlist));
        final downloadsService = GetIt.instance<DownloadsService>();
        unawaited(
          downloadsService.resync(
            DownloadStub.fromItem(type: DownloadItemType.collection, item: playlist),
            null,
            keepSlow: true,
            forceSync: true,
          ),
        );
        if (!mounted) return;
        // GlobalSnackbar.message((context) => AppLocalizations.of(context)!.playlistUpdated, isConfirmation: true);
        // Trigger success flash before pop
        _playlistSaveFeedbackController.success();
        await Future<void>.delayed(const Duration(milliseconds: 750));
        setState(() {
          _isUpdating = false;
          _resetDirtyBaseline();
        });
        if (mounted) Navigator.of(context).pop();
      } catch (e) {
        GlobalSnackbar.error(e);
        if (mounted) setState(() => _isUpdating = false);
      }
    }
  }

  // Controller to communicate save state transitions to FAB
  final _playlistSaveFeedbackController = _PlaylistSaveFeedbackController();

  @override
  Widget build(BuildContext context) {
    final bool isOffline = ref.watch(finampSettingsProvider.isOffline);

    final playlistTracksCount = playlistTracks.length;
    final trackCountString = (playlistTracks.length == playlist.childCount || !isOffline)
        ? AppLocalizations.of(context)!.trackCount(playlistTracksCount)
        : AppLocalizations.of(context)!.offlineTrackCount(playlist.childCount!, playlistTracksCount);
    final trackDurationString = (playlistTracks.length == playlist.childCount)
        ? printDuration(playlist.runTimeTicksDuration(), leadingZeroes: false)
        : printDuration(
            playlistTracks
                .map((t) => t.runTimeTicksDuration())
                .whereType<Duration>()
                .fold<Duration>(Duration.zero, (sum, dur) => sum + dur),
            leadingZeroes: false,
          );

    return PopScope(
      canPop: !_isDirty,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldDiscard = await _confirmDiscardChanges();
        if (shouldDiscard && mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        body: PaddedCustomScrollview(
          bottomPadding: 120.0,
          slivers: [
            SliverAppBar(
              title: Text(AppLocalizations.of(context)!.editItemTitle(BaseItemDtoType.fromItem(playlist).name)),
              leading: FinampAppBarBackButton(),
              actions: [
                if (_isDirty)
                  IconButtonWithSemantics(
                    label: AppLocalizations.of(context)!.updatePlaylistButtonLabel,
                    icon: TablerIcons.device_floppy,
                    onPressed: _isUpdating ? null : () async => await _saveOrUpdatePlaylist(),
                  ),
              ],
              expandedHeight: kToolbarHeight + 125 + 48,
              pinned: true,
              centerTitle: false,
              titleSpacing: 0,
              flexibleSpace: ItemTheme(
                item: playlist,
                child: _HeaderSection(
                  formKey: _formKey,
                  coverSize: _coverSize,
                  name: _name,
                  albumImage: playlist,
                  canEdit: ref.watch(canEditMetadataProvider),
                  publicVisibility: _publicVisibility ?? false,
                  trackCountString: trackCountString,
                  trackDurationString: trackDurationString,
                  onPickImage: () async {
                    final file = await filePicker();
                    if (file == null) return;
                    setState(() => newAlbumImage = file);
                  },
                  newAlbumImage: newAlbumImage,
                  onNameChanged: (v) => setState(() => _name = v),
                  onVisibilityChanged: (v) => setState(() => _publicVisibility = v),
                  onSubmit: () async => await _saveOrUpdatePlaylist(),
                ),
              ),
            ),
            if (_isLoading)
              ItemTheme(
                item: playlist,
                child: Builder(
                  builder: (context) {
                    return SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(ColorScheme.of(context).primary),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              )
            else ...[
              SliverReorderableList(
                autoScrollerVelocityScalar: 20.0,
                onReorder: (oldIndex, newIndex) {
                  if (!mounted) return;
                  setState(() {
                    playlistTracks.insert(
                      newIndex < oldIndex ? newIndex : newIndex - 1,
                      playlistTracks.removeAt(oldIndex),
                    );
                  });
                },
                onReorderStart: (_) => FeedbackHelper.feedback(FeedbackType.selection),
                findChildIndexCallback: (Key key) {
                  key = key as GlobalObjectKey;
                  final valueKey = key.value as ValueKey<String>;
                  final index = playlistTracks.indexWhere((item) => item.id == valueKey.value);
                  if (index == -1) return null;
                  return index;
                },
                itemCount: playlistTracks.length,
                itemBuilder: (context, index) {
                  final item = playlistTracks[index];
                  return Material(
                    type: MaterialType.transparency,
                    key: ValueKey(item.id),
                    child: EditListTile(
                      item: item,
                      listIndex: index,
                      onRemoveOrRestore: () {
                        setState(() => removedTracks.add(playlistTracks.removeAt(index)));
                      },
                      onTap: (bool playable) {},
                    ),
                  );
                },
              ),
              _RemovedTracksSection(
                removedTracks: removedTracks,
                onRestore: (index) => setState(() => playlistTracks.add(removedTracks.removeAt(index))),
              ),
            ],
          ],
        ),
        floatingActionButton: _isDirty
            ? ItemTheme(
                item: playlist,
                child: _PlaylistSaveFAB(
                  isSaving: _isUpdating,
                  onPressed: _isUpdating ? null : () async => await _saveOrUpdatePlaylist(),
                  controller: _playlistSaveFeedbackController,
                ),
              )
            : null,
      ),
    );
  }
}

class _HeaderSection extends ConsumerWidget {
  const _HeaderSection({
    required this.formKey,
    required this.coverSize,
    required this.name,
    required this.albumImage,
    required this.canEdit,
    required this.publicVisibility,
    required this.trackCountString,
    required this.trackDurationString,
    required this.onPickImage,
    required this.newAlbumImage,
    required this.onNameChanged,
    required this.onVisibilityChanged,
    required this.onSubmit,
    Key? key,
  }) : super(key: key);

  final GlobalKey<FormState> formKey;
  final double coverSize;
  final String? name;
  final BaseItemDto? albumImage;
  final bool canEdit;
  final bool publicVisibility;
  final String trackCountString;
  final String trackDurationString;
  final VoidCallback onPickImage;
  final File? newAlbumImage;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<bool> onVisibilityChanged;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FlexibleSpaceBar(
      background: Align(
        alignment: AlignmentGeometry.bottomCenter,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0),
          decoration: BoxDecoration(
            color: ColorScheme.of(context).primary.withOpacity(0.25),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: canEdit
                        ? onPickImage
                        : () => GlobalSnackbar.message(
                            (context) => AppLocalizations.of(context)!.noPermissionToEditMetadata,
                          ),
                    child: SizedBox(
                      height: coverSize,
                      width: coverSize,
                      child: Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.center,
                        children: [
                          if (newAlbumImage != null)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(5),
                              child: Image.file(
                                newAlbumImage!,
                                fit: BoxFit.cover,
                                width: coverSize,
                                height: coverSize,
                                errorBuilder: (_, __, ___) => const ColoredBox(color: Colors.black26),
                              ),
                            )
                          else
                            AlbumImage(
                              item: albumImage,
                              borderRadius: const BorderRadius.all(Radius.circular(5)),
                              tapToZoom: false,
                            ),
                          if (canEdit)
                            Stack(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.4),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                ),
                                const Center(child: Icon(TablerIcons.edit, color: Colors.white, size: 32.0)),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10, height: 1),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Form(
                          key: formKey,
                          child: TextFormField(
                            initialValue: name,
                            textAlign: TextAlign.start,
                            cursorColor: ColorScheme.of(context).onSurface,
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                              labelText: AppLocalizations.of(context)!.name,
                              floatingLabelBehavior: FloatingLabelBehavior.never,
                              filled: true,
                              fillColor: Theme.brightnessOf(context) == Brightness.dark
                                  ? Colors.black.withOpacity(0.8)
                                  : Colors.white.withOpacity(0.8),
                              border: OutlineInputBorder(
                                borderSide: BorderSide.none,
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            textInputAction: TextInputAction.done,
                            validator: (value) =>
                                (value == null || value.isEmpty) ? AppLocalizations.of(context)!.required : null,
                            onFieldSubmitted: (_) async => await onSubmit(),
                            onChanged: onNameChanged,
                            onSaved: (newValue) => onNameChanged(newValue ?? ''),
                          ),
                        ),
                        FormField<bool>(
                          builder: (state) => CheckboxListTile(
                            value: publicVisibility,
                            title: Text(
                              AppLocalizations.of(context)!.publiclyVisiblePlaylist,
                              textAlign: TextAlign.left,
                            ),
                            contentPadding: const EdgeInsets.symmetric(vertical: 0.0, horizontal: 4.0),
                            onChanged: (value) {
                              state.didChange(value);
                              if (value != null) onVisibilityChanged(value);
                            },
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: Wrap(
                            spacing: _PlaylistEditScreenState._wrapSpacing,
                            children: [Text(trackCountString), Text(trackDurationString)],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RemovedTracksSection extends StatelessWidget {
  const _RemovedTracksSection({required this.removedTracks, required this.onRestore});

  final List<BaseItemDto> removedTracks;
  final void Function(int index) onRestore;

  @override
  Widget build(BuildContext context) {
    return SliverStickyHeader(
      header: Padding(
        padding: const EdgeInsets.only(left: 12.0, top: 16.0, bottom: 2.0),
        child: Text(AppLocalizations.of(context)!.removedTracks, style: Theme.of(context).textTheme.titleMedium),
      ),
      sliver: removedTracks.isEmpty
          ? SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 20.0),
                child: Center(child: Text(AppLocalizations.of(context)!.removedTracksEmptyListPlaceholder)),
              ),
            )
          : SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final item = removedTracks[index];
                return Material(
                  type: MaterialType.transparency,
                  key: ValueKey(item.id),
                  child: EditListTile(
                    item: item,
                    listIndex: index,
                    restoreInsteadOfRemove: true,
                    onRemoveOrRestore: () => onRestore(index),
                    onTap: (bool playable) {},
                  ),
                );
              }, childCount: removedTracks.length),
            ),
    );
  }
}

class _PlaylistSaveFeedbackController extends ChangeNotifier {
  bool _showSuccess = false;
  bool get showSuccess => _showSuccess;

  void success() {
    _showSuccess = true;
    notifyListeners();
    Future.delayed(const Duration(milliseconds: 750), () {
      if (_showSuccess) {
        _showSuccess = false;
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _showSuccess = false;
    super.dispose();
  }
}

class _PlaylistSaveFAB extends StatefulWidget {
  const _PlaylistSaveFAB({required this.isSaving, required this.onPressed, required this.controller});
  final bool isSaving;
  final VoidCallback? onPressed;
  final _PlaylistSaveFeedbackController controller;

  @override
  State<_PlaylistSaveFAB> createState() => _PlaylistSaveFABState();
}

class _PlaylistSaveFABState extends State<_PlaylistSaveFAB> with SingleTickerProviderStateMixin {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(covariant _PlaylistSaveFAB oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (widget.controller.showSuccess) {
      // Light haptic feedback if available
      FeedbackHelper.feedback(FeedbackType.selection);
      setState(() {});
    } else {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final showingSuccess = widget.controller.showSuccess;
    final isSaving = widget.isSaving && !showingSuccess; // freeze spinner during success flash if already done
    final l10n = AppLocalizations.of(context)!; // assume localization is always available
    return Tooltip(
      message: isSaving
          ? l10n.savingChanges
          : showingSuccess
          ? l10n.playlistUpdated
          : l10n.updatePlaylistButtonLabel,
      waitDuration: const Duration(milliseconds: 400),
      child: Semantics(
        button: true,
        label: showingSuccess ? l10n.playlistUpdated : (isSaving ? l10n.savingChanges : l10n.updatePlaylistButtonLabel),
        child: FloatingActionButton.extended(
          heroTag: 'playlist-edit-save-fab',
          onPressed: isSaving || showingSuccess ? null : widget.onPressed,
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: ScaleTransition(scale: anim, child: child),
            ),
            child: showingSuccess
                ? const Icon(TablerIcons.check, key: ValueKey('success-icon'))
                : isSaving
                ? const SizedBox(
                    key: ValueKey('saving-icon'),
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(TablerIcons.device_floppy, key: ValueKey('save-icon')),
          ),
          label: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SizeTransition(sizeFactor: anim, axis: Axis.horizontal, child: child),
            ),
            child: showingSuccess
                ? Text(l10n.playlistUpdated, key: const ValueKey('success-label'))
                : isSaving
                ? Text(l10n.savingChanges, key: const ValueKey('saving-label'))
                : Text(l10n.updatePlaylistButtonLabel, key: const ValueKey('save-label')),
          ),
        ),
      ),
    );
  }
}
