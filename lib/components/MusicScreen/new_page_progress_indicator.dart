import 'package:flutter/material.dart';

class NewPageProgressIndicator extends StatelessWidget {
  const NewPageProgressIndicator({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.only(top: 16, bottom: 16),
    child: Center(child: CircularProgressIndicator.adaptive()),
  );
}
