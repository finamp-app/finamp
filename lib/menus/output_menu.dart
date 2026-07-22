import 'dart:async';
import 'dart:io';

import 'package:finamp/color_schemes.g.dart';
import 'package:finamp/components/Buttons/cta_medium.dart';
import 'package:finamp/components/album_image.dart';
import 'package:finamp/components/Shortcuts/global_shortcut_manager.dart';
import 'package:finamp/components/Shortcuts/music_control_shortcuts.dart';
import 'package:finamp/components/global_snackbar.dart';
import 'package:finamp/components/themed_bottom_sheet.dart';
import 'package:finamp/components/toggleable_list_tile.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/services/feedback_helper.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:finamp/services/jellyfin_api.dart' as jellyfin_api;
import 'package:finamp/services/jellyfin_api_helper.dart';
import 'package:finamp/services/music_player_background_task.dart';
import 'package:finamp/services/queue_service.dart';
import 'package:finamp/services/remote_session_service.dart';
import 'package:finamp/services/theme_provider.dart';
import 'package:finamp/utils/platform_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_sticky_header/flutter_sticky_header.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:flutter_to_airplay/flutter_to_airplay.dart';
import 'package:get_it/get_it.dart';

const outputMenuRouteName = "/output-menu";

Future<void> showOutputMenu({required BuildContext context, bool usePlayerTheme = true}) async {
  final queueService = GetIt.instance<QueueService>();

  FeedbackHelper.feedback(FeedbackType.selection);

  await showThemedBottomSheet(
    context: context,
    item: queueService.getCurrentTrack()?.baseItem,
    routeName: outputMenuRouteName,
    minDraggableHeight: 0.2,
    buildSlivers: (context) {
      final menuEntries = [
        // SongInfo.condensed(
        //   item: item,
        //   useThemeImage: usePlayerTheme,
        // ),
        Consumer(
          builder: (context, ref, child) {
            final localVolume = (ref.watch(finampSettingsProvider.currentVolume) * 100).floor() / 100.0;
            // While connected to a remote session, the slider reflects and
            // controls the remote client's volume (if it reports one);
            // MusicPlayerBackgroundTask.setVolume routes to the remote.
            return StreamBuilder<SessionInfo?>(
              stream: GetIt.instance<RemoteSessionService>().getRemoteStateStream(),
              builder: (context, snapshot) {
                final remoteSession = GetIt.instance<RemoteSessionService>();
                return VolumeSlider(
                  initialValue: remoteSession.isRemote ? (remoteSession.remoteVolume ?? 1.0) : localVolume,
                  onChange: (double currentValue) async {
                    final audioHandler = GetIt.instance<MusicPlayerBackgroundTask>();
                    audioHandler.setVolume(currentValue);
                  },
                  forceLoading: true,
                );
              },
            );
          },
        ),
        if (isDesktop)
          Center(
            child: Text(
              AppLocalizations.of(context)!.volumeControlHint(
                "${GlobalShortcuts.getDisplay(VolumeUpIntent)} / "
                "${GlobalShortcuts.getDisplay(VolumeDownIntent)}",
              ),
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ),
        const SizedBox(height: 10),
      ];

      var menu = [
        SliverStickyHeader(
          header: const OutputMenuHeader(),
          sliver: SliverToBoxAdapter(child: SizedBox.shrink()),
        ),
        SliverStickyHeader(
          header: Padding(
            padding: const EdgeInsets.only(top: 10.0, bottom: 8.0, left: 16.0, right: 16.0),
            child: Text(
              AppLocalizations.of(context)!.outputMenuVolumeSectionTitle,
              // AppLocalizations.of(context)!.outputMenuVolumeSectionTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          sliver: MenuMask(
            height: OutputMenuHeader.defaultHeight,
            child: SliverList(delegate: SliverChildListDelegate.fixed(menuEntries)),
          ),
        ),
        // One combined device list: native audio outputs (Android) and remote
        // Jellyfin sessions this device can cast to / control (Play On /
        // Connect; not available in offline mode).
        if (Platform.isAndroid || !FinampSettingsHelper.finampSettings.isOffline)
          SliverStickyHeader(
            header: Padding(
              padding: const EdgeInsets.only(top: 10.0, bottom: 8.0, left: 16.0, right: 16.0),
              child: Text(
                AppLocalizations.of(context)!.outputMenuDevicesSectionTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            sliver: MenuMask(height: OutputMenuHeader.defaultHeight, child: OutputTargetList()),
          ),
      ];
      // TODO better estimate, how to deal with lag getting playlists?
      var stackHeight = MediaQuery.heightOf(context) * (Platform.isAndroid ? 0.75 : 0.55);
      return (stackHeight, menu);
    },
  );
}

class OutputMenuHeader extends ConsumerWidget {
  const OutputMenuHeader({super.key});

  static MenuMaskHeight defaultHeight = MenuMaskHeight(36.0);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(top: 6.0, bottom: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SizedBox(
            // just for justifying the remaining contents of the row
            width: 38,
          ),
          Center(
            child: Text(
              AppLocalizations.of(context)!.outputMenuTitle,
              // AppLocalizations.of(context)!.outputMenuTitle,
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyLarge!.color!,
                fontSize: 18,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          if (Platform.isIOS)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: AnimatedSwitcher(
                duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 1000),
                switchOutCurve: const Threshold(0.0),
                child: Consumer(
                  builder: (context, ref, child) {
                    return AirPlayRoutePickerView(
                      key: ValueKey(ref.watch(localThemeProvider).primary),
                      tintColor: ref.watch(localThemeProvider).primary,
                      activeTintColor: jellyfinBlueColor,
                      onShowPickerView: () => FeedbackHelper.feedback(FeedbackType.selection),
                    );
                  },
                ),
              ),
            ),
          if (Platform.isAndroid)
            IconButton(
              icon: Icon(TablerIcons.cast),
              onPressed: () {
                final audioHandler = GetIt.instance<MusicPlayerBackgroundTask>();
                audioHandler.getRoutes();
                // audioHandler.setOutputToDeviceSpeaker();
                // audioHandler.setOutputToBluetoothDevice();
                audioHandler.showOutputSwitcherDialog();
              },
            ),
          if (!Platform.isAndroid && !Platform.isIOS) SizedBox(width: 32, height: 8),
        ],
      ),
    );
  }
}

/// One combined list of playback targets: the device's native audio outputs
/// (Android output switcher routes) and the remote Jellyfin sessions this
/// device can hand playback off to / control (Play On / Connect), the latter
/// distinguished only by their cast icon. Local outputs and remote control
/// are mutually exclusive: while connected to a remote session the native
/// routes are replaced by a single synthetic "this device" tile that migrates
/// playback back; that tile also stands in on platforms without native
/// routes.
class OutputTargetList extends StatefulWidget {
  const OutputTargetList({super.key});

  @override
  State<OutputTargetList> createState() => _OutputTargetListState();
}

class _OutputTargetListState extends State<OutputTargetList> {
  final audioHandler = GetIt.instance<MusicPlayerBackgroundTask>();
  final _remoteSessionService = GetIt.instance<RemoteSessionService>();

  // Native routes and remote sessions load independently, so the (fast,
  // local) routes can be shown immediately while the (slow, server
  // round-trip) session list is still loading. Null = still loading.
  List<FinampOutputRoute>? _routes;
  List<SessionInfo>? _sessions;

  /// Discards results of superseded loads (the list is reloaded on remote
  /// state changes and after switching routes).
  int _loadGeneration = 0;

  String? switchingToRoute;
  String? _connectingToSessionId;
  bool _disconnecting = false;
  bool _stoppingRemote = false;
  StreamSubscription<SessionInfo?>? _remoteStateSubscription;

  @override
  void initState() {
    super.initState();
    _loadTargets();
    // Reload when the connected session changes (e.g. auto-disconnect while
    // the menu is open): the list content depends on remote state (native
    // routes are hidden while remote).
    _remoteStateSubscription = _remoteSessionService.getRemoteStateStream().distinct((a, b) => a?.id == b?.id).listen((
      _,
    ) {
      if (mounted) {
        setState(_loadTargets);
      }
    });
  }

  @override
  void dispose() {
    _remoteStateSubscription?.cancel();
    super.dispose();
  }

  void _loadTargets() {
    final generation = ++_loadGeneration;
    _routes = null;
    _sessions = FinampSettingsHelper.finampSettings.isOffline ? [] : null;
    unawaited(
      audioHandler
          .getRoutes() // empty off-Android
          .then((routes) {
            if (mounted && generation == _loadGeneration) setState(() => _routes = routes);
          })
          .catchError((Object e) {
            GlobalSnackbar.error(e);
            if (mounted && generation == _loadGeneration) setState(() => _routes = []);
          }),
    );
    if (_sessions == null) {
      unawaited(
        _loadSessions().then((sessions) {
          if (mounted && generation == _loadGeneration) setState(() => _sessions = sessions);
        }),
      );
    }
  }

  /// Loads the remote sessions this device can control. A failure shouldn't
  /// take the native outputs down with it, so it surfaces as a snackbar and
  /// an empty list.
  Future<List<SessionInfo>> _loadSessions() async {
    try {
      final myDeviceId = (await jellyfin_api.getDeviceInfo()).id;
      return (await GetIt.instance<JellyfinApiHelper>().getSessions())
          .where((s) => s.supportsRemoteControl && s.deviceId != myDeviceId)
          .toList();
    } catch (e) {
      GlobalSnackbar.message((context) => AppLocalizations.of(context)!.playOnDeviceListError(e.toString()));
      return [];
    }
  }

  Future<void> _selectRoute(FinampOutputRoute route) async {
    setState(() {
      switchingToRoute = route.name;
    });
    try {
      await audioHandler.setOutputToRoute(route);
    } finally {
      if (mounted) {
        setState(() {
          switchingToRoute = null;
          _loadTargets();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final routes = _routes;
    final sessions = _sessions;
    if (routes == null) {
      return SliverList(
        delegate: SliverChildListDelegate.fixed([
          const Center(child: CircularProgressIndicator.adaptive()),
          if (Platform.isAndroid) openOsOutputOptionsButton(context),
        ]),
      );
    }
    // Local output routes and remote control are mutually exclusive:
    // while a remote session is connected, the synthetic "this device"
    // tile is the single local option (tapping it migrates playback
    // back). It also stands in when there are no native routes
    // (non-Android).
    final showRoutes = !_remoteSessionService.isRemote && routes.isNotEmpty;
    final targets = <Widget>[
      if (!showRoutes) _thisDeviceTile(context),
      if (showRoutes)
        ...routes.map(
          (route) => OutputSelectorTile(
            routeInfo: route,
            isSelected: route.isSelected,
            isLoading: switchingToRoute == route.name,
            onSelect: () => _selectRoute(route),
          ),
        ),
      // Remote sessions get appended as soon as the server responds.
      if (sessions == null)
        const Center(
          child: Padding(padding: EdgeInsets.all(12.0), child: CircularProgressIndicator.adaptive()),
        )
      else
        ...sessions.map((session) => _sessionTile(context, session)),
      if (Platform.isAndroid && !_remoteSessionService.isRemote) openOsOutputOptionsButton(context),
    ];
    return SliverList(delegate: SliverChildListDelegate.fixed(targets));
  }

  Widget openOsOutputOptionsButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CTAMedium(
            text: AppLocalizations.of(context)!.outputMenuOpenConnectionSettingsButtonTitle,
            icon: TablerIcons.cast,
            //accentColor: Theme.of(context).colorScheme.primary,
            onPressed: () async {
              final audioHandler = GetIt.instance<MusicPlayerBackgroundTask>();
              // await audioHandler.showOutputSwitcherDialog();
              await audioHandler.openBluetoothSettings();
            },
          ),
        ],
      ),
    );
  }

  String _sessionDisplayName(SessionInfo session) =>
      session.deviceName ?? session.client ?? AppLocalizations.of(context)!.playOnUnknownDevice;

  Future<void> _connect(SessionInfo session) async {
    final queueService = GetIt.instance<QueueService>();
    final hasLocalQueue = queueService.getQueue().currentTrack != null;
    final remoteIsPlaying = session.nowPlayingItem != null;

    // If the target is already playing something, let the user choose between
    // just controlling that playback and migrating the local queue over
    // (overriding the remote queue).
    bool migrateQueue;
    if (remoteIsPlaying && hasLocalQueue) {
      final migrateChoice = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(AppLocalizations.of(context)!.playOnSessionActivePromptTitle),
          content: Text(AppLocalizations.of(context)!.playOnSessionActivePromptBody(_sessionDisplayName(session))),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(AppLocalizations.of(context)!.playOnAttachAction),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(AppLocalizations.of(context)!.playOnMigrateAction),
            ),
          ],
        ),
      );
      if (migrateChoice == null) return; // cancelled
      migrateQueue = migrateChoice;
    } else {
      // Only one side has a queue (or neither): migrate ours if we have one,
      // otherwise attach to whatever the remote has.
      migrateQueue = hasLocalQueue;
    }

    setState(() {
      _connectingToSessionId = session.id;
    });
    try {
      await _remoteSessionService.connect(session, migrateQueue: migrateQueue);
      GlobalSnackbar.message(
        (context) => migrateQueue
            ? AppLocalizations.of(context)!.playOnPlayingOnDevice(_sessionDisplayName(session))
            : AppLocalizations.of(context)!.playOnConnectedTo(_sessionDisplayName(session)),
      );
    } catch (e) {
      GlobalSnackbar.message((context) => AppLocalizations.of(context)!.playOnConnectFailed(e.toString()));
    } finally {
      if (mounted) {
        setState(() {
          _connectingToSessionId = null;
        });
      }
    }
  }

  Future<void> _disconnect() async {
    setState(() {
      _disconnecting = true;
    });
    try {
      await _remoteSessionService.disconnect();
      GlobalSnackbar.message((context) => AppLocalizations.of(context)!.playOnDisconnected);
    } finally {
      if (mounted) {
        setState(() {
          _disconnecting = false;
        });
      }
    }
  }

  /// Stops playback on the connected remote and fully disconnects, leaving this
  /// device's own queue restored but paused (or cleared if there was none).
  Future<void> _stopAndDisconnect() async {
    setState(() {
      _stoppingRemote = true;
    });
    try {
      await _remoteSessionService.stopAndDisconnect(restoreLocalQueue: true);
      GlobalSnackbar.message((context) => AppLocalizations.of(context)!.playOnStoppedAndDisconnected);
    } finally {
      if (mounted) {
        setState(() {
          _stoppingRemote = false;
        });
      }
    }
  }

  /// The kind of device Finamp is running on, for the "This phone" /
  /// "This tablet" / "This computer" label of the local playback entry.
  String _thisDeviceType(BuildContext context) {
    if (isDesktop) return "computer";
    return MediaQuery.sizeOf(context).shortestSide >= 600 ? "tablet" : "phone";
  }

  Widget _thisDeviceTile(BuildContext context) {
    final isLocal = !_remoteSessionService.isRemote;
    return ToggleableListTile(
      isLoading: _disconnecting,
      title: AppLocalizations.of(context)!.playOnThisDevice(_thisDeviceType(context)),
      subtitle: AppLocalizations.of(context)!.deviceType("speaker"),
      leading: Container(
        padding: const EdgeInsets.all(16.0),
        color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
        child: Icon(isDesktop ? TablerIcons.device_laptop : TablerIcons.device_mobile),
      ),
      icon: isLocal ? TablerIcons.device_speaker_filled : TablerIcons.device_speaker,
      state: isLocal,
      onToggle: (bool currentState) async {
        // Tapping the local device while connected pauses the remote and
        // migrates playback back to this device.
        if (!isLocal) {
          await _disconnect();
        }
      },
      confirmationFeedback: false,
      enabled: true,
    );
  }

  Widget _sessionTile(BuildContext context, SessionInfo session) {
    final isConnected = _remoteSessionService.isRemote && _remoteSessionService.activeSessionId == session.id;
    final nowPlayingItem = session.nowPlayingItem;

    // While connected, offer an explicit "stop & disconnect" action that stops
    // the remote (clearing its queue) and returns to this device.
    Widget? trailing;
    if (isConnected) {
      trailing = IconButton(
        icon: const Icon(TablerIcons.player_stop_filled),
        color: Theme.of(context).colorScheme.error,
        tooltip: AppLocalizations.of(context)!.playOnStopAndDisconnect,
        onPressed: _stoppingRemote ? null : _stopAndDisconnect,
      );
    }

    return ToggleableListTile(
      isLoading: _connectingToSessionId == session.id || (isConnected && _stoppingRemote),
      title: _sessionDisplayName(session),
      subtitle: session.client ?? AppLocalizations.of(context)!.deviceType("unknown"),
      // Surface what the device is currently playing (so the user knows what
      // they would take over) through its album art; a small cast badge keeps
      // the tile recognizable as a remote (cast) target. Idle devices keep
      // the plain cast icon.
      leading: nowPlayingItem != null
          ? Stack(
              children: [
                AlbumImage(item: nowPlayingItem),
                Positioned(
                  right: 2.0,
                  bottom: 2.0,
                  child: Container(
                    padding: const EdgeInsets.all(2.0),
                    decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4.0)),
                    child: const Icon(TablerIcons.cast, size: 14.0, color: Colors.white),
                  ),
                ),
              ],
            )
          : Container(
              padding: const EdgeInsets.all(16.0),
              color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
              // The icon marks the tile as a remote (cast) target; the
              // connection state is conveyed by the tile's active state, not
              // the icon.
              child: Icon(TablerIcons.cast),
            ),
      icon: isConnected ? TablerIcons.device_speaker_filled : TablerIcons.device_speaker,
      trailing: trailing,
      state: isConnected,
      onToggle: (bool currentState) async {
        // Already connected to this session: nothing to do. Disconnecting is
        // done via the stop button, or by selecting another device (or the
        // local one).
        if (!isConnected) {
          await _connect(session);
        }
      },
      confirmationFeedback: false,
      enabled: true,
    );
  }
}

