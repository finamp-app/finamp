import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:finamp/components/padded_custom_scrollview.dart';
import 'package:finamp/menus/components/menu_item_info_header.dart';
import 'package:finamp/menus/components/playbackActions/playback_action_row.dart';
import 'package:finamp/screens/blurred_player_screen_background.dart';
import 'package:finamp/services/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../menus/components/menuEntries/menu_entry.dart';
import '../models/jellyfin_models.dart';
import '../services/feedback_helper.dart';
import '../services/finamp_settings_helper.dart';

typedef SliverBuilder = (double, List<Widget>) Function(BuildContext);

typedef WrapperBuilder = Widget Function(BuildContext, DraggableScrollableController, ScrollBuilder);
typedef ScrollBuilder = Widget Function(double, List<Widget>);

Future<T?> showThemedBottomSheet<T>({
  required BuildContext context,
  BaseItemDto? item,
  required String routeName,
  SliverBuilder? buildSlivers,
  WrapperBuilder? buildWrapper,
  double minDraggableHeight = 0.6,
  bool showDragHandle = true,
}) async {
  FeedbackHelper.feedback(FeedbackType.selection);
  bool useDefaultTheme = false;
  final menu = ThemedBottomSheet(
    key: ValueKey((item?.id?.raw ?? "") + routeName),
    buildSlivers: buildSlivers,
    buildWrapper: buildWrapper,
    minDraggableHeight: minDraggableHeight,
    showDragHandle: showDragHandle,
  );
  return await showModalBottomSheet<T>(
    context: context,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20.0))),
    isScrollControlled: true,
    clipBehavior: Clip.hardEdge,
    constraints: BoxConstraints(
      maxWidth: (Platform.isIOS || Platform.isAndroid) ? 500 : min(500, MediaQuery.widthOf(context) * 0.9),
    ),
    isDismissible: true,
    enableDrag: true,
    useSafeArea: true,
    routeSettings: RouteSettings(name: routeName),
    // Anchor to bottom right sub screen, required for foldables
    // On book-style foldables, this will anchor to the right half of the screen.
    // On flip-style foldables, this will anchor to the bottom half of the screen.
    anchorPoint: Offset(double.maxFinite, double.maxFinite),
    builder: (BuildContext context) {
      return ProviderScope(
        overrides: [
          if (useDefaultTheme || item == null) localThemeProvider.overrideWith((_) => ColorScheme.of(context)),
          if (!useDefaultTheme && item != null)
            localThemeInfoProvider.overrideWithValue(ThemeInfo(item, useIsolate: false)),
        ],
        child: menu,
      );
    },
  );
}

class ThemedBottomSheet extends ConsumerStatefulWidget {
  const ThemedBottomSheet({
    super.key,
    this.buildSlivers,
    this.buildWrapper,
    required this.minDraggableHeight,
    required this.showDragHandle,
  });

  final SliverBuilder? buildSlivers;
  final WrapperBuilder? buildWrapper;
  final double minDraggableHeight;
  final bool showDragHandle;

  static double calculateStackHeight({
    required BuildContext context,
    required List<HideableMenuEntry> menuEntries,
    double? extraHeight,
    bool includePlaybackRow = true,
    bool includePlaybackRowPageIndicator = true,
  }) {
    double stackHeight = infoHeaderFullExtent;
    stackHeight +=
        menuEntries.where((element) => element.isVisible).length *
        (Theme.of(context).visualDensity == VisualDensity.compact ? 48 : 56);
    stackHeight += extraHeight ?? 0.0;
    stackHeight += includePlaybackRow ? playActionRowHeightDefault : 0;
    stackHeight += includePlaybackRowPageIndicator ? playActionPageIndicatorHeightDefault : 0;
    return stackHeight;
  }

  @override
  ConsumerState<ThemedBottomSheet> createState() => _ThemedBottomSheetState();
}

class _ThemedBottomSheetState extends ConsumerState<ThemedBottomSheet> {
  final ScrollController _controller = ScrollController();

  final dragController = DraggableScrollableController();

