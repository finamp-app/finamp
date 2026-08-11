import 'package:flutter/material.dart';
import 'package:finamp/l10n/app_localizations.dart';

import '../screens/external_search_screen.dart';

/// AppBar action that opens [ExternalSearchScreen].
///
/// Always visible so the user can open External Search and connect a Music
/// Finder server from there (or via Settings).
class ExternalSearchButton extends StatelessWidget {
  const ExternalSearchButton({Key? key}) : super(key: key);

  static const assetPath = 'images/external_search_icon.png';

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: ExternalSearchGlyph(size: 24),
      tooltip: AppLocalizations.of(context)!.externalSearch,
      onPressed: () => Navigator.of(context)
          .pushNamed(ExternalSearchScreen.routeName),
    );
  }
}

/// Monochrome skull asset tinted with the ambient [IconTheme] color.
///
/// The PNG is black ink on transparent (white baked out). [BlendMode.srcIn]
/// paints that ink with the theme icon color — black/dark in light mode,
/// white/light in dark mode.
class ExternalSearchGlyph extends StatelessWidget {
  const ExternalSearchGlyph({Key? key, this.size = 24}) : super(key: key);

  final double size;

  @override
  Widget build(BuildContext context) {
    final color = IconTheme.of(context).color ??
        Theme.of(context).iconTheme.color ??
        Theme.of(context).colorScheme.onSurface;

    return ColorFiltered(
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      child: Image.asset(
        ExternalSearchButton.assetPath,
        width: size,
        height: size,
        filterQuality: FilterQuality.medium,
      ),
    );
  }
}

/// Drawer leading icon matching [ExternalSearchButton].
class ExternalSearchLeadingIcon extends StatelessWidget {
  const ExternalSearchLeadingIcon({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const ExternalSearchGlyph(size: 24);
  }
}
