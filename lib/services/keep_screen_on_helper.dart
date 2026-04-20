import 'package:battery_plus/battery_plus.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/screens/lyrics_screen.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:finamp/services/music_player_background_task.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:logging/logging.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Implements ability to keep screen on according to various conditions
class KeepScreenOnHelper {
  bool _keepingScreenOn = false;

  bool _isPlaying = false;
  bool _isLyricsShowing = false;
  bool _isPluggedIn = false;

  final _keepScreenOnLogger = Logger("KeepScreenOnHelper");

  KeepScreenOnHelper() {
    _attachEvents();
  }

  void _attachEvents() {
    // Subscribe to audio playback events
    final audioHandler = GetIt.instance<MusicPlayerBackgroundTask>();
    audioHandler.playbackState.listen((event) async {
      if (_isPlaying != event.playing) {
        setCondition(isPlaying: event.playing);
      }
    });

    // Subscribe to battery state change events
    var battery = Battery();
    BatteryState prevBattState = BatteryState.unknown;
    battery.onBatteryStateChanged.listen((BatteryState state) {
      if (prevBattState != state) {
        prevBattState = state;
        setCondition(batteryState: state);
      }
    });

    final container = GetIt.instance<ProviderContainer>();
    container.listen(finampSettingsProvider.keepScreenOnOption, (_, __) => setKeepScreenOn);
    container.listen(finampSettingsProvider.keepScreenOnWhilePluggedIn, (_, __) => setKeepScreenOn);
  }

  void setKeepScreenOn() {
    if (FinampSettingsHelper.finampSettings.keepScreenOnWhilePluggedIn && !_isPluggedIn) {
      _turnOff();
    } else {
      switch (FinampSettingsHelper.finampSettings.keepScreenOnOption) {
        case KeepScreenOnOption.disabled:
          if (_keepingScreenOn) _turnOff();
          break;
        case KeepScreenOnOption.alwaysOn:
          _turnOn();
          break;
        case KeepScreenOnOption.whilePlaying:
          if (_isPlaying) {
            _turnOn();
          } else {
            _turnOff();
          }
          break;
        case KeepScreenOnOption.whileLyrics:
          if (_isPlaying && _isLyricsShowing) {
            _turnOn();
          } else {
            _turnOff();
          }
          break;
      }
    }

    _keepScreenOnLogger.fine(
      "keepingScreenOn: $_keepingScreenOn | mainSetting: ${FinampSettingsHelper.finampSettings.keepScreenOnOption} | whilePluggedInSetting: ${FinampSettingsHelper.finampSettings.keepScreenOnWhilePluggedIn} | isPlaying: $_isPlaying | lyricsShowing: $_isLyricsShowing | isPluggedIn: $_isPluggedIn",
    );
  }

  void setCondition({bool? isPlaying, bool? isLyricsShowing, BatteryState? batteryState}) {
    if (isPlaying != null) _isPlaying = isPlaying;
    if (isLyricsShowing != null) _isLyricsShowing = isLyricsShowing;
    if (batteryState != null) {
      _keepScreenOnLogger.fine("reported battery state: $batteryState");
      switch (batteryState) {
        case BatteryState.charging:
        case BatteryState.connectedNotCharging:
        case BatteryState.full:
          _isPluggedIn = true;
          break;
        case BatteryState.discharging:
        case BatteryState.unknown:
          _isPluggedIn = false;
          break;
      }
    }

    setKeepScreenOn();
  }

  void _turnOn() {
    if (!_keepingScreenOn) {
      _keepingScreenOn = true;
      WakelockPlus.enable();
    }
  }

  void _turnOff() {
    if (_keepingScreenOn) {
      _keepingScreenOn = false;
      WakelockPlus.disable();
    }
  }
}

class KeepScreenOnObserver extends NavigatorObserver {
  final KeepScreenOnHelper keepScreenOnHelper = GetIt.instance<KeepScreenOnHelper>();

  static final _lyricsCheck = ModalRoute.withName(LyricsScreen.routeName);
  @override
  void didPush(Route route, Route? previousRoute) {
    // Just pushed to lyrics?
    if (_lyricsCheck(route)) {
      keepScreenOnHelper.setCondition(isLyricsShowing: true);
    }
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    // Just popped lyrics?
    if (_lyricsCheck(route)) {
      keepScreenOnHelper.setCondition(isLyricsShowing: false);
    }
    super.didPop(route, previousRoute);
  }
}
