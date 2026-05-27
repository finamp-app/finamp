import 'package:finamp/color_schemes.g.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:finamp/services/widget_bindings_observer_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';

class FinampIcon extends ConsumerWidget {
  final double height;
  final double width;
  final Color? overrideColor;
  const FinampIcon(this.width, this.height, {this.overrideColor, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final icon = SvgPicture.asset("images/finamp_cropped.svg", width: width, height: height);
    final useMonochromeIcon = ref.watch(finampSettingsProvider.useMonochromeIcon);
    if (!useMonochromeIcon && overrideColor == null) return icon;

    final color = overrideColor ?? Theme.of(context).colorScheme.primary;

    // Basically this uses the icon as a mask on top of a solid color
    return ColorFiltered(colorFilter: ColorFilter.mode(color, BlendMode.srcIn), child: icon);
  }
}
