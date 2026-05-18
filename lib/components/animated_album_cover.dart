import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

class AnimatedAlbumCover extends StatefulWidget {
  const AnimatedAlbumCover({super.key, required this.animatedCoverUri, required this.borderRadius, this.decoration});

  final String animatedCoverUri;
  final BorderRadius borderRadius;
  final BoxDecoration? decoration;

  @override
  State<AnimatedAlbumCover> createState() => _AnimatedAlbumCoverState();
}

class _AnimatedAlbumCoverState extends State<AnimatedAlbumCover> {
  late final Player _player;
  late final VideoController _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      _player = Player();
      _controller = VideoController(_player);

      // Configure player for seamless looping
      await _player.setPlaylistMode(PlaylistMode.loop);
      await _player.setVolume(0.0); // Mute the video

      // Load the media
      await _player.open(Media(widget.animatedCoverUri));

      print(widget.animatedCoverUri);

      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      // If video initialization fails, we'll show the fallback
      print(e);
      setState(() {
        _isInitialized = false;
      });
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: widget.decoration,
      child: ClipRRect(
        borderRadius: widget.borderRadius,
        child: Video(controller: _controller, controls: null, fit: BoxFit.cover, fill: Colors.transparent),
      ),
    );
  }
}
