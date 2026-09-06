from pathlib import Path
import hashlib

def edit(name, old, new):
    p=Path(name); text=p.read_text(); assert text.count(old)==1, f'Anchor changed: {name}: {old[:50]}'
    p.write_text(text.replace(old,new))

# The offline entry is a games-only route. It never creates or opens a business account.
edit('lib/screens/login_screen.dart', "import 'package:flutter/material.dart';", "import 'local_party_screen.dart';\nimport 'package:flutter/material.dart';")
edit('lib/screens/login_screen.dart', "                        Text('SAUNA STILO · INTERFAZ 3.0'", "                        TextButton.icon(onPressed: _isLoading ? null : () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const LocalPartyScreen())), icon: const Icon(Icons.sports_esports_rounded), label: const Text('Juegos sin conexión · hasta 4')),\n                        Text('SAUNA STILO · INTERFAZ 3.0'")
edit('lib/main.dart', "import 'dart:async';", "import 'dart:async';\nimport 'screens/local_party_screen.dart';")
edit('lib/main.dart', "                FilledButton.icon(onPressed: _retry, icon: const Icon(Icons.refresh_rounded), label: const Text('REINTENTAR')),", "                FilledButton.icon(onPressed: _retry, icon: const Icon(Icons.refresh_rounded), label: const Text('REINTENTAR')),\n                Builder(builder: (nav) => TextButton.icon(onPressed: () => Navigator.of(nav).push(MaterialPageRoute<void>(builder: (_) => const LocalPartyScreen())), icon: const Icon(Icons.sports_esports_rounded), label: const Text('Juegos sin conexión · hasta 4'))),")
# Lazy remote tab: opening local games must never require a Firestore collection subscription.
p=Path('lib/screens/team_games_screen.dart'); s=p.read_text()
s="import 'local_party_screen.dart';\n"+s
s=s.replace("late final _service=TeamGamesService();bool _busy=false;final _ids", "late final _service=TeamGamesService();bool _busy=false;bool _remote=false;final _ids",1)
a=s.index('  @override\n  Widget build(BuildContext context)=>DefaultTabController(')
b=s.index('  Widget _tile(',a)
remote=s[s.index('    Column(children:[Padding(padding:const EdgeInsets.all(18),child:FilledButton.icon',a):s.index('\n  ])));',a)].strip().removesuffix(',')
assert remote.startswith('Column(') and remote.endswith('])')
body="""  @override
  Widget build(BuildContext context)=>Scaffold(backgroundColor:Colors.black,
    appBar:AppBar(title:const Text('Pausa Stilo · Juegos')),
    body:Column(children:[Padding(padding:const EdgeInsets.symmetric(horizontal:16),child:Wrap(spacing:10,runSpacing:8,children:[
      ChoiceChip(label:const Text('Sin Wi-Fi · hasta 4'),selected:!_remote,onSelected:(_)=>setState(()=>_remote=false)),
      ChoiceChip(label:const Text('Gato en línea'),selected:_remote,onSelected:(_)=>setState(()=>_remote=true)),
    ])),Expanded(child:_remote?REMOTE:const LocalPartyLobby())]));
""".replace('REMOTE',remote)
s=s[:a]+body+s[b:];p.write_text(s)
edit('lib/services/app_action_catalog.dart', "subtitle: 'Gato con el equipo y juegos locales'", "subtitle: 'Sin Wi-Fi · hasta 4 en el mismo teléfono'")
edit('lib/services/app_action_catalog.dart', "keywords: const ['jugar','memoria','gato']", "keywords: const ['jugar','memoria','gato','cuatro','carrera','territorios','offline']")
assert "'juegos'].contains(a.id)" in Path('lib/screens/operations_shell.dart').read_text()
# Commit the exact version under review; no secrets or production service changes.
edit('pubspec.yaml', 'version: 1.0.0+1', 'version: 3.2.0+1788740000')
print('Offline games connected to login, home and team menu. Work roles and general alert preserved.')
