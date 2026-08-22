import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../models/jellyfin_models.dart';
import '../../services/jellyfin_api_helper.dart';
import '../screens/artist_screen.dart';

List<TextSpan> getArtistsTextSpans(BaseItemDto item, BuildContext context, bool popRoutes) {
  final jellyfinApiHelper = GetIt.instance<JellyfinApiHelper>();
  List<TextSpan> separatedArtistTextSpans = [];
  final navigator = Navigator.of(context);

  List<NameIdPair>? artists = item.type == "MusicAlbum" ? item.albumArtists : item.artistItems;

  if (artists?.isEmpty ?? true) {
    separatedArtistTextSpans = [TextSpan(text: "Unknown Artist", style: Theme.of(context).textTheme.bodyMedium)];
  } else {
    artists
        ?.map(
          (e) => TextSpan(
            text: e.name,
            style: Theme.of(context).textTheme.bodyMedium,
            recognizer: TapGestureRecognizer()
              ..onTap = () {
                // Offline artists aren't implemented yet so we return if offline
                if (FinampSettingsHelper.finampSettings.isOffline) return;

                jellyfinApiHelper
                    .getItemById(e.id)
                    .then(
                      (artist) => popRoutes
                          ? navigator.popAndPushNamed(ArtistScreen.routeName, arguments: artist)
                          : navigator.pushNamed(ArtistScreen.routeName, arguments: artist),
                    );
              },
          ),
        )
        .forEach((artistTextSpan) {
          separatedArtistTextSpans.add(artistTextSpan);
          separatedArtistTextSpans.add(TextSpan(text: ", ", style: Theme.of(context).textTheme.bodyMedium));
        });
    separatedArtistTextSpans.removeLast();
  }
  return separatedArtistTextSpans;
}
