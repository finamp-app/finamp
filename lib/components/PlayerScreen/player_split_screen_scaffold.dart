import 'dart:async';

import 'package:finamp/components/global_snackbar.dart';
import 'package:finamp/screens/lyrics_screen.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:finamp/services/keep_screen_on_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:split_view/split_view.dart';

import '../../models/finamp_models.dart';
import '../../screens/player_screen.dart';
import '../../services/queue_service.dart';

bool _inSplitScreen = false;

bool get usingPlayerSplitScreen => _inSplitScreen;

double _weight = 0.0;

SplitViewController _controller = SplitViewController();

Timer? _timer;
double? _playerWidth;

Widget buildPlayerSplitScreenScaffold(BuildContext context, Widget? widget) {
  return LayoutBuilder(
    builder: (context, constraints) {
      // Only use split screen if wide enough to easily show both views and tall enough
      // that a landscape full-screen player is not preferred instead
      if (constraints.maxWidth < 800 || constraints.maxHeight < 500) {
        _inSplitScreen = false;
        return widget!;
      }
      final queueService = GetIt.instance<QueueService>();
      // Minimum player width is 275.  Minimum menu width is 400.
      _controller = SplitViewController(
        limits: [WeightLimit(min: 400 / constraints.maxWidth, max: 1.0 - (275 / constraints.maxWidth))],
      );

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
                      snapshot.data!.currentTrack != null) &&
                  allowSplitScreen) {
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
                          padding: padding.copyWith(right: padding.right + 10),
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
                            pages: const [MaterialPage(child: PlayerScreen())],
                            onPopPage: (_, __) => false,
                            onGenerateRoute: (x) {
                              GlobalSnackbar.navigatorState!.pushNamed(x.name!, arguments: x.arguments);
                              return EmptyRoute();
                            },
                            observers: [KeepScreenOnObserver()],
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
            },
          );
        },
      );
    },
  );
}

class EmptyRoute extends Route {
  @override
  List<OverlayEntry> get overlayEntries => [OverlayEntry(builder: (_) => const SizedBox.shrink())];
  @override
  void didAdd() {
    super.didAdd();
    navigator?.pop();
  }
}

class SplitScreenNavigatorObserver extends NavigatorObserver {
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (usingPlayerSplitScreen && previousRoute != null && !shouldNotPop(previousRoute)) {
      queuePop();
    }
  }

  static final _playerCheck = ModalRoute.withName(PlayerScreen.routeName);
  static final _lyricsCheck = ModalRoute.withName(LyricsScreen.routeName);

  static void queuePop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      GlobalSnackbar.navigatorState?.popUntil(SplitScreenNavigatorObserver.shouldNotPop);
    });
  }

  static bool shouldNotPop(Route route) {
    return !_playerCheck(route) && !_lyricsCheck(route);
  }
}
