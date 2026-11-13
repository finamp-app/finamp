import 'package:finamp/components/PlayerScreen/looping_muted_video.dart';
import 'package:finamp/services/animated_music_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class VerticalBackgroundVideo extends ConsumerStatefulWidget {
  const VerticalBackgroundVideo({super.key});

  @override
  ConsumerState<VerticalBackgroundVideo> createState() => _VerticalBackgroundVideoState();
}

class _BackgroundLayer {
  _BackgroundLayer(this.source);

  final AnimatedPlaybackSource source;
  bool ready = false;
  bool outgoing = false;
}

class _VerticalBackgroundVideoState extends ConsumerState<VerticalBackgroundVideo> {
  final List<_BackgroundLayer> _layers = [];

  bool _handleSource(AnimatedPlaybackSource? source) {
    if (source == null) {
      final before = _layers.length;
      _layers.removeWhere((layer) => !layer.ready);
      var changed = _layers.length != before;
      for (final layer in _layers) {
        if (!layer.outgoing) {
          layer.outgoing = true;
          changed = true;
        }
      }
      return changed;
    }
    if (_layers.any((layer) => layer.source == source && !layer.outgoing)) {
      return false;
    }
    _layers.removeWhere((layer) => !layer.ready || layer.outgoing);
    _layers.add(_BackgroundLayer(source));
    return true;
  }

  void _onLayerReady(_BackgroundLayer layer) {
    if (!mounted || layer.outgoing || layer.ready) {
      return;
    }
    setState(() {
      layer.ready = true;
      for (final other in _layers) {
        if (!identical(other, layer)) {
          other.outgoing = true;
        }
      }
    });
    ref.read(verticalBackgroundReadyProvider.notifier).markReady();
  }

  void _removeLayer(_BackgroundLayer layer) {
    if (!mounted || !_layers.contains(layer)) {
      return;
    }
    setState(() {
      _layers.remove(layer);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return const SizedBox.shrink();
    }

    final source = ref.watch(currentVerticalBackgroundSourceProvider);
    ref.listen(currentVerticalBackgroundSourceProvider, (previous, next) {
      if (_handleSource(next)) {
        setState(() {});
      }
    });
    if (_layers.isEmpty && source != null) {
      _handleSource(source);
    }

    final duration = animatedMusicFadeDurationOf(context);
    final showing = _layers.any((layer) => layer.ready && !layer.outgoing);

    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          fit: StackFit.expand,
          children: [
            for (final layer in List<_BackgroundLayer>.of(_layers))
              AnimatedOpacity(
                key: ObjectKey(layer),
                opacity: layer.ready && !layer.outgoing ? 1 : 0,
                duration: duration,
                curve: animatedMusicFadeCurve,
                onEnd: () {
                  if (layer.outgoing) {
                    _removeLayer(layer);
                  }
                },
                child: LoopingMutedVideo(
                  source: layer.source,
                  fit: BoxFit.cover,
                  fade: false,
                  onFirstFrame: () => _onLayerReady(layer),
                ),
              ),
            AnimatedOpacity(
              opacity: showing ? 1 : 0,
              duration: duration,
              curve: animatedMusicFadeCurve,
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x73000000), Colors.transparent, Colors.transparent, Color(0x9E000000)],
                    stops: [0.0, 0.18, 0.55, 1.0],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
