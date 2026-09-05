from pathlib import Path

files = {
    Path('lib/screens/futuristic_dashboard_screen.dart'): {
        '0xFF05070A': '0xFF050506',
        '0xFF10151B': '0xFF111012',
        '0xFF86E9FF': '0xFFB7FF2A',
        '0xFFA8F6D5': '0xFFC6FF68',
        '0xFFB8A7FF': '0xFFC13CFF',
        '0xFF172530': '0xFF2B0B18',
        '0xFF0C1117': '0xFF120C12',
        '0xFF0C1817': '0xFF12180C',
    },
    Path('lib/screens/blog_interno_screen.dart'): {
        '0xFF000000': '0xFF050506',
        '0xFF262626': '0xFF30272D',
        '0xFF121212': '0xFF111012',
        '0xFFFF2D7A': '0xFFB7FF2A',
        '0xFFFF8A3D': '0xFF8E1538',
        '0xFF8B5CF6': '0xFFC13CFF',
    },
    Path('lib/services/app_action_catalog.dart'): {
        '0xFF86E9FF': '0xFFB7FF2A',
        '0xFFA8F6D5': '0xFFC6FF68',
        '0xFFB8A7FF': '0xFFC13CFF',
        '0xFFFFB2D8': '0xFFB82B55',
        '0xFFFFCA80': '0xFFFFB347',
        '0xFF9FC7FF': '0xFFB7FF2A',
        '0xFFC7CFD9': '0xFFD7D3D6',
        '0xFFFFDF8A': '0xFFD7FF74',
        '0xFFFFAFC4': '0xFFC94469',
        '0xFFFFB384': '0xFFB82B55',
        '0xFFFFC18A': '0xFFD7FF74',
        '0xFF8DE6B5': '0xFFC6FF68',
        '0xFFE4C6FF': '0xFFC13CFF',
        '0xFFFF9878': '0xFFFF536A',
    },
}

for path, replacements in files.items():
    text = path.read_text(encoding='utf-8')
    original = text
    for old, new in replacements.items():
        text = text.replace(old, new)
    if text == original:
        raise SystemExit(f'No theme replacements were applied to {path}')
    path.write_text(text, encoding='utf-8')

# Brand copy: community remains a team social space but explicitly Sauna Stilo.
blog = Path('lib/screens/blog_interno_screen.dart')
text = blog.read_text(encoding='utf-8')
text = text.replace("'SAUNA STILO'", "'STILO COMMUNITY'", 1)
blog.write_text(text, encoding='utf-8')

# Dashboard fallback icon follows the real brand rather than a generic fire mark.
dash = Path('lib/screens/futuristic_dashboard_screen.dart')
text = dash.read_text(encoding='utf-8')
text = text.replace('Icons.local_fire_department_rounded,\n                    color: _cyan,', 'Icons.blur_on_rounded,\n                    color: _cyan,', 1)
dash.write_text(text, encoding='utf-8')
