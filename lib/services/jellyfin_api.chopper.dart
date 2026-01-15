// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'jellyfin_api.dart';

// **************************************************************************
// ChopperGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: type=lint
final class _$JellyfinApi extends JellyfinApi {
  _$JellyfinApi([ChopperClient? client]) {
    if (client == null) return;
    this.client = client;
  }

  @override
  final Type definitionType = JellyfinApi;

  @override
  Future<dynamic> getPublicServerInfo() async {
    final Uri $url = Uri.parse('/System/Info/Public');
    final Request $request = Request('GET', $url, client.baseUrl);
    final Response $response = await client.send<dynamic, dynamic>(
      $request,
      requestConverter: JsonConverter.requestFactory,
      responseConverter: JsonConverter.responseFactory,
    );
    return $response.bodyOrThrow;
  }

  @override
  Future<dynamic> getPublicUsers() async {
    final Uri $url = Uri.parse('/Users/Public');
    final Request $request = Request('GET', $url, client.baseUrl);
    final Response $response = await client.send<dynamic, dynamic>(
      $request,
      requestConverter: JsonConverter.requestFactory,
      responseConverter: JsonConverter.responseFactory,
    );
    return $response.bodyOrThrow;
  }

  @override
  Future<dynamic> getQuickConnectState() async {
    final Uri $url = Uri.parse('/QuickConnect/Enabled');
    final Request $request = Request('GET', $url, client.baseUrl);
    final Response $response = await client.send<dynamic, dynamic>(
      $request,
      requestConverter: JsonConverter.requestFactory,
      responseConverter: JsonConverter.responseFactory,
    );
    return $response.bodyOrThrow;
  }

  @override
  Future<dynamic> initiateQuickConnect() async {
    final Uri $url = Uri.parse('/QuickConnect/Initiate');
    final Request $request = Request('GET', $url, client.baseUrl);
    final Response $response = await client.send<dynamic, dynamic>(
      $request,
      requestConverter: JsonConverter.requestFactory,
      responseConverter: JsonConverter.responseFactory,
    );
    return $response.bodyOrThrow;
  }