  @override
  Widget build(BuildContext context) {
    // Exactly one builder must be supplied.
    assert(widget.buildSlivers == null || widget.buildWrapper == null);
    assert(widget.buildSlivers != null || widget.buildWrapper != null);
    return Theme(
      data: ThemeData(colorScheme: ref.watch(localThemeProvider)),
      child: Builder(
        builder: (BuildContext context) {
          Widget child;
          if (widget.buildWrapper != null) {
            child = widget.buildWrapper!(context, dragController, (height, slivers) => buildInternal(height, slivers));
          } else {
            var (height, slivers) = widget.buildSlivers!(context);
            child = buildInternal(height, slivers);
          }
          final colorScheme = ColorScheme.of(context);
          return ColoredBox(
            color: ElevationOverlay.applySurfaceTint(colorScheme.surface, colorScheme.surfaceTint, 1),
            child: child,
          );
        },
      ),
    );
  }

  Widget buildInternal(double stackHeight, List<Widget> slivers) {
    stackHeight += widget.showDragHandle ? 29.5 : 0;
    // Account for bottom padding in PaddedCustomscrollview
    stackHeight += 32;
    stackHeight += MediaQuery.paddingOf(context).bottom;

    if (Platform.isIOS || Platform.isAndroid) {
      return LayoutBuilder(
        builder: (context, constraints) {
          var size = (stackHeight / constraints.maxHeight).clamp(widget.minDraggableHeight, 1.0);
          return DraggableScrollableSheet(
            controller: dragController,
            snap: true,
            initialChildSize: size,
            minChildSize: size * 0.75,
            expand: false,
            builder: (context, scrollController) => menu(scrollController, slivers),
          );
        },
      );
    } else {
      final child = menu(_controller, slivers);
      return LayoutBuilder(
        builder: (context, constraints) {
          var minSize = widget.minDraggableHeight * constraints.maxHeight;
          return SizedBox(
            // This is an overestimate of stack height on desktop, but this widget
            // needs some bottom padding on large displays anyway.
            height: max(minSize, stackHeight),
            child: child,
          );
        },
      );
    }
  }

  Widget menu(ScrollController scrollController, List<Widget> slivers) {
    var scrollview = PaddedCustomScrollview(controller: scrollController, slivers: slivers);
    return Stack(
      children: [
        if (ref.watch(finampSettingsProvider.useCoverAsBackground)) const BlurredPlayerScreenBackground(),
        widget.showDragHandle
            ? Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 16.0, bottom: 10.0),
                    child: Builder(
                      builder: (context) {
                        var textColor = Theme.of(context).textTheme.bodySmall!.color!;
                        return Container(
                          width: 40,
                          height: 3.5,
                          decoration: BoxDecoration(color: textColor, borderRadius: BorderRadius.circular(3.5)),
                        );
                      },
                    ),
                  ),
                  Expanded(child: scrollview),
                ],
              )
            : scrollview,
      ],
    );
  }
}

/// This type extension ensures that the MenuMask isn't used with an arbitrary height, but only with the heights of the actual used headers
extension type MenuMaskHeight._(double raw) {
  const MenuMaskHeight(this.raw);
  double operator +(MenuMaskHeight other) => raw + other.raw;
  double operator /(double other) => raw / other;
}

class MenuMask extends SingleChildRenderObjectWidget {
  const MenuMask({super.key, super.child, required this.height});

  final MenuMaskHeight height;

  @override
  RenderTrackMenuMask createRenderObject(BuildContext context) {
    return RenderTrackMenuMask(height.raw);
  }

  @override
  void updateRenderObject(BuildContext context, RenderTrackMenuMask renderObject) {
    renderObject.updateHeight(height.raw);
    super.updateRenderObject(context, renderObject);
  }
}

class RenderTrackMenuMask extends RenderProxySliver {
  RenderTrackMenuMask(this.height);

  double height;

  @override
  ShaderMaskLayer? get layer => super.layer as ShaderMaskLayer?;

  @override
  bool get alwaysNeedsCompositing => child != null;

  void updateHeight(double newHeight) {
    if (height != newHeight) {
      height = newHeight;
      layer = null;
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child != null) {
      layer ??= ShaderMaskLayer(
        shader: const LinearGradient(
          colors: [Color.fromARGB(0, 255, 255, 255), Color.fromARGB(255, 255, 255, 255)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Rect.fromLTWH(0, height, 0, 10)),
        blendMode: BlendMode.modulate,
        maskRect: Rect.fromLTWH(0, 0, 99999, height + 15),
      );

      context.pushLayer(layer!, super.paint, offset);
    } else {
      layer = null;
    }
  }
}
