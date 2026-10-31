import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:finamp/components/global_snackbar.dart';
import 'package:finamp/gen/assets.gen.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:finamp/services/music_player_background_task.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:logging/logging.dart';
import 'package:tray_manager/tray_manager.dart' as tray;
import 'package:window_manager/window_manager.dart';

/// System tray integration for Windows, Linux, and macOS.
///
/// On Linux, `tray_manager` (built on `nativeapi`) implements the
/// StatusNotifierItem and DBusMenu specifications directly over GDBus,
/// so it works on Wayland (KDE natively, GNOME with the AppIndicator
/// extension, wlroots compositors via e.g. waybar).
///
/// The tray icon is only shown when at least one of the tray settings is enabled
/// (or the app was started hidden with `--minimized`), so nothing changes for users
/// who don't opt in.
class TrayService with WindowListener {
  static final _logger = Logger("TrayService");

  static bool get isSupported => Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  /// Command-line flag to start with the window hidden in the tray.
  static const startMinimizedFlag = "--minimized";

  /// Whether we are running in a Linux Wayland session. Wayland doesn't tell clients when
  /// they get minimized, so "minimize to tray" can't work there.
  static bool get isWayland =>
      Platform.isLinux &&
      (Platform.environment["WAYLAND_DISPLAY"]?.isNotEmpty ?? false) &&
      Platform.environment["GDK_BACKEND"] != "x11";

  /// Whether the window should stay hidden on startup.
  static bool shouldStartHidden(List<String> args) =>
      isSupported && (args.contains(startMinimizedFlag) || FinampSettingsHelper.finampSettings.startMinimizedToTray);

  TrayService({required bool startedHidden}) : _forceTray = startedHidden, _windowVisible = !startedHidden;

  /// Keep the icon even if all settings are off, otherwise a window started with
  /// `--minimized` would be unreachable.
  final bool _forceTray;
  bool _windowVisible;
  bool _quitting = false;

  MediaItem? _currentItem;
  String? _lastMenuSignature;

  tray.TrayIcon? _trayIcon;
  tray.ListenerId? _trayListenerId;
  final Map<tray.MenuItemId, tray.ListenerId> _menuItemListeners = {};

  MusicPlayerBackgroundTask get _audioHandler => GetIt.instance<MusicPlayerBackgroundTask>();

  bool get _trayVisible => _trayIcon != null;

  void init() {
    if (!isSupported) return;

    windowManager.addListener(this);

    final container = GetIt.instance<ProviderContainer>();
    container.listen(finampSettingsProvider.closeToTray, (_, _) => unawaited(_applySettings()));
    container.listen(finampSettingsProvider.minimizeToTray, (_, _) => unawaited(_applySettings()));
    container.listen(finampSettingsProvider.startMinimizedToTray, (_, _) => unawaited(_applySettings()));
    // Menu labels are localized, rebuild them once the new locale is in effect.
    container.listen(finampSettingsProvider.locale, (_, _) => _refreshMenuAfterFrame());

    _audioHandler.mediaItem.distinct().listen((item) {
      _currentItem = item;
      _refreshMenu();
    });

    unawaited(_applySettings());
    // Localizations are only fully available once MaterialApp has been built.
    _refreshMenuAfterFrame();
  }

  bool get _trayWanted {
    final settings = FinampSettingsHelper.finampSettings;
    return _forceTray || settings.closeToTray || settings.minimizeToTray || settings.startMinimizedToTray;
  }

  Future<void> _applySettings() async {
    try {
      // Intercept the close button only when we want to hide instead of quitting.
      await windowManager.setPreventClose(FinampSettingsHelper.finampSettings.closeToTray);

      if (_trayWanted && !_trayVisible) {
        final trayIcon = tray.TrayIcon.create();
        if (trayIcon == null) {
          _logger.warning("Unable to create system tray icon");
          return;
        }
        final image = tray.ImageAsset.fromAsset(_iconPath);
        if (image != null) {
          trayIcon.icon = image;
        }
        trayIcon.setContextMenuTrigger(
          Platform.isMacOS ? tray.ContextMenuTrigger.clicked : tray.ContextMenuTrigger.rightClicked,
        );
        _trayListenerId = trayIcon.addListener(_onTrayIconEvent);
        trayIcon.setVisible(true);
        _trayIcon = trayIcon;
        _lastMenuSignature = null;
        _refreshMenu();
      } else if (!_trayWanted && _trayVisible) {
        _destroyTray();
      }
    } catch (e, stack) {
      _logger.severe("Failed to update tray icon", e, stack);
    }
  }

  void _destroyTray() {
    final trayIcon = _trayIcon;
    if (trayIcon == null) return;
    if (_trayListenerId != null) {
      trayIcon.removeListener(_trayListenerId!);
    }
    _trayListenerId = null;
    _disposeMenu();
    trayIcon.icon?.dispose();
    trayIcon.dispose();
    _trayIcon = null;
  }

  void _disposeMenu() {
    final menu = _trayIcon?.getContextMenu();
    if (menu == null) return;
    for (final item in menu.allItems) {
      final listenerId = _menuItemListeners.remove(item.id);
      if (listenerId != null) {
        item.removeListener(listenerId);
      }
      item.dispose();
    }
    _menuItemListeners.clear();
    menu.dispose();
  }

  String get _iconPath => Platform.isWindows ? Assets.tray.trayIconIco : Assets.tray.trayIconPng.path;

