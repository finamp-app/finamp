import 'dart:async';
import 'dart:io';

import 'package:finamp/components/global_snackbar.dart';
import 'package:finamp/screens/lyrics_screen.dart';
import 'package:finamp/screens/splash_screen.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:finamp/services/keep_screen_on_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:split_view/split_view.dart';

import '../../models/finamp_models.dart';
import '../../screens/player_screen.dart';
import '../../services/queue_service.dart';

// TODO this should probably be a notifier?  It does seem to force a rebuild of all relevent widgets, so it
//  doesn't matter in practice, but that would be more correct.
bool _inSplitScreen = false;

final ValueNotifier<bool> splitScreenAvailable = ValueNotifier(false);
final ValueNotifier<bool> minimizeSplitScreen = ValueNotifier(false);
final ValueNotifier<bool> usingSplitScreen = ValueNotifier(false);

bool get usingPlayerSplitScreen => _inSplitScreen;

double _weight = 0.0;

SplitViewController _controller = SplitViewController();

Timer? _timer;
double? _playerWidth;

/// Smallest size at which the split screen is used.
const Size _splitScreenMinSize = Size(800, 500);

final bool _isDesktop = Platform.isLinux || Platform.isWindows || Platform.isMacOS;

Widget buildPlayerSplitScreenScaffold(BuildContext context, Widget? widget) {
  return LayoutBuilder(
    builder: (context, constraints) {
      // Only use split screen if wide enough to easily show both views and tall enough
      // that a landscape full-screen player is not preferred instead
      final bigEnough =
          constraints.maxWidth >= _splitScreenMinSize.width && constraints.maxHeight >= _splitScreenMinSize.height;
      return DelayedFlag(
        value: bigEnough,
        waitForNextFrame: _isDesktop,
        builder: (context, bigEnough) {
          if (!bigEnough) {
            _inSplitScreen = false;
            splitScreenAvailable.value = false;
            return widget!;
          }
          return _buildSplitScreen(context, constraints, widget);
        },
      );
    },
  );
}