class OutputSelectorTile extends StatelessWidget {
  const OutputSelectorTile({
    super.key,
    required this.routeInfo,
    required this.isSelected,
    this.isLoading = false,
    required this.onSelect,
  });

  final FinampOutputRoute routeInfo;
  final bool isSelected;
  final bool isLoading;
  final Future<void> Function() onSelect;

  @override
  Widget build(BuildContext context) {
    return ToggleableListTile(
      isLoading: isLoading,
      title: routeInfo.name,
      subtitle: (routeInfo.isDeviceSpeaker
          ? AppLocalizations.of(context)!.deviceType("speaker")
          : switch (routeInfo.deviceType) {
              1 => AppLocalizations.of(context)!.deviceType("tv"),
              3 => AppLocalizations.of(context)!.deviceType("bluetooth"),
              _ => AppLocalizations.of(context)!.deviceType("unknown"),
            }),
      // subtitle: AppLocalizations.of(context)!.songCount(childCount ?? 0),
      leading: Container(
        padding: const EdgeInsets.all(16.0),
        color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
        child: Icon(switch (routeInfo.deviceType) {
          1 => TablerIcons.device_tv,
          3 => TablerIcons.bluetooth,
          _ => TablerIcons.volume,
        }),
      ),
      icon: isSelected ? TablerIcons.device_speaker_filled : TablerIcons.device_speaker,
      state: isSelected,
      onToggle: (bool currentState) => onSelect(),
      confirmationFeedback: false,
      enabled: true,
    );
  }
}

