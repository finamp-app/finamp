/// Jellyfin server URL helpers for login.
///
/// Dart's [Uri.parse] treats `http://jellyfin@tailnet.ts.net:8096` as
/// userInfo=`jellyfin` + host=`tailnet.ts.net` (because `@` starts userinfo).
/// That produces requests to `http://tailnet.ts.net:8096/...` and DNS failures.
/// A common typo/paste replaces the first `.` with `@`.
class JellyfinServerUrl {
  JellyfinServerUrl._();

  /// If [raw] has userInfo that looks like a hostname label (no `:`)
  /// and a real host, rewrite `user@host` → `user.host`.
  static String normalize(String raw) {
    final trimmed = raw.trim();
    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return trimmed;
    }
    final userInfo = uri.userInfo;
    if (userInfo.isEmpty) {
      return trimmed;
    }
    // Real credentials use user:password — leave those alone.
    if (userInfo.contains(':')) {
      return trimmed;
    }
    if (!_looksLikeHostnameLabel(userInfo)) {
      return trimmed;
    }

    final fixedHost = '$userInfo.${uri.host}';
    final fixed = uri.replace(userInfo: '', host: fixedHost);
    // Keep Finamp's no-trailing-slash convention.
    var out = fixed.toString();
    if (out.endsWith('/') && (fixed.path.isEmpty || fixed.path == '/')) {
      out = out.substring(0, out.length - 1);
    }
    return out;
  }

  /// Returns a validation error string, or null if OK.
  ///
  /// Call [normalize] before validate if you want `@` typos auto-fixed;
  /// otherwise this rejects bare `user@host` so the field error is visible.
  static String? validate(
    String? value, {
    required String empty,
    required String mustStartWithHttp,
    required String noTrailingSlash,
    required String userInfoTypo,
  }) {
    if (value == null || value.trim().isEmpty) {
      return empty;
    }
    final trimmed = value.trim();
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      return mustStartWithHttp;
    }
    if (trimmed.endsWith('/')) {
      return noTrailingSlash;
    }

    final uri = Uri.tryParse(trimmed);
    if (uri == null || uri.host.isEmpty) {
      return mustStartWithHttp;
    }
    // Bare user@host (no password) is almost always a MagicDNS typo.
    if (uri.userInfo.isNotEmpty && !uri.userInfo.contains(':')) {
      return userInfoTypo;
    }
    return null;
  }

  static bool _looksLikeHostnameLabel(String s) {
    if (s.isEmpty || s.length > 63) {
      return false;
    }
    return RegExp(r'^[A-Za-z0-9]([A-Za-z0-9\-]*[A-Za-z0-9])?$').hasMatch(s);
  }
}
