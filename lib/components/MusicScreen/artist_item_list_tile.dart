import 'package:finamp/components/favorite_button.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../models/finamp_models.dart';
import '../../models/jellyfin_models.dart';
import '../../services/generate_subtitle.dart';
import '../../services/jellyfin_api_helper.dart';
import '../AlbumScreen/downloaded_indicator.dart';
import '../album_image.dart';

/// ListTile content for ArtistItem. You probably shouldn't use this widget
/// directly, use ArtistItem instead.
class ArtistItemListTile extends StatelessWidget {
  const ArtistItemListTile({super.key, required this.item, this.parentType, this.onTap});

  final BaseItemDto item;
  final ContentType? parentType;
  final void Function()? onTap;

  @override
  Widget build(BuildContext context) {
    final jellyfinApiHelper = GetIt.instance<JellyfinApiHelper>();
    final subtitle = generateSubtitle(item: item, parentType: parentType, context: context);

    return ListTile(
      // This widget is used on the add to playlist screen, so we allow a custom
      // onTap to be passed as an argument.
      onTap: onTap,
      leading: AlbumImage(item: item, borderRadius: BorderRadius.circular(9999)),
      title: Text(item.name ?? AppLocalizations.of(context)!.unknownName, overflow: TextOverflow.ellipsis),
      subtitle: Text.rich(
        TextSpan(
          children: [
            WidgetSpan(
              child: Transform.translate(
                offset: const Offset(-3, 0),
                child: DownloadedIndicator(
                  item: DownloadStub.fromItem(item: item, type: DownloadItemType.collection),
                  size: Theme.of(context).textTheme.bodyMedium!.fontSize! + 3,
                ),
              ),
              alignment: PlaceholderAlignment.top,
            ),
            if (subtitle != null)
              TextSpan(
                text: subtitle,
                style: TextStyle(color: Theme.of(context).disabledColor),
              ),
          ],
        ),
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if ((item.type == "MusicArtist" ? jellyfinApiHelper.selectedMixArtists : jellyfinApiHelper.selectedMixAlbums)
              .contains(item))
            const Icon(Icons.explore),
          FavoriteButton(item: item, onlyIfFav: true),
        ],
      ),
    );
  }
}
