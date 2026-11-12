import 'package:finamp/components/PlayerScreen/looping_muted_video.dart';
import 'package:finamp/services/animated_music_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AnimatedCoverOverlay extends ConsumerWidget {
  const AnimatedCoverOverlay({super.key, required this.borderRadius});

  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return const SizedBox.shrink();
    }
    final source = ref.watch(currentAnimatedCoverSourceProvider);
    if (source == null) {
      return const SizedBox.shrink();
    }
    return Positioned.fill(
      child: LoopingMutedVideo(
        key: ValueKey(source.id),
        source: source,
        fit: BoxFit.contain,
        coverClipBorderRadius: borderRadius,
      ),
    );
  }
}
