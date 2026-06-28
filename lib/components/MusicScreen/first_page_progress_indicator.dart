import 'package:flutter/material.dart';

// Taken from https://github.com/EdsonBueno/infinite_scroll_pagination/blob/983763669fe7247682cd64f0f8f5d6c6f96d75d3/lib/src/ui/default_indicators/first_page_progress_indicator.dart
// Made CircularProgressIndicator adaptive

class FirstPageProgressIndicator extends StatelessWidget {
  const FirstPageProgressIndicator({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(32),
    child: Center(child: CircularProgressIndicator.adaptive()),
  );
}
