import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A native AirPlay route picker button.
///
/// Backed by the `flutter_to_airplay` plugin, which registers the native
/// `airplay_route_picker_view` platform view on both iOS and macOS. This widget
/// embeds it with a [UiKitView] on iOS and an [AppKitView] on macOS, sharing the
/// `flutter_to_airplay#<id>` method channel contract for the show/close picker
/// callbacks.
class AirPlayRoutePicker extends StatefulWidget {
  const AirPlayRoutePicker({
    super.key,
    this.tintColor,
    this.activeTintColor,
    this.backgroundColor,
    this.height = 44.0,
    this.width = 44.0,
    this.onShowPickerView,
    this.onClosePickerView,
  });

  final Color? tintColor;
  final Color? activeTintColor;
  final Color? backgroundColor;
  final double height;
  final double width;
  final VoidCallback? onShowPickerView;
  final VoidCallback? onClosePickerView;

  /// Whether the current platform has a native AirPlay picker implementation.
  static bool get isSupported => Platform.isIOS || Platform.isMacOS;

  static Map<String, dynamic> _colorToParams(Color color) => {
    'red': color.r,
    'green': color.g,
    'blue': color.b,
    'alpha': color.a,
  };

  Map<String, dynamic> _createParams() => <String, dynamic>{
    'class': 'AirplayRoutePicker',
    'prioritizesVideoDevices': false,
    if (tintColor != null) 'tintColor': _colorToParams(tintColor!),
    if (activeTintColor != null) 'activeTintColor': _colorToParams(activeTintColor!),
    if (backgroundColor != null) 'backgroundColor': _colorToParams(backgroundColor!),
  };

  @override
  State<AirPlayRoutePicker> createState() => _AirPlayRoutePickerState();
}

class _AirPlayRoutePickerState extends State<AirPlayRoutePicker> {
  static const _viewType = 'airplay_route_picker_view';
  MethodChannel? _methodChannel;

  @override
  void dispose() {
    _disposeChannel();
    super.dispose();
  }

  void _onPlatformViewCreated(int id) {
    _disposeChannel();
    _methodChannel = MethodChannel('flutter_to_airplay#$id')
      ..setMethodCallHandler(_onPlatformCall);
  }

  Future<dynamic> _onPlatformCall(MethodCall call) async {
    switch (call.method) {
      case 'onShowPickerView':
        widget.onShowPickerView?.call();
        break;
      case 'onClosePickerView':
        widget.onClosePickerView?.call();
        break;
    }
  }

  void _disposeChannel() {
    _methodChannel?.setMethodCallHandler(null);
    _methodChannel = null;
  }

  @override
  Widget build(BuildContext context) {
    if (!AirPlayRoutePicker.isSupported) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Platform.isMacOS
          ? AppKitView(
              viewType: _viewType,
              creationParamsCodec: const StandardMessageCodec(),
              creationParams: widget._createParams(),
              onPlatformViewCreated: _onPlatformViewCreated,
            )
          : UiKitView(
              viewType: _viewType,
              creationParamsCodec: const StandardMessageCodec(),
              creationParams: widget._createParams(),
              onPlatformViewCreated: _onPlatformViewCreated,
            ),
    );
  }
}
