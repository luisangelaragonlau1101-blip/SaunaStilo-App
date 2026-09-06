from pathlib import Path

def replace(name, old, new):
    p = Path(name); text = p.read_text(); assert text.count(old) == 1, name
    p.write_text(text.replace(old, new))

replace('lib/academy/learning_progress.dart', "   dates[lang]=raw.toSet().toList()..sort();", "   if ((d['days'] as Map).containsKey(lang)) dates[lang]=raw.toSet().toList()..sort();")
replace('lib/services/external_transfer.dart', 'ContextMenuButtonType.cut,ContextMenuButtonType.share]', 'ContextMenuButtonType.cut,ContextMenuButtonType.share,ContextMenuButtonType.searchWeb,ContextMenuButtonType.lookUp]')