class VolumeSlider extends ConsumerStatefulWidget {
  const VolumeSlider({
    super.key,
    required this.initialValue,
    required this.onChange,
    this.forceLoading = false,
    this.feedback = true,
  });

  final double initialValue;
  final bool forceLoading;
  final Future<void> Function(double currentValue) onChange;
  final bool feedback;

  @override
  ConsumerState<VolumeSlider> createState() => _VolumeSliderState();
}

class _VolumeSliderState extends ConsumerState<VolumeSlider> {
  double currentValue = 0;
  Timer? debounce;

  @override
  void initState() {
    super.initState();
    currentValue = widget.initialValue;
  }

  @override
  void didUpdateWidget(VolumeSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.forceLoading) {
      currentValue = widget.initialValue;
    }
  }

  @override
  Widget build(BuildContext context) {
    var themeColor = Theme.of(context).colorScheme.primary;
    double sliderHeight = 56.0;
    return Padding(
      padding: const EdgeInsets.only(left: 12.0, right: 12.0, top: 4.0, bottom: 4.0),
      child: Container(
        decoration: ShapeDecoration(
          color: themeColor.withOpacity(0.3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        clipBehavior: Clip.antiAlias,
        padding: EdgeInsets.zero,
        child: Stack(
          children: [
            SizedBox(
              height: sliderHeight,
              width: double.infinity,
              child: SliderTheme(
                data: SliderThemeData(
                  trackHeight: sliderHeight,
                  // Same as container height
                  padding: EdgeInsets.zero,

                  trackShape: RoundedRectangleTrackShape(),
                  thumbShape: VerticalSliderThumbShape(
                    thumbWidth: 2.0,
                    thumbHeight: 24.0,
                    borderRadius: 8.0,
                    offsetLeft: -9.0,
                  ),
                  thumbColor: Colors.white,
                  activeTrackColor: themeColor,
                  inactiveTrackColor: themeColor.withOpacity(0.3),
                  overlayShape: SliderComponentShape.noOverlay,
                ),
                child: Slider(
                  value: currentValue,
                  onChanged: (value) {
                    setState(() {
                      currentValue = value;
                    });
                    if (debounce?.isActive ?? false) debounce!.cancel();
                    debounce = Timer(const Duration(milliseconds: 100), () {
                      widget.onChange(value);
                    });
                  },
                  onChangeEnd: (value) async {
                    unawaited(widget.onChange(value));
                    if (widget.feedback) {
                      FeedbackHelper.feedback(FeedbackType.selection);
                    }
                    setState(() {
                      currentValue = value;
                    });
                  },
                  autofocus: false,
                  focusNode: FocusNode(skipTraversal: true, canRequestFocus: false),
                ),
              ),
            ),
            Positioned(
              top: 0,
              bottom: 0,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  "${(currentValue * 100).floor()}%",
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RoundedRectangleTrackShape extends RoundedRectSliderTrackShape {
  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final double trackHeight = sliderTheme.trackHeight ?? 0;
    final double trackLeft = offset.dx;
    final double trackTop = offset.dy + (parentBox.size.height - trackHeight) / 2;
    final double trackWidth = parentBox.size.width;

    return Rect.fromLTWH(trackLeft, trackTop, trackWidth, trackHeight);
  }

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
    double additionalActiveTrackHeight = 0,
  }) {
    final Canvas canvas = context.canvas;
    final Rect trackRect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );

    // Active track
    final activeRect = Rect.fromLTRB(
      trackRect.left,
      trackRect.top,
      thumbCenter.dx + sliderTheme.thumbShape!.getPreferredSize(isEnabled, isDiscrete).width,
      trackRect.bottom,
    );

    final Paint activePaint = Paint()..color = sliderTheme.activeTrackColor!;
    final Paint inactivePaint = Paint()..color = sliderTheme.inactiveTrackColor!;

    final radius = Radius.circular(12.0);

    canvas.drawRRect(RRect.fromRectAndRadius(trackRect, radius), inactivePaint);

    final activeRRect = RRect.fromRectAndRadius(activeRect, radius);

    canvas.drawRRect(activeRRect, activePaint);
  }
}

class VerticalSliderThumbShape extends SliderComponentShape {
  final double thumbWidth;
  final double thumbHeight;
  final double borderRadius;
  final double offsetLeft;

  VerticalSliderThumbShape({
    this.thumbWidth = 4.0,
    this.thumbHeight = 40.0,
    this.borderRadius = 8.0,
    this.offsetLeft = 0.0,
  });

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) {
    return Size(thumbWidth - offsetLeft * 3, thumbHeight);
  }

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final Paint paint = Paint()
      ..color = sliderTheme.thumbColor!
      ..style = PaintingStyle.fill;

    final Rect thumbRect = Rect.fromCenter(
      center: center.translate(-offsetLeft * 2, 0),
      width: getPreferredSize(true, true).width + offsetLeft * 3,
      height: getPreferredSize(true, true).height,
    );

    final RRect thumbRRect = RRect.fromRectAndRadius(thumbRect, Radius.circular(borderRadius));

    context.canvas.drawRRect(thumbRRect, paint);
  }
}