Widget _buildSplitScreen(BuildContext context, BoxConstraints constraints, Widget? widget) {
  final queueService = GetIt.instance<QueueService>();
  // Minimum player width is 275.  Minimum menu width is 400.
  _controller = SplitViewController(
    limits: [WeightLimit(min: 400 / constraints.maxWidth, max: 1.0 - (275 / constraints.maxWidth))],
  );

  return ValueListenableBuilder(
    valueListenable: minimizeSplitScreen,
    builder: (context, minimizeValue, _) {
      return Consumer(
        builder: (context, ref, child) {
          bool allowSplitScreen = ref.watch(finampSettingsProvider.allowSplitScreen);
          return StreamBuilder<FinampQueueInfo?>(
            stream: queueService.getQueueStream(),
            initialData: queueService.getQueue(),
            builder: (context, snapshot) {
              if (snapshot.hasData &&
                  (snapshot.data!.saveState == SavedQueueState.loading ||
                      snapshot.data!.saveState == SavedQueueState.failed ||
                      snapshot.data!.currentTrack != null)) {
                splitScreenAvailable.value = true;
                if (allowSplitScreen && !minimizeValue) {
                  _inSplitScreen = true;
                  SplitScreenNavigatorObserver.queuePop();
                  var size = MediaQuery.sizeOf(context);
                  var padding = MediaQuery.paddingOf(context);
                  // When resizing window, update weights to keep player width consistent
                  _weight =
                      (1.0 -
                              (_playerWidth ?? FinampSettingsHelper.finampSettings.splitScreenPlayerWidth) /
                                  constraints.maxWidth)
                          .clamp(_controller.limits[0]!.min!, _controller.limits[0]!.max!);
                  _controller.weights = [_weight];
                  return SplitView(
                    key: const ValueKey("PlayerSplitView"),
                    resizingAreaSize: 20,
                    gripSize: 0,
                    viewMode: SplitViewMode.Horizontal,
                    controller: _controller,
                    onWeightChanged: (weights) {
                      if (weights[0]! == _weight) {
                        // Weight is changing due to window resize, not drag action.
                        // Do not update setting.
                        return;
                      }
                      _playerWidth = (1.0 - weights[0]!) * constraints.maxWidth;
                      _timer?.cancel();
                      // Do not spam settings updates while resizing
                      _timer = Timer(const Duration(seconds: 1), () {
                        FinampSetters.setSplitScreenPlayerWidth(_playerWidth!);
                      });
                    },
                    children: [
                      ListenableBuilder(
                        listenable: _controller,
                        builder: (context, child) => MediaQuery(
                          data: MediaQuery.of(context).copyWith(
                            size: Size(size.width * (_controller.weights[0] ?? 1.0), size.height),
                            padding: padding.copyWith(right: padding.right + 6),
                          ),
                          child: child!,
                        ),
                        child: widget,
                      ),
                      ListenableBuilder(
                        listenable: _controller,
                        builder: (context, child) {
                          return MediaQuery(
                            data: MediaQuery.of(
                              context,
                            ).copyWith(size: Size(size.width * (1.0 - (_controller.weights[0] ?? 1.0)), size.height)),
                            child: child!,
                          );
                        },
                        child: HeroControllerScope(
                          controller: HeroController(),
                          child: ScaffoldMessenger(
                            child: Navigator(
                              pages: const [MaterialPage(canPop: false, child: PlayerScreen())],
                              onDidRemovePage: (_) {},
                              onGenerateRoute: (x) {
                                GlobalSnackbar.navigatorState!.pushNamed(x.name!, arguments: x.arguments);
                                return EmptyRoute();
                              },
                              observers: [KeepScreenOnObserver(), PushBackupObserver()],
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                } else {
                  _inSplitScreen = false;
                  return widget!;
                }
              } else {
                splitScreenAvailable.value = false;
                _inSplitScreen = false;
                return widget!;
              }
            },
          );
        },
      );
    },
  );
}

/// Builds with [value], but when [waitForNextFrame] is true, delays updating by one frame.
///
/// While native Linux changes (`linux/finamp_application.cc`) ensure the window restores to its
/// allocated size on remap, dynamic window manager adjustments (such as rapid tiling compositor
/// reflows or intermediate configure events) can still briefly cross the split-screen threshold.
///
/// When entering split-screen, [SplitScreenNavigatorObserver.queuePop] pops the player route
/// from the main navigator. Because a popped route does not revert on its own when the window
/// returns to a smaller size, a single transient frame would leave the user on the home screen
/// instead of the player. This single-frame delay ensures route popping and split-screen transitions
/// only occur for sustained window sizes.
@visibleForTesting
class DelayedFlag extends StatefulWidget {
  const DelayedFlag({super.key, required this.value, this.waitForNextFrame = false, required this.builder});

  final bool value;
  final bool waitForNextFrame;
  final Widget Function(BuildContext context, bool value) builder;

  @override
  State<DelayedFlag> createState() => _DelayedFlagState();
}

class _DelayedFlagState extends State<DelayedFlag> {
  late bool _value = widget.value;
  bool _frameCallbackScheduled = false;

  @override
  void didUpdateWidget(covariant DelayedFlag oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value == _value) {
      _frameCallbackScheduled = false;
    } else if (!widget.waitForNextFrame) {
      _frameCallbackScheduled = false;
      _value = widget.value;
    } else if (!_frameCallbackScheduled) {
      _frameCallbackScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _frameCallbackScheduled = false;
        if (widget.value != _value) {
          setState(() => _value = widget.value);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _value);
}

class EmptyRoute<T> extends Route<T> {
  @override
  List<OverlayEntry> get overlayEntries => [OverlayEntry(builder: (_) => const SizedBox.shrink())];
  @override
  void didAdd() {
    super.didAdd();
    navigator?.removeRoute(this);
  }
}

class SplitScreenNavigatorObserver extends NavigatorObserver {
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (usingPlayerSplitScreen && previousRoute != null && !shouldNotPop(previousRoute)) {
      queuePop();
    }
    // previousRoute will only be null if we've messed something up and accidentally popped the initial splashScreen
    // route.  This check will add it back to recover.  Hopefully this never happens.
    if (previousRoute == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        navigator?.pushNamed(SplashScreen.routeName);
      });
    }
  }

  static final _playerCheck = ModalRoute.withName(PlayerScreen.routeName);
  static final _lyricsCheck = ModalRoute.withName(LyricsScreen.routeName);

  static void queuePop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      GlobalSnackbar.navigatorState?.popUntil(SplitScreenNavigatorObserver.shouldNotPop);
    });
  }

  static bool shouldNotPop(Route<dynamic> route) {
    return !_playerCheck(route) && !_lyricsCheck(route);
  }
}

/// If route objects are pushed directly instead of using pushNamed, onGenerateroute will not have a chance to
/// intercept them and redirect to the main window.  This observer is a fallback to remove the route and re-add a copy
/// to the main navigator.
class PushBackupObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is MaterialPageRoute) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        navigator?.removeRoute(route);
        // The given route is already attached to the navigator, so we need to copy it.
        GlobalSnackbar.navigatorState!.push(
          MaterialPageRoute<dynamic>(builder: route.builder, settings: route.settings),
        );
      });
    }
    super.didPush(route, previousRoute);
  }
}
