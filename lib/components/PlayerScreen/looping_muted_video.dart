import 'dart:async';

import 'package:finamp/services/animated_media_proxy.dart';
import 'package:finamp/services/animated_music_service.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:visibility_detector/visibility_detector.dart';

final _loopingVideoLogger = Logger("LoopingMutedVideo");

class LoopingMutedVideo extends StatefulWidget {
  const LoopingMutedVideo({
    super.key,
    required this.source,
    this.fit = BoxFit.cover,
    this.coverClipBorderRadius,
    this.onFirstFrame,
    this.fade = true,
  });

  final AnimatedPlaybackSource source;
  final BoxFit fit;
  final BorderRadius? coverClipBorderRadius;
  final VoidCallback? onFirstFrame;
  final bool fade;

  @override
  State<LoopingMutedVideo> createState() => _LoopingMutedVideoState();
}

class _LoopingMutedVideoState extends State<LoopingMutedVideo> with WidgetsBindingObserver {
  final _visibilityKey = UniqueKey();
  int _session = 0;
  bool _ready = false;
  bool _visible = true;
  bool _sawVisible = false;
  bool _showPreview = false;
  Size? _imageSize;
  String? _proxyId;
  Player? _player;
  VideoController? _videoController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_open());
  }

  @override
  void didUpdateWidget(LoopingMutedVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source) {
      unawaited(_reopen());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) {
      return;
    }
    if (state == AppLifecycleState.resumed) {
      unawaited(_setPlaying(_visible));
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      unawaited(_setPlaying(false));
    }
  }

  Future<void> _reopen() async {
    await _disposePlayer();
    if (!mounted) {
      return;
    }
    setState(() {
      _ready = false;
      _showPreview = false;
      _imageSize = null;
    });
    await _open();
  }

  Future<void> _open() async {
    if (widget.source.isImage || !widget.source.isPlayable) {
      return;
    }
    final session = _session;
    try {
      await _openPlayer(session);
    } catch (e, stack) {
      if (session != _session) {
        return;
      }
      _loopingVideoLogger.warning(
        "Failed to open animated video (${widget.source.fileName ?? widget.source.kind.name}): $e",
        e,
        stack,
      );
      await _disposePlayer();
      if (mounted && widget.source.previewUrl != null) {
        setState(() => _showPreview = true);
      }
    }
  }

  /// Any [_disposePlayer] call bumps [_session] and disposes the player and
  /// proxy registered here, so stale sessions only need to bail out.
  Future<void> _openPlayer(int session) async {
    MediaKit.ensureInitialized();
    final Media media;
    final file = widget.source.file;
    final url = widget.source.url;
    if (file != null) {
      media = Media(file.path);
    } else if (url != null) {
      final proxied = await AnimatedMediaProxy.instance.register(
        upstream: url,
        headers: widget.source.headers ?? const {},
        fileName: widget.source.fileName ?? 'video.mp4',
      );
      if (!mounted || session != _session) {
        AnimatedMediaProxy.instance.unregister(proxied.id);
        return;
      }
      _proxyId = proxied.id;
      media = Media(proxied.uri.toString());
    } else {
      return;
    }

    final player = Player(configuration: const PlayerConfiguration(muted: true));
    final videoController = VideoController(player);
    _player = player;
    _videoController = videoController;

    await player.setPlaylistMode(PlaylistMode.loop);
    await player.setVolume(0);
    await player.open(media, play: _visible);
    await videoController.waitUntilFirstFrameRendered;
    if (!mounted || session != _session) {
      return;
    }
    setState(() => _ready = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _player == player) {
        widget.onFirstFrame?.call();
      }
    });
  }

  Future<void> _setPlaying(bool playing) async {
    if (widget.source.isImage || _showPreview) {
      return;
    }
    final player = _player;
    if (player == null) {
      return;
    }
    try {
      if (playing) {
        await player.play();
      } else {
        await player.pause();
      }
    } catch (e, stack) {
      _loopingVideoLogger.finest("Failed to update animated video playback", e, stack);
    }
  }

  Future<void> _disposePlayer() async {
    _session++;
    final proxyId = _proxyId;
    _proxyId = null;
    if (proxyId != null) {
      AnimatedMediaProxy.instance.unregister(proxyId);
    }
    _videoController = null;
    final player = _player;
    _player = null;
    await player?.dispose();
  }

  void _onImageReady(Size size) {
    if (!mounted || (_ready && _imageSize == size)) {
      return;
    }
    final wasReady = _ready;
    setState(() {
      _ready = true;
      _imageSize = size;
    });
    if (!wasReady) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.onFirstFrame?.call();
        }
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_disposePlayer());
    super.dispose();
  }

  ImageProvider? _imageProvider() {
    final source = widget.source;
    if (source.isImage) {
      final file = source.file;
      if (file != null) {
        return FileImage(file);
      }
      final url = source.url;
      return url == null ? null : NetworkImage(url.toString(), headers: source.headers);
    }
    final preview = source.previewUrl;
    if (_showPreview && preview != null) {
      return NetworkImage(preview.toString(), headers: source.headers);
    }
    return null;
  }

  Widget _buildVideo(VideoController controller) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        if (!width.isFinite || !height.isFinite || width <= 0 || height <= 0) {
          return const SizedBox.shrink();
        }
        return Video(
          controller: controller,
          width: width,
          height: height,
          fit: widget.fit,
          fill: Colors.transparent,
          wakelock: false,
          pauseUponEnteringBackgroundMode: false,
          controls: (_) => const SizedBox.shrink(),
        );
      },
    );
  }

  Widget _clip(Widget media, Size? mediaSize) {
    final borderRadius = widget.coverClipBorderRadius;
    if (borderRadius == null) {
      return media;
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final bounds = constraints.biggest;
        final fitted = mediaSize == null || mediaSize.isEmpty || !bounds.isFinite
            ? bounds
            : applyBoxFit(widget.fit, mediaSize, bounds).destination;
        return Center(
          child: SizedBox.fromSize(
            size: fitted,
            child: ClipRRect(borderRadius: borderRadius, clipBehavior: Clip.antiAlias, child: media),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final Widget media;
    final image = _imageProvider();
    final controller = _videoController;
    if (image != null) {
      media = _clip(_ImageLoop(image: image, fit: widget.fit, onReady: _onImageReady), _imageSize);
    } else if (controller != null && _ready) {
      media = ValueListenableBuilder<Rect?>(
        valueListenable: controller.rect,
        builder: (context, rect, child) => _clip(child!, rect?.size),
        child: _buildVideo(controller),
      );
    } else {
      media = const SizedBox.shrink();
    }

    return VisibilityDetector(
      key: _visibilityKey,
      onVisibilityChanged: (info) {
        if (!mounted) {
          return;
        }
        final visible = info.visibleFraction > 0.01;
        if (visible) {
          _sawVisible = true;
        } else if (!_sawVisible || !_ready) {
          return;
        }
        if (visible == _visible) {
          return;
        }
        _visible = visible;
        unawaited(_setPlaying(_visible));
      },
      child: IgnorePointer(
        child: AnimatedOpacity(
          opacity: _ready ? 1 : 0,
          duration: widget.fade ? animatedMusicFadeDurationOf(context) : Duration.zero,
          curve: animatedMusicFadeCurve,
          child: media,
        ),
      ),
    );
  }
}

class _ImageLoop extends StatefulWidget {
  const _ImageLoop({required this.image, required this.fit, required this.onReady});

  final ImageProvider image;
  final BoxFit fit;
  final ValueChanged<Size> onReady;

  @override
  State<_ImageLoop> createState() => _ImageLoopState();
}

class _ImageLoopState extends State<_ImageLoop> {
  ImageStream? _stream;
  late final _listener = ImageStreamListener(
    _onImage,
    onError: (e, stack) => _loopingVideoLogger.fine("Failed to load animated image", e, stack),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(_ImageLoop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.image != widget.image) {
      _resolve();
    }
  }

  void _resolve() {
    final stream = widget.image.resolve(createLocalImageConfiguration(context));
    if (stream.key == _stream?.key) {
      return;
    }
    _stream?.removeListener(_listener);
    _stream = stream..addListener(_listener);
  }

  void _onImage(ImageInfo info, bool _) {
    final size = Size(info.image.width.toDouble(), info.image.height.toDouble());
    info.dispose();
    _stream?.removeListener(_listener);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.onReady(size);
      }
    });
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Image(image: widget.image, fit: widget.fit, gaplessPlayback: true, excludeFromSemantics: true);
  }
}
