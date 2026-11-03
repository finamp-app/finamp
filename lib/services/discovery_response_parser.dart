import 'dart:convert';

import 'package:finamp/models/jellyfin_models.dart';

/// Discovery uses unauthenticated UDP, so unrelated or incomplete datagrams
/// must not escape into the asynchronous socket listener as exceptions.
ClientDiscoveryResponse? parseDiscoveryResponse(List<int> bytes) {
  try {
    final json = jsonDecode(utf8.decode(bytes));
    if (json is! Map<String, dynamic>) return null;

    final response = ClientDiscoveryResponse.fromJson(json);
    final address = response.address;
    if (address == null || address.trim().isEmpty) return null;
    final uri = Uri.tryParse(address);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https') || uri.host.isEmpty) {
      return null;
    }
    return response;
  } on FormatException {
    return null;
  } on TypeError {
    return null;
  }
}