  String? get _nowPlayingText {
    final item = _currentItem;
    if (item == null) return null;
    final artist = item.artist;
    return (artist != null && artist.isNotEmpty) ? "$artist - ${item.title}" : item.title;
  }

  void _refreshMenuAfterFrame() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _lastMenuSignature = null;
      _refreshMenu();
    });
  }

  tray.MenuItem? _createItem(String label, {bool enabled = true, void Function()? onClick}) {
    final item = tray.MenuItem.createWithLabelAndType(label, tray.MenuItemType.normal);
    if (item == null) return null;
    item.isEnabled = enabled;
    if (onClick != null) {
      _menuItemListeners[item.id] = item.addListener((event) {
        if (event is tray.MenuItemClickedEvent) {
          onClick();
        }
      });
    }
    return item;
  }

  void _refreshMenu() {
    final trayIcon = _trayIcon;
    if (trayIcon == null) return;
    final l10n = GlobalSnackbar.requireL10n;
    final nowPlaying = _nowPlayingText;
    final hasTrack = _currentItem != null;

    // Avoid needlessly rebuilding the native menu.
    final signature = "${l10n.localeName}|$_windowVisible|$nowPlaying";
    if (signature == _lastMenuSignature) return;
    _lastMenuSignature = signature;

    try {
      final menu = tray.Menu.create();
      if (menu == null) return;

      _disposeMenu();

      menu.addItem(_createItem(nowPlaying ?? l10n.trayNothingPlaying, enabled: false));
      menu.addSeparator();
      menu.addItem(
        _createItem(
          _windowVisible ? l10n.trayHideWindow : l10n.trayShowWindow,
          onClick: () => unawaited(toggleWindow()),
        ),
      );
      menu.addSeparator();
      menu.addItem(
        _createItem(
          l10n.togglePlaybackButtonTooltip,
          enabled: hasTrack,
          onClick: () => unawaited(_audioHandler.togglePlayback()),
        ),
      );
      menu.addItem(
        _createItem(
          l10n.skipToPreviousTrackButtonTooltip,
          enabled: hasTrack,
          onClick: () => unawaited(_audioHandler.skipToPrevious()),
        ),
      );
      menu.addItem(
        _createItem(
          l10n.skipToNextTrackButtonTooltip,
          enabled: hasTrack,
          onClick: () => unawaited(_audioHandler.skipToNext()),
        ),
      );
      menu.addSeparator();
      menu.addItem(_createItem(l10n.trayQuit, onClick: () => unawaited(quit())));

      trayIcon.setContextMenu(menu);
      trayIcon.setTooltip(nowPlaying != null ? l10n.trayTooltipPlaying(nowPlaying) : l10n.finamp);
    } catch (e, stack) {
      _logger.warning("Failed to update tray menu", e, stack);
    }
  }

  Future<void> hideWindow() async {
    if (!_trayVisible) {
      throw StateError("Cannot hide window when tray icon is not visible");
    }
    await windowManager.hide();
    _setWindowVisible(false);
  }

  Future<void> showWindow() async {
    await windowManager.show();
    if (await windowManager.isMinimized()) {
      await windowManager.restore();
    }
    await windowManager.focus();
    _setWindowVisible(true);
  }

  Future<void> toggleWindow() async {
    if (await windowManager.isVisible()) {
      await hideWindow();
    } else {
      await showWindow();
    }
  }

  /// Fully quits the app, bypassing close-to-tray.
  Future<void> quit() async {
    if (_quitting) return;
    _quitting = true;
    _logger.info("Quitting from tray");
    try {
      _destroyTray();
    } catch (_) {}
    // Let the regular close path run (which also disposes the player).
    // Don't use windowManager.destroy(), it freezes Windows release builds.
    await windowManager.setPreventClose(false);
    await windowManager.close();
  }

  void _setWindowVisible(bool visible) {
    if (_windowVisible == visible) return;
    _windowVisible = visible;
    _refreshMenu();
  }

  void _onTrayIconEvent(tray.TrayIconEvent event) {
    switch (event) {
      case tray.TrayIconClickedEvent():
        // On macOS, clicking a status bar item opens the menu; on Windows and Linux
        // (StatusNotifierItem Activate), a primary click toggles the main window.
        if (!Platform.isMacOS) {
          unawaited(toggleWindow());
        }
      case tray.TrayIconDoubleClickedEvent():
        // GNOME's AppIndicator extension emits Activate on double-click.
        if (Platform.isLinux) {
          unawaited(toggleWindow());
        }
      case tray.TrayIconRightClickedEvent():
        break;
    }
  }

  // ---- WindowListener ----

  @override
  void onWindowClose() {
    if (_quitting || !FinampSettingsHelper.finampSettings.closeToTray) return;
    unawaited(hideWindow());
  }

  @override
  void onWindowMinimize() {
    if (!FinampSettingsHelper.finampSettings.minimizeToTray) return;
    unawaited(hideWindow());
  }

  @override
  void onWindowEvent(String eventName) {
    // Keep the Show/Hide entry accurate when the window is shown by other means,
    // e.g. by launching Finamp again.
    if (eventName == "show" || eventName == "focus" || eventName == "restore") {
      _setWindowVisible(true);
    } else if (eventName == "hide") {
      _setWindowVisible(false);
    }
  }
}
