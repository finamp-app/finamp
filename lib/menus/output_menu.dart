import 'dart:async';
import 'dart:io';

import 'package:finamp/color_schemes.g.dart';
import 'package:finamp/components/Buttons/cta_medium.dart';
import 'package:finamp/components/Shortcuts/global_shortcut_manager.dart';
import 'package:finamp/components/Shortcuts/music_control_shortcuts.dart';
import 'package:finamp/components/global_snackbar.dart';
import 'package:finamp/components/themed_bottom_sheet.dart';
import 'package:finamp/components/toggleable_list_tile.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/services/feedback_helper.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:finamp/services/music_player_background_task.dart';
import 'package:finamp/services/queue_service.dart';
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
            return VolumeSlider(
              initialValue: (ref.watch(finampSettingsProvider.currentVolume) * 100).floor() / 100.0,
              onChange: (double currentValue) async {
                final audioHandler = GetIt.instance<MusicPlayerBackgroundTask>();
                audioHandler.setVolume(currentValue);
              },
              forceLoading: true,
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
        if (Platform.isAndroid)
          SliverStickyHeader(
            header: Padding(
              padding: const EdgeInsets.only(top: 10.0, bottom: 8.0, left: 16.0, right: 16.0),
              child: Text(
                AppLocalizations.of(context)!.outputMenuDevicesSectionTitle,
                // AppLocalizations.of(context)!.outputMenuDevicesSectionTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            sliver: MenuMask(
              height: OutputMenuHeader.defaultHeight,
              child: OutputTargetList(), // Pass the outputRoutes
            ),
          ),
      ];
      // TODO better estimate, how to deal with lag getting playlists?
      var stackHeight = MediaQuery.heightOf(context) * (Platform.isAndroid ? 0.65 : 0.4);
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

class OutputTargetList extends StatefulWidget {
  const OutputTargetList({super.key});

  @override
  State<OutputTargetList> createState() => _OutputTargetListState();
}

class _OutputTargetListState extends State<OutputTargetList> {
  final audioHandler = GetIt.instance<MusicPlayerBackgroundTask>();
  String? switchingToRoute;

  @override
  Widget build(BuildContext context) {
    Future<List<FinampOutputRoute>> outputRoutes = audioHandler.getRoutes();
    return FutureBuilder(
      future: outputRoutes,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              if (index == snapshot.data!.length) {
                return openOsOutputOptionsButton(context);
              }
              final route = snapshot.data![index];
              if (route.isSelected) {
                switchingToRoute = null; // Reset switching state if route is selected
              }
              return OutputSelectorTile(
                routeInfo: route,
                isLoading: switchingToRoute == route.name,
                onSelect: ({bool loading = false, bool value = false}) {
                  setState(() {
                    switchingToRoute = loading ? route.name : null;
                    outputRoutes = audioHandler.getRoutes();
                  });
                },
              );
            }, childCount: snapshot.data!.length + 1),
          );
        } else if (snapshot.hasError) {
          GlobalSnackbar.error(snapshot.error);
          return const SliverToBoxAdapter(child: Center(heightFactor: 3.0, child: Icon(Icons.error, size: 64)));
        } else {
          return SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              if (index == 1) {
                return openOsOutputOptionsButton(context);
              } else {
                return const Center(child: CircularProgressIndicator.adaptive());
              }
            }, childCount: 2),
          );
        }
      },
    );
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
}

class OutputSelectorTile extends StatelessWidget {
  const OutputSelectorTile({super.key, required this.routeInfo, this.isLoading = false, this.onSelect});

  final FinampOutputRoute routeInfo;
  final bool isLoading;
  final void Function({bool loading, bool value})? onSelect;

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
      icon: routeInfo.isSelected ? TablerIcons.device_speaker_filled : TablerIcons.device_speaker,
      state: routeInfo.isSelected,
      onToggle: (bool currentState) async {
        final audioHandler = GetIt.instance<MusicPlayerBackgroundTask>();
        onSelect?.call(loading: true, value: currentState);
        await audioHandler.setOutputToRoute(routeInfo);
        onSelect?.call(loading: false, value: true);
      },
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
