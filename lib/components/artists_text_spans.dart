import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../models/jellyfin_models.dart';
import '../../services/jellyfin_api_helper.dart';
import '../screens/artist_screen.dart';
import '../services/downloads_service.dart';

List<TextSpan> buildArtistsTextSpans(BaseItemDto item, Color? textColour, BuildContext context, bool popRoutes) {
  final jellyfinApiHelper = GetIt.instance<JellyfinApiHelper>();
  final isarDownloader = GetIt.instance<DownloadsService>();
  List<TextSpan> separatedArtistTextSpans = [];
  final navigator = Navigator.of(context);

  List<NameIdPair>? artists = item.type == "MusicAlbum" ? item.albumArtists : item.artistItems;

  if (artists?.isEmpty ?? true) {
    separatedArtistTextSpans = [
      TextSpan(
        text: "Unknown Artist",
        style: TextStyle(color: textColour),
      ),
    ];
  } else {
    artists
        ?.map(
          (e) => TextSpan(
            text: e.name,
            style: TextStyle(color: textColour),
            recognizer: TapGestureRecognizer()
              ..onTap = () {
                Future<BaseItemDto>? artistFuture = FinampSettingsHelper.finampSettings.isOffline
                    ? isarDownloader.getCollectionInfo(id: e.id).then((value) => value!.baseItem!)
                    : jellyfinApiHelper.getItemById(e.id);

                artistFuture.then(
                  (artist) => popRoutes
                      ? navigator.popAndPushNamed(ArtistScreen.routeName, arguments: artist)
                      : navigator.pushNamed(ArtistScreen.routeName, arguments: artist),
                );
              },
          ),
        )
        .forEach((artistTextSpan) {
          separatedArtistTextSpans.add(artistTextSpan);
          separatedArtistTextSpans.add(
            TextSpan(
              text: ", ",
              style: TextStyle(color: textColour),
            ),
          );
        });
    separatedArtistTextSpans.removeLast();
  }
  return separatedArtistTextSpans;
}