  @override
  Future<dynamic> updateQuickConnect({required String secret}) async {
    final Uri $url = Uri.parse('/QuickConnect/Connect');
    final Map<String, dynamic> $params = <String, dynamic>{'Secret': secret};
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
      parameters: $params,
    );
    final Response $response = await client.send<dynamic, dynamic>(
      $request,
      requestConverter: JsonConverter.requestFactory,
      responseConverter: JsonConverter.responseFactory,
    );
    return $response.bodyOrThrow;
  }

  @override
  Future<Response<dynamic>> authorizeQuickConnect({
    required String code,
    String? userId,
  }) {
    final Uri $url = Uri.parse('/QuickConnect/Authorize');
    final Map<String, dynamic> $params = <String, dynamic>{
      'code': code,
      'userId': userId,
    };
    final Request $request = Request(
      'POST',
      $url,
      client.baseUrl,
      parameters: $params,
    );
    return client.send<dynamic, dynamic>(
      $request,
      requestConverter: JsonConverter.requestFactory,
      responseConverter: JsonConverter.responseFactory,
    );
  }

  @override
  Future<dynamic> authenticateWithQuickConnect(
    Map<String, String> quickConnectInfo,
  ) async {
    final Uri $url = Uri.parse('/Users/AuthenticateWithQuickConnect');
    final $body = quickConnectInfo;
    final Request $request = Request('POST', $url, client.baseUrl, body: $body);
    final Response $response = await client.send<dynamic, dynamic>(
      $request,
      requestConverter: JsonConverter.requestFactory,
      responseConverter: JsonConverter.responseFactory,
    );
    return $response.bodyOrThrow;
  }

  @override
  Future<dynamic> authenticateViaName(
    Map<String, String> usernameAndPassword,
  ) async {
    final Uri $url = Uri.parse('/Users/AuthenticateByName');
    final $body = usernameAndPassword;
    final Request $request = Request('POST', $url, client.baseUrl, body: $body);
    final Response $response = await client.send<dynamic, dynamic>(
      $request,
      requestConverter: JsonConverter.requestFactory,
      responseConverter: JsonConverter.responseFactory,
    );
    return $response.bodyOrThrow;
  }

  @override
  Future<dynamic> getAlbumPrimaryImage({
    required BaseItemId id,
    String format = "webp",
  }) async {
    final Uri $url = Uri.parse('/Items/${id}/Images/Primary');
    final Map<String, dynamic> $params = <String, dynamic>{'format': format};
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
      parameters: $params,
    );
    final Response $response = await client.send<dynamic, dynamic>(
      $request,
      requestConverter: JsonConverter.requestFactory,
      responseConverter: JsonConverter.responseFactory,
    );
    return $response.bodyOrThrow;
  }

  @override
  Future<Response<dynamic>> setItemPrimaryImage({
    String contentType = "image/jpeg",
    required BaseItemId itemId,
    required String base64Image,
  }) {
    final Uri $url = Uri.parse('/Items/${itemId}/Images/Primary');
    final Map<String, String> $headers = {'Content-Type': contentType};
    final $body = base64Image;
    final Request $request = Request(
      'POST',
      $url,
      client.baseUrl,
      body: $body,
      headers: $headers,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<dynamic> getUser() async {
    final Uri $url = Uri.parse('/Users/Me');
    final Request $request = Request('GET', $url, client.baseUrl);
    final Response $response = await client.send<dynamic, dynamic>(
      $request,
      requestConverter: JsonConverter.requestFactory,
      responseConverter: JsonConverter.responseFactory,
    );
    return $response.bodyOrThrow;
  }

  @override
  Future<dynamic> getViews(String id) async {
    final Uri $url = Uri.parse('/Users/${id}/Views');
    final Request $request = Request('GET', $url, client.baseUrl);
    final Response $response = await client.send<dynamic, dynamic>(
      $request,
      requestConverter: JsonConverter.requestFactory,
      responseConverter: JsonConverter.responseFactory,
    );
    return $response.bodyOrThrow;
  }

  @override
  Future<dynamic> deleteItem(BaseItemId id) async {
    final Uri $url = Uri.parse('/Items/${id}');
    final Request $request = Request('DELETE', $url, client.baseUrl);
    final Response $response = await client.send<dynamic, dynamic>(
      $request,
      requestConverter: JsonConverter.requestFactory,
      responseConverter: JsonConverter.responseFactory,
    );
    return $response.bodyOrThrow;
  }

  @override
  Future<dynamic> getItems({
    required String userId,
    String? includeItemTypes,
    BaseItemId? parentId,
    String? albumArtistIds,
    String? artistIds,
    String? contributingArtistIds,
    String? albumIds,
    String? genreIds,
    String? ids,
    bool? recursive,
    String? sortBy,
    String? sortOrder,
    String? fields = defaultFields,
    String? searchTerm,
    String? filters,
    bool? isFavorite,
    String? excludeItemIds,
    int? startIndex,
    int? limit,
    bool? collapseMultiDiscAlbums,
    String? nameStartsWith,
    String? nameStartsWithOrGreater,
    String? nameLessThan,
  }) async {
    final Uri $url = Uri.parse('/Users/${userId}/Items');
    final Map<String, dynamic> $params = <String, dynamic>{
      'IncludeItemTypes': includeItemTypes,
      'ParentId': parentId,
      'AlbumArtistIds': albumArtistIds,
      'ArtistIds': artistIds,
      'contributingArtistIds': contributingArtistIds,
      'AlbumIds': albumIds,
      'GenreIds': genreIds,
      'ids': ids,
      'Recursive': recursive,
      'SortBy': sortBy,
      'SortOrder': sortOrder,
      'Fields': fields,
      'SearchTerm': searchTerm,
      'Filters': filters,
      'isFavorite': isFavorite,
      'excludeItemIds': excludeItemIds,
      'StartIndex': startIndex,
      'Limit': limit,
      'CollapseBoxSetItems': collapseMultiDiscAlbums,
      'NameStartsWith': nameStartsWith,
      'NameStartsWithOrGreater': nameStartsWithOrGreater,
      'NameLessThan': nameLessThan,
    };
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
      parameters: $params,
    );
    final Response $response = await client.send<dynamic, dynamic>(
      $request,
      requestConverter: JsonConverter.requestFactory,
      responseConverter: JsonConverter.responseFactory,
    );
    return $response.bodyOrThrow;
  }

  @override
  Future<dynamic> getLatestItems({
    required String userId,
    String? includeItemTypes,
    BaseItemId? parentId,
    String? fields = defaultFields,
    int? limit,
    bool? groupItems,
  }) async {
    final Uri $url = Uri.parse('/Users/${userId}/Items/Latest');
    final Map<String, dynamic> $params = <String, dynamic>{
      'IncludeItemTypes': includeItemTypes,
      'ParentId': parentId,
      'Fields': fields,
      'Limit': limit,
      'GroupItems': groupItems,
    };
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
      parameters: $params,
    );
    final Response $response = await client.send<dynamic, dynamic>(
      $request,
      requestConverter: JsonConverter.requestFactory,
      responseConverter: JsonConverter.responseFactory,
    );
    return $response.bodyOrThrow;
  }

  @override
  Future<dynamic> getInstantMix({
    required BaseItemId id,
    required String userId,
    required int limit,
  }) async {
    final Uri $url = Uri.parse('/Items/${id}/InstantMix');
    final Map<String, dynamic> $params = <String, dynamic>{
      'userId': userId,
      'limit': limit,
    };
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
      parameters: $params,
    );
    final Response $response = await client.send<dynamic, dynamic>(
      $request,
      requestConverter: JsonConverter.requestFactory,
      responseConverter: JsonConverter.responseFactory,
    );
    return $response.bodyOrThrow;
  }

  @override
  Future<dynamic> getSimilarAlbums({
    required BaseItemId id,
    String? userId,
    List<String>? excludeArtistIds,
    int? limit,
    List<String>? fields,
  }) async {
    final Uri $url = Uri.parse('/Albums/${id}/Similar');
    final Map<String, dynamic> $params = <String, dynamic>{
      'userId': userId,
      'excludeArtistIds': excludeArtistIds,
      'limit': limit,
      'fields': fields,
    };
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
      parameters: $params,
    );
    final Response $response = await client.send<dynamic, dynamic>(
      $request,
      requestConverter: JsonConverter.requestFactory,
      responseConverter: JsonConverter.responseFactory,
    );
    return $response.bodyOrThrow;
  }

  @override
  Future<dynamic> getItemById({
    required String userId,
    required BaseItemId itemId,
  }) async {
    final Uri $url = Uri.parse('/Users/${userId}/Items/${itemId}');
    final Request $request = Request('GET', $url, client.baseUrl);
    final Response $response = await client.send<dynamic, dynamic>(
      $request,
      requestConverter: JsonConverter.requestFactory,
      responseConverter: JsonConverter.responseFactory,
    );
    return $response.bodyOrThrow;
  }

  @override
  Future<dynamic> getPlaylistUser({
    required String userId,
    required BaseItemId playlistId,
  }) async {
    final Uri $url = Uri.parse('/Playlists/${playlistId}/Users/${userId}');
    final Request $request = Request('GET', $url, client.baseUrl);
    final Response $response = await client.send<dynamic, dynamic>(
      $request,
      requestConverter: JsonConverter.requestFactory,
      responseConverter: JsonConverter.responseFactory,
    );
    return $response.bodyOrThrow;
  }

  @override
  Future<dynamic> getPlaylistUsers({
    required String userId,
    required BaseItemId playlistId,
  }) async {
    final Uri $url = Uri.parse('/Playlists/${playlistId}/Users');
    final Request $request = Request('GET', $url, client.baseUrl);
    final Response $response = await client.send<dynamic, dynamic>(
      $request,
      requestConverter: JsonConverter.requestFactory,
      responseConverter: JsonConverter.responseFactory,
    );
    return $response.bodyOrThrow;
  }

  @override
  Future<dynamic> getPlaybackInfo({
    required BaseItemId id,
    required String userId,
  }) async {
    final Uri $url = Uri.parse('/Items/${id}/PlaybackInfo');
    final Map<String, dynamic> $params = <String, dynamic>{'userId': userId};
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
      parameters: $params,
    );
    final Response $response = await client.send<dynamic, dynamic>(
      $request,
      requestConverter: JsonConverter.requestFactory,
      responseConverter: JsonConverter.responseFactory,
    );
    return $response.bodyOrThrow;
  }

  @override
  Future<dynamic> submitPlaybackInfo({
    required BaseItemId id,
    required PlaybackInfoRequest playbackInfoRequest,
  }) async {
    final Uri $url = Uri.parse('/Items/${id}/PlaybackInfo');
    final $body = playbackInfoRequest;
    final Request $request = Request('POST', $url, client.baseUrl, body: $body);
    final Response $response = await client.send<dynamic, dynamic>(
      $request,
      requestConverter: JsonConverter.requestFactory,
      responseConverter: JsonConverter.responseFactory,
    );
    return $response.bodyOrThrow;
  }

  @override
  Future<dynamic> updateItem({
    required BaseItemId itemId,
    required BaseItemDto newItem,
  }) async {
    final Uri $url = Uri.parse('/Items/${itemId}');
    final $body = newItem;
    final Request $request = Request('POST', $url, client.baseUrl, body: $body);
    final Response $response = await client.send<dynamic, dynamic>(
      $request,
      requestConverter: JsonConverter.requestFactory,
    );
    return $response.bodyOrThrow;
  }

  @override
  Future<dynamic> updateCapabilities({
    required String playableMediaTypes,
    required String supportedCommands,
    required bool supportsMediaControl,
    required bool supportsPersistentIdentifier,
  }) async {
    final Uri $url = Uri.parse('/Sessions/Capabilities');
    final Map<String, dynamic> $params = <String, dynamic>{
      'playableMediaTypes': playableMediaTypes,
      'supportedCommands': supportedCommands,
      'supportsMediaControl': supportsMediaControl,
      'supportsPersistentIdentifier': supportsPersistentIdentifier,
    };
    final Request $request = Request(
      'POST',
      $url,
      client.baseUrl,
      parameters: $params,
    );
    final Response $response = await client.send<dynamic, dynamic>(
      $request,
      requestConverter: JsonConverter.requestFactory,
    );
    return $response.bodyOrThrow;
  }

  @override
  Future<dynamic> updateCapabilitiesFull(
    ClientCapabilities clientCapabilities,
  ) async {
    final Uri $url = Uri.parse('/Sessions/Capabilities/Full');
    final $body = clientCapabilities;
    final Request $request = Request('POST', $url, client.baseUrl, body: $body);
    final Response $response = await client.send<dynamic, dynamic>(
      $request,
      requestConverter: JsonConverter.requestFactory,
    );
    return $response.bodyOrThrow;
  }

  @override
  Future<dynamic> startPlayback(
    PlaybackProgressInfo playbackProgressInfo,
  ) async {
    final Uri $url = Uri.parse('/Sessions/Playing');
    final $body = playbackProgressInfo;
    final Request $request = Request('POST', $url, client.baseUrl, body: $body);
    final Response $response = await client.send<dynamic, dynamic>(
      $request,
      requestConverter: JsonConverter.requestFactory,
    );
    return $response.bodyOrThrow;
  }

  @override
  Future<dynamic> playbackStatusUpdate(
    PlaybackProgressInfo playbackProgressInfo,
  ) async {
    final Uri $url = Uri.parse('/Sessions/Playing/Progress');
    final $body = playbackProgressInfo;
    final Request $request = Request('POST', $url, client.baseUrl, body: $body);
    final Response $response = await client.send<dynamic, dynamic>(
      $request,
      requestConverter: JsonConverter.requestFactory,
    );
    return $response.bodyOrThrow;
  }

  @override
  Future<dynamic> playbackStatusStopped(
    PlaybackProgressInfo playbackProgressInfo,
  ) async {
    final Uri $url = Uri.parse('/Sessions/Playing/Stopped');
    final $body = playbackProgressInfo;
    final Request $request = Request('POST', $url, client.baseUrl, body: $body);
    final Response $response = await client.send<dynamic, dynamic>(
      $request,
      requestConverter: JsonConverter.requestFactory,
    );
    return $response.bodyOrThrow;
  }

  @override
  Future<dynamic> getPlaylistItems({
    required BaseItemId playlistId,
    required String userId,
    String? includeItemTypes,
    BaseItemId? parentId,
    bool? recursive,
    String? fields = defaultFields,
  }) async {
    final Uri $url = Uri.parse('/Playlists/${playlistId}/Items');
    final Map<String, dynamic> $params = <String, dynamic>{
      'UserId': userId,
      'IncludeItemTypes': includeItemTypes,
      'ParentId': parentId,
      'Recursive': recursive,
      'Fields': fields,
    };
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
      parameters: $params,
    );
    final Response $response = await client.send<dynamic, dynamic>(
      $request,
      requestConverter: JsonConverter.requestFactory,
      responseConverter: JsonConverter.responseFactory,
    );
    return $response.bodyOrThrow;
  }

  @override
  Future<dynamic> createNewPlaylist({required NewPlaylist newPlaylist}) async {
    final Uri $url = Uri.parse('/Playlists');
    final $body = newPlaylist;
    final Request $request = Request('POST', $url, client.baseUrl, body: $body);
    final Response $response = await client.send<dynamic, dynamic>(
      $request,
      requestConverter: JsonConverter.requestFactory,
      responseConverter: JsonConverter.responseFactory,
    );
    return $response.bodyOrThrow;
  }

  @override
  Future<Response<dynamic>> addItemsToPlaylist({
    required BaseItemId playlistId,
    String? ids,
    String? userId,
  }) {
    final Uri $url = Uri.parse('/Playlists/${playlistId}/Items');
    final Map<String, dynamic> $params = <String, dynamic>{
      'ids': ids,
      'userId': userId,
    };
    final Request $request = Request(
      'POST',
      $url,
      client.baseUrl,
      parameters: $params,
    );
    return client.send<dynamic, dynamic>(
      $request,
      requestConverter: JsonConverter.requestFactory,
    );
  }

  @override
  Future<Response<dynamic>> removeItemsFromPlaylist({
    required BaseItemId playlistId,
    String? entryIds,
  }) {
    final Uri $url = Uri.parse('/Playlists/${playlistId}/Items');
    final Map<String, dynamic> $params = <String, dynamic>{
      'entryIds': entryIds,
    };
    final Request $request = Request(
      'DELETE',
      $url,
      client.baseUrl,
      parameters: $params,
    );
    return client.send<dynamic, dynamic>(
      $request,
      requestConverter: JsonConverter.requestFactory,
    );
  }

  @override
  Future<dynamic> updatePlaylist({
    required BaseItemId playlistId,
    required NewPlaylist playlist,
  }) async {
    final Uri $url = Uri.parse('/Playlists/${playlistId}');
    final $body = playlist;
    final Request $request = Request('POST', $url, client.baseUrl, body: $body);
    final Response $response = await client.send<dynamic, dynamic>(
      $request,
      requestConverter: JsonConverter.requestFactory,
    );
    return $response.bodyOrThrow;
  }

  @override
  Future<dynamic> getPlaylist({required BaseItemId playlistId}) async {
    final Uri $url = Uri.parse('/Playlists/${playlistId}');
    final Request $request = Request('GET', $url, client.baseUrl);
    final Response $response = await client.send<dynamic, dynamic>(
      $request,
      responseConverter: JsonConverter.responseFactory,
    );
    return $response.bodyOrThrow;
  }

  @override
  Future<dynamic> getArtists({
    BaseItemId? parentId,
    String? sortBy,
    String? sortOrder,
    String? fields = defaultFields,
    String? searchTerm,
    String? filters,
    String? genreIds,
    int? startIndex,
    int? limit,
    bool? isFavorite,
    String? nameStartsWith,
  }) async {
    final Uri $url = Uri.parse('/Artists');
    final Map<String, dynamic> $params = <String, dynamic>{
      'ParentId': parentId,
      'SortBy': sortBy,
      'SortOrder': sortOrder,
      'Fields': fields,
      'SearchTerm': searchTerm,
      'Filters': filters,
      'GenreIds': genreIds,
      'StartIndex': startIndex,
      'Limit': limit,
      'isFavorite': isFavorite,
      'NameStartsWith': nameStartsWith,
    };
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
      parameters: $params,
    );
    final Response $response = await client.send<dynamic, dynamic>(
      $request,
      requestConverter: JsonConverter.requestFactory,
      responseConverter: JsonConverter.responseFactory,
    );
    return $response.bodyOrThrow;
  }

  @override
  Future<dynamic> getAlbumArtists({
    String? includeItemTypes,
    BaseItemId? parentId,
    bool? recursive,
    String? sortBy,
    String? sortOrder,
    String? fields = defaultFields,
    String? searchTerm,
    bool enableUserData = true,
    String? filters,
    String? genreIds,
    int? startIndex,
    int? limit,
    required String userId,
    bool? isFavorite,
    String? nameStartsWith,
  }) async {
    final Uri $url = Uri.parse('/Artists/AlbumArtists');
    final Map<String, dynamic> $params = <String, dynamic>{
      'IncludeItemTypes': includeItemTypes,
      'ParentId': parentId,
      'Recursive': recursive,
      'SortBy': sortBy,
      'SortOrder': sortOrder,
      'Fields': fields,
      'SearchTerm': searchTerm,
      'EnableUserData': enableUserData,
      'Filters': filters,
      'GenreIds': genreIds,
      'StartIndex': startIndex,
      'Limit': limit,
      'UserId': userId,
      'isFavorite': isFavorite,
      'NameStartsWith': nameStartsWith,
    };
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
      parameters: $params,
    );
    final Response $response = await client.send<dynamic, dynamic>(
      $request,
      requestConverter: JsonConverter.requestFactory,
      responseConverter: JsonConverter.responseFactory,
    );
    return $response.bodyOrThrow;
  }

  @override
  Future<dynamic> getGenres({
    String? includeItemTypes,
    BaseItemId? parentId,
    String? fields = defaultFields,
    String? sortBy,
    String? sortOrder,
    bool? isFavorite,
    String? searchTerm,
    int? startIndex,
    int? limit,
  }) async {
    final Uri $url = Uri.parse('/Genres');
    final Map<String, dynamic> $params = <String, dynamic>{
      'IncludeItemTypes': includeItemTypes,
      'ParentId': parentId,
      'Fields': fields,
      'SortBy': sortBy,
      'SortOrder': sortOrder,
      'isFavorite': isFavorite,
      'SearchTerm': searchTerm,
      'StartIndex': startIndex,
      'Limit': limit,
    };
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
      parameters: $params,
    );
    final Response $response = await client.send<dynamic, dynamic>(
      $request,
      requestConverter: JsonConverter.requestFactory,
      responseConverter: JsonConverter.responseFactory,
    );
    return $response.bodyOrThrow;
  }

  @override
  Future<dynamic> addFavorite({
    required String userId,
    required BaseItemId itemId,
  }) async {
    final Uri $url = Uri.parse('/Users/${userId}/FavoriteItems/${itemId}');
    final Request $request = Request('POST', $url, client.baseUrl);
    final Response $response = await client.send<dynamic, dynamic>(
      $request,
      requestConverter: JsonConverter.requestFactory,
      responseConverter: JsonConverter.responseFactory,
    );
    return $response.bodyOrThrow;
  }

  @override
  Future<dynamic> removeFavorite({
    required String userId,
    required BaseItemId itemId,
  }) async {
    final Uri $url = Uri.parse('/Users/${userId}/FavoriteItems/${itemId}');
    final Request $request = Request('DELETE', $url, client.baseUrl);
    final Response $response = await client.send<dynamic, dynamic>(
      $request,
      requestConverter: JsonConverter.requestFactory,
      responseConverter: JsonConverter.responseFactory,
    );
    return $response.bodyOrThrow;
  }

  @override
  Future<dynamic> getLyrics({required BaseItemId itemId}) async {
    final Uri $url = Uri.parse('/Audio/${itemId}/Lyrics');
    final Request $request = Request('GET', $url, client.baseUrl);
    final Response $response = await client.send<dynamic, dynamic>(
      $request,
      requestConverter: JsonConverter.requestFactory,
      responseConverter: JsonConverter.responseFactory,
    );
    return $response.bodyOrThrow;
  }

  @override
  Future<Response<dynamic>> logout() {
    final Uri $url = Uri.parse('/Sessions/Logout');
    final Request $request = Request('POST', $url, client.baseUrl);
    return client.send<dynamic, dynamic>(
      $request,
      requestConverter: JsonConverter.requestFactory,
    );
  }

  @override
  Future<Response<dynamic>> pingServer() {
    final Uri $url = Uri.parse('/System/Endpoint');
    final Request $request = Request('GET', $url, client.baseUrl);
    return client.send<dynamic, dynamic>($request);
  }
}
