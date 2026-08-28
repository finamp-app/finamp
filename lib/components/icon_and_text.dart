import 'package:flutter/material.dart';

class IconAndText extends StatelessWidget {
  const IconAndText({super.key, required this.iconData, required this.textSpan, this.iconColor});

  final IconData iconData;
  final TextSpan textSpan;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final effectiveIconColor =
        iconColor ??
        Theme.of(context).iconTheme.color?.withOpacity(Theme.brightnessOf(context) == Brightness.light ? 0.38 : 0.5);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            iconData,
            // Inactive icons have an opacity of 50% with dark theme and 38%
            // with bright theme
            // https://material.io/design/iconography/system-icons.html#color
            color: effectiveIconColor,
          ),
          const Padding(padding: EdgeInsets.symmetric(horizontal: 2)),
          // RichText blocks theming.  Text.rich does not.
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Text.rich(textSpan, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}
