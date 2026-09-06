/// Only public HTTPS links are opened, on a deliberate user tap. No previews are fetched.
class ProfileSocialLinks {
  static const platforms = <String, String>{
    'instagram': 'Instagram', 'facebook': 'Facebook', 'tiktok': 'TikTok',
    'spotify': 'Spotify', 'youtube': 'YouTube', 'x': 'X', 'linkedin': 'LinkedIn',
    'web': 'Mi sitio web', 'otro': 'Otro enlace',
  };
  static const _hosts = <String, List<String>>{
    'instagram': ['instagram.com'], 'facebook': ['facebook.com', 'fb.com', 'fb.me'],
    'tiktok': ['tiktok.com'], 'spotify': ['open.spotify.com', 'spotify.link'],
    'youtube': ['youtube.com', 'youtu.be'], 'x': ['x.com', 'twitter.com'],
    'linkedin': ['linkedin.com'],
  };
  static bool _matches(String host, String allowed) => host == allowed || host.endsWith('.$allowed');
  static String normalize(String platform, String input) {
    var value = input.trim();
    if (value.isEmpty) return '';
    if (!value.contains('://')) value = 'https://$value';
    final uri = Uri.tryParse(value);
    if (value.length > 500 || RegExp(r'\s|%0a|%0d', caseSensitive: false).hasMatch(value) ||
        uri == null || uri.scheme != 'https' || uri.userInfo.isNotEmpty ||
        (uri.hasPort && uri.port != 443) || !uri.host.contains('.') ||
        !RegExp(r'^[a-zA-Z0-9.-]+$').hasMatch(uri.host) ||
        RegExp(r'^[0-9.]+$').hasMatch(uri.host) || uri.host.endsWith('.local') || uri.host.endsWith('.internal')) {
      throw const FormatException('Pega un enlace público HTTPS válido, sin contraseñas (máximo 500 caracteres).');
    }
    final hosts = _hosts[platform];
    if (hosts != null && !hosts.any((host) => _matches(uri.host.toLowerCase(), host))) {
      throw FormatException('Este campo necesita un enlace de ${platforms[platform]}.');
    }
    return uri.toString();
  }
  static String music(String input) {
    final value = normalize('web', input);
    if (value.isEmpty) return '';
    final host = Uri.parse(value).host.toLowerCase();
    const allowed = ['open.spotify.com', 'spotify.link', 'youtube.com', 'youtu.be', 'music.apple.com', 'soundcloud.com'];
    if (!allowed.any((h) => _matches(host, h))) throw const FormatException('Usa Spotify, YouTube, Apple Music o SoundCloud.');
    return value;
  }
  static Map<String, String> fromData(dynamic raw) {
    if (raw is! Map) return {};
    final result = <String, String>{};
    for (final key in platforms.keys) {
      try { final value = normalize(key, raw[key]?.toString() ?? ''); if (value.isNotEmpty) result[key] = value; }
      on FormatException { /* Invalid legacy links are not made clickable. */ }
    }
    return result;
  }
}
