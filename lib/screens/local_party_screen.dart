import '../services/external_transfer.dart';
import 'package:flutter/material.dart';
import '../games/party_match.dart';
import '../games/party_store.dart';
import '../widgets/stilo_orbit.dart';

const partyColors = [Color(0xFFB7FF2A), Color(0xFFFF729C), Color(0xFFC798FF), Color(0xFFFFB876)];
const partyIcons = [
  Icons.local_fire_department_rounded, Icons.spa_rounded, Icons.handyman_rounded,
  Icons.water_drop_rounded, Icons.forest_rounded, Icons.wb_sunny_rounded,
  Icons.workspace_premium_rounded, Icons.music_note_rounded, Icons.favorite_rounded,
  Icons.construction_rounded, Icons.bolt_rounded, Icons.home_rounded,
];
String partyTitle(PartyKind kind) => switch (kind) {
  PartyKind.memory => 'Memorama Stilo', PartyKind.territory => 'Territorios Stilo', PartyKind.race => 'Carrera Stilo',
};
String partyRules(PartyKind kind) => switch (kind) {
  PartyKind.memory => 'Encuentra los 12 pares. Si aciertas, conservas el turno. Si no, mira las cartas y pulsa Siguiente turno. Gana quien reúne más pares.',
  PartyKind.territory => 'Toca una línea libre para unir dos puntos. Quien cierra un cuadro lo conquista y vuelve a jugar. Gana quien conquista más cuadros.',
  PartyKind.race => 'Tira el dado y avanza hacia la casilla 30. Las casillas + te impulsan; las casillas − te hacen retroceder. Gana quien llega primero, sin necesitar un tiro exacto.',
};
IconData partyIcon(PartyKind kind) => switch (kind) {
  PartyKind.memory => Icons.style_rounded, PartyKind.territory => Icons.grid_view_rounded, PartyKind.race => Icons.flag_rounded,
};

class LocalPartyScreen extends StatelessWidget {
  const LocalPartyScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(backgroundColor: Colors.black,
    appBar: AppBar(title: const Text('Pausa Stilo'), backgroundColor: Colors.black),
    body: const LocalPartyLobby());
}

/// Can be opened before sign-in; this widget never accesses company data or Firebase.
class LocalPartyLobby extends StatefulWidget {
  const LocalPartyLobby({super.key});
  @override
  State<LocalPartyLobby> createState() => _LocalLobbyState();
}
class _LocalLobbyState extends State<LocalPartyLobby> {
  PartyMatch? _saved;
  String? _warning;
  bool _opening = false;
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try { final saved = await PartyStore.read(); if (mounted) setState(() { _saved = saved; _warning = null; }); }
    catch (_) { if (mounted) setState(() => _warning = 'No se pudo recuperar la partida anterior. Puedes comenzar otra.'); }
  }
  Future<void> _open(PartyMatch match) async {
    await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => LocalPartyBoard(match: match)));
    if (mounted) await _load();
  }
  Future<void> _setup(PartyKind kind) async {
    if (_opening) return;
    setState(() => _opening = true);
    final match = await showModalBottomSheet<PartyMatch>(context: context, isScrollControlled: true,
      useSafeArea: true, backgroundColor: const Color(0xFF111012),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (_) => _PartySetup(kind: kind, hasSaved: _saved != null));
    if (!mounted) return;
    setState(() => _opening = false);
    if (match != null) await _open(match);
  }
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.fromLTRB(18, 16, 18, 32), children: [
    Container(padding: const EdgeInsets.all(22), decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(32), border: Border.all(color: const Color(0xFF71304D)),
      gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF36101F), Color(0xFF151015), Color(0xFF090909)]),
      boxShadow: const [BoxShadow(color: Color(0x228E1538), blurRadius: 25)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Image.asset('assets/logo_saunastilo.png', width: 102, height: 64, fit: BoxFit.contain), const Spacer(),
          const StiloOrbitIcon(icon: Icons.sports_esports_rounded, color: Color(0xFFC798FF), size: 58, active: true)]),
        const SizedBox(height: 14), const Text('Una pausa.\nTodo el equipo.', style: TextStyle(color: Colors.white, fontSize: 29, height: 1.12, fontWeight: FontWeight.w900)),
        const SizedBox(height: 16), const Wrap(spacing: 8, runSpacing: 8, children: [
          Chip(avatar: Icon(Icons.wifi_off_rounded, size: 16), label: Text('Sin Wi-Fi')),
          Chip(avatar: Icon(Icons.groups_rounded, size: 18), label: Text('Hasta 4 jugadores')),
        ]),
        const SizedBox(height: 6), const Text('Por turnos en el mismo teléfono. Sin datos, anuncios ni compras.', style: TextStyle(color: Colors.white70, height: 1.4)),
      ])),
    if (_warning != null) Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(_warning!, style: const TextStyle(color: Colors.amberAccent))),
    if (_saved != null) Padding(padding: const EdgeInsets.only(top: 16), child: OutlinedButton.icon(
      key: const ValueKey('party-resume'), onPressed: () => _open(_saved!), icon: const Icon(Icons.play_circle_outline_rounded),
      label: Text('${_saved!.finished ? 'Ver resultado' : 'Continuar'} · ${partyTitle(_saved!.kind)}'))),
    const Padding(padding: EdgeInsets.only(top: 22, bottom: 12), child: Text('ELIGE TU PAUSA', style: TextStyle(color: Colors.white60, fontWeight: FontWeight.w800, letterSpacing: 1.8, fontSize: 12))),
    for (final kind in PartyKind.values) Padding(padding: const EdgeInsets.only(bottom: 13), child: Card(
      margin: EdgeInsets.zero, color: const Color(0xFF111012), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28), side: BorderSide(color: partyColors[kind.index].withValues(alpha: .35))),
      child: InkWell(key: ValueKey('party-select-${kind.name}'), borderRadius: BorderRadius.circular(28), onTap: _opening ? null : () => _setup(kind),
        child: Padding(padding: const EdgeInsets.all(18), child: Row(children: [
          StiloOrbitIcon(icon: partyIcon(kind), color: partyColors[kind.index], size: 52, active: true), const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(partyTitle(kind), style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6), Text(switch (kind) { PartyKind.memory => '1–4 personas · encuentra los pares', PartyKind.territory => '2–4 personas · conquista cuadros', PartyKind.race => '2–4 personas · llega a la meta' }, style: const TextStyle(color: Colors.white60, fontSize: 12, height: 1.4))])),
          const Icon(Icons.chevron_right_rounded, color: Colors.white60),
        ]))))),
    const Padding(padding: EdgeInsets.only(top: 6), child: Text('La partida se guarda en este dispositivo, no en los perfiles del equipo. Los juegos no cambian tu asistencia, rachas ni logros de trabajo.', style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.5))),
  ]);
}

class _PartySetup extends StatefulWidget {
  final PartyKind kind; final bool hasSaved;
  const _PartySetup({required this.kind, required this.hasSaved});
  @override
  State<_PartySetup> createState() => _SetupState();
}
class _SetupState extends State<_PartySetup> {
  int _players = 2;
  final _names = List.generate(4, (_) => TextEditingController());
  @override
  void dispose() { for (final n in _names) { n.dispose(); } super.dispose(); }
  @override
  Widget build(BuildContext context) => Padding(padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: SingleChildScrollView(padding: const EdgeInsets.all(22), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(partyTitle(widget.kind), style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
      const SizedBox(height: 12), Text(partyRules(widget.kind), style: const TextStyle(color: Colors.white70, height: 1.45)),
      const SizedBox(height: 18), const Text('¿Cuántos juegan en este teléfono?', style: TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 10), Wrap(spacing: 10, runSpacing: 8, children: [
        for (var p = widget.kind == PartyKind.memory ? 1 : 2; p <= 4; p++) ChoiceChip(key: ValueKey('party-count-$p'), label: Text('$p'),
          selected: _players == p, onSelected: (_) => setState(() => _players = p)),
      ]),
      for (var i = 0; i < _players; i++) Padding(padding: const EdgeInsets.only(top: 12), child: TextField(contextMenuBuilder: privacyTextMenu,
        key: ValueKey('party-name-$i'), controller: _names[i], maxLength: 24, textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(labelText: 'Jugador ${i + 1}', hintText: 'Nombre o apodo (opcional)', counterText: '', prefixIcon: Icon(Icons.person_rounded, color: partyColors[i])))),
      const SizedBox(height: 18), Text(widget.hasSaved ? 'Al empezar se reemplaza la partida local anterior. No se modifica ningún dato de trabajo.' : 'Solo se guardan nombres y jugadas en este dispositivo.', style: const TextStyle(color: Colors.white54, fontSize: 12)),
      const SizedBox(height: 16), FilledButton.icon(key: const ValueKey('party-start'), onPressed: () {
        final names = List.generate(_players, (i) => _names[i].text.trim().isEmpty ? 'Jugador ${i + 1}' : _names[i].text.trim());
        Navigator.pop(context, PartyMatch(widget.kind, names));
      }, icon: const Icon(Icons.play_arrow_rounded), label: const Text('Empezar partida')),
    ])));
}

class LocalPartyBoard extends StatefulWidget {
  final PartyMatch match;
  const LocalPartyBoard({super.key, required this.match});
  @override
  State<LocalPartyBoard> createState() => _PartyBoardState();
}
class _PartyBoardState extends State<LocalPartyBoard> {
  late PartyMatch _game;
  String _saveLabel = 'Guardando partida local…';
  int _saveVersion = 0;
  @override
  void initState() { super.initState(); _game = widget.match; _save(); }
  Future<void> _save() async {
    final version = ++_saveVersion;
    try { await PartyStore.save(_game); if (mounted && version == _saveVersion) setState(() => _saveLabel = 'Partida guardada en este dispositivo'); }
    catch (_) { if (mounted && version == _saveVersion) setState(() => _saveLabel = 'No se pudo guardar. Puedes jugar, pero no cierres esta pantalla.'); }
  }
  void _act(VoidCallback action) {
    try { setState(() { action(); _saveLabel = 'Guardando partida local…'; }); _save(); }
    on StateError catch (_) { /* Ignore a stale double-tap; the current board remains authoritative. */ }
  }
  Future<void> _restart() async {
    final yes = await showDialog<bool>(context: context, builder: (c) => AlertDialog(title: const Text('¿Comenzar otra partida?'),
      content: const Text('Se reiniciarán el tablero y los puntos de esta partida.'), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Reiniciar'))]));
    if (yes == true && mounted) _act(() => _game = PartyMatch(_game.kind, _game.names));
  }
  String get _status {
    if (!_game.finished) return 'Turno de ${_game.names[_game.turn]}';
    return '${_game.winners.length > 1 ? '¡Empate!' : '¡Ganó'} ${_game.winners.map((p) => _game.names[p]).join(' y ')}${_game.winners.length == 1 ? '!' : ''}';
  }
  @override
  Widget build(BuildContext context) => Scaffold(backgroundColor: Colors.black,
    appBar: AppBar(title: Text(partyTitle(_game.kind)), backgroundColor: Colors.black, actions: [IconButton(tooltip: 'Cómo jugar', icon: const Icon(Icons.help_outline_rounded), onPressed: () => showDialog<void>(context: context, builder: (c) => AlertDialog(title: const Text('Cómo jugar'), content: Text(partyRules(_game.kind)), actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Entendido'))])))]),
    body: SafeArea(top: false, child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 660), child: ListView(padding: const EdgeInsets.all(18), children: [
      Row(children: [Image.asset('assets/logo_saunastilo.png', width: 80, height: 44), const Spacer(), const Icon(Icons.wifi_off_rounded, size: 16, color: Colors.white60), const SizedBox(width: 7), const Flexible(child: Text('Mismo teléfono', style: TextStyle(color: Colors.white60, fontSize: 12)))]),
      const SizedBox(height: 14), Semantics(liveRegion: true, child: Text(_status, key: const ValueKey('party-status'), style: const TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.w900))),
      const SizedBox(height: 14), Wrap(spacing: 8, runSpacing: 8, children: [for (var p = 0; p < _game.players; p++) Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10), decoration: BoxDecoration(borderRadius: BorderRadius.circular(22),
          color: partyColors[p].withValues(alpha: p == _game.turn && !_game.finished ? .17 : .06), border: Border.all(color: partyColors[p].withValues(alpha: p == _game.turn ? .75 : .26))),
        child: Text('P${p + 1} · ${_game.names[p]}   ${_game.scores[p]}${_game.kind == PartyKind.race ? '/30' : ''}', style: TextStyle(color: partyColors[p], fontWeight: FontWeight.w700, fontSize: 12)))]),
      const SizedBox(height: 18),
      if (_game.finished) Container(margin: const EdgeInsets.only(bottom: 18), padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: const Color(0xFF29101D), borderRadius: BorderRadius.circular(26)), child: const Row(children: [StiloOrbitIcon(icon: Icons.emoji_events_rounded, color: Color(0xFFB7FF2A), active: true), SizedBox(width: 14), Expanded(child: Text('¡Buena partida, equipo!\nUn momento para compartir.', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)))])),
      switch (_game.kind) { PartyKind.memory => _memory(), PartyKind.territory => _territory(), PartyKind.race => _race() },
      const SizedBox(height: 20), Text(_saveLabel, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54, fontSize: 11)),
      const SizedBox(height: 12), OutlinedButton.icon(onPressed: _restart, icon: const Icon(Icons.refresh_rounded), label: const Text('Nueva partida')),
    ])))));
  Widget _memory() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    const Text('12 pares · si aciertas, repites turno', style: TextStyle(color: Colors.white60, fontSize: 12)), const SizedBox(height: 12),
    GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: 24,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, mainAxisSpacing: 8, crossAxisSpacing: 8),
      itemBuilder: (c, i) {
        final open = _game.faceUp(i), owner = _game.claimed[i];
        final color = partyColors[owner >= 0 ? owner : _game.turn];
        return Semantics(label: 'Carta ${i + 1}, ${owner >= 0 ? 'par de jugador ${owner + 1}' : open ? 'figura ${_game.deck[i] + 1}' : 'oculta'}', button: true,
          child: FilledButton(key: ValueKey('memory-card-$i'), style: FilledButton.styleFrom(padding: EdgeInsets.zero,
            backgroundColor: open ? color.withValues(alpha: .15) : const Color(0xFF25131E), disabledBackgroundColor: open ? color.withValues(alpha: .15) : const Color(0xFF25131E),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(19), side: BorderSide(color: open ? color : const Color(0xFF512B3E)))),
            onPressed: _game.finished || _game.waiting || open ? null : () => _act(() => _game.flip(i)),
            child: Icon(open ? partyIcons[_game.deck[i]] : Icons.blur_on_rounded, color: open ? color : const Color(0xFFBC91A2), size: 28)));
      }),
    if (_game.waiting) Padding(padding: const EdgeInsets.only(top: 16), child: FilledButton.icon(key: const ValueKey('memory-next'), onPressed: () => _act(_game.nextMemoryTurn), icon: const Icon(Icons.arrow_forward_rounded), label: const Text('Siguiente turno'))),
  ]);
  Widget _territory() => Column(children: [const Text('Une puntos · cierra cuadros · repite turno', style: TextStyle(color: Colors.white60, fontSize: 12)),
    const SizedBox(height: 16), AspectRatio(aspectRatio: 1, child: LayoutBuilder(builder: (context, constraints) {
      final size = constraints.maxWidth, gap = (size - 44) / 3;
      return Stack(children: [
        for (var b = 0; b < 9; b++) Positioned(left: 22 + (b % 3) * gap + 22, top: 22 + (b ~/ 3) * gap + 22, width: gap - 44, height: gap - 44,
          child: Center(child: _game.boxes[b] < 0 ? const Icon(Icons.spa_rounded, color: Colors.white12, size: 19) : Text('P${_game.boxes[b] + 1}', style: TextStyle(color: partyColors[_game.boxes[b]], fontSize: 18, fontWeight: FontWeight.w900)))),
        for (var i = 0; i < 16; i++) Positioned(left: 16 + (i % 4) * gap, top: 16 + (i ~/ 4) * gap, width: 12, height: 12,
          child: Container(decoration: const BoxDecoration(color: Colors.white70, shape: BoxShape.circle))),
        for (var e = 0; e < 24; e++) _edge(e, gap),
      ]);
    })),
  ]);
  Widget _edge(int e, double gap) {
    final horizontal = e < 12, i = horizontal ? e : e - 12;
    final row = horizontal ? i ~/ 3 : i ~/ 4, col = horizontal ? i % 3 : i % 4;
    final owner = _game.edges[e], color = owner < 0 ? const Color(0xFF543344) : partyColors[owner];
    return Positioned(left: horizontal ? 36 + col * gap : col * gap, top: horizontal ? row * gap : 36 + row * gap,
      width: horizontal ? gap - 28 : 44, height: horizontal ? 44 : gap - 28,
      child: Semantics(button: true, label: '${horizontal ? 'Horizontal' : 'Vertical'} ${i + 1}: ${owner < 0 ? 'libre' : 'jugador ${owner + 1}'}',
        child: InkWell(key: ValueKey('territory-edge-$e'), borderRadius: BorderRadius.circular(16), onTap: owner >= 0 || _game.finished ? null : () => _act(() => _game.drawEdge(e)),
          child: Center(child: Container(width: horizontal ? gap - 28 : 7, height: horizontal ? 7 : gap - 28,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8), boxShadow: owner < 0 ? null : [BoxShadow(color: color.withValues(alpha: .24), blurRadius: 10)]))))));
  }
  Widget _race() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    const Text('Meta: 30 · + impulso · − retroceso', style: TextStyle(color: Colors.white60, fontSize: 12)), const SizedBox(height: 12),
    GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: 30,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 5, mainAxisSpacing: 6, crossAxisSpacing: 6), itemBuilder: (context, index) {
        final row = index ~/ 5, col = index % 5, step = row.isEven ? row * 5 + col + 1 : row * 5 + 5 - col;
        final tokens = [for (var p = 0; p < _game.players; p++) if (_game.positions[p] == step) p];
        final boost = PartyMatch.boosts[step];
        return Container(decoration: BoxDecoration(color: step == 30 ? const Color(0xFF2C3412) : const Color(0xFF1A1218), borderRadius: BorderRadius.circular(15), border: Border.all(color: step == 30 ? partyColors[0] : const Color(0xFF39222F))),
          child: Padding(padding: const EdgeInsets.all(3), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('$step${boost == null ? '' : boost > 0 ? ' +$boost' : ' $boost'}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: boost == null ? Colors.white60 : boost > 0 ? partyColors[0] : partyColors[1])),
            if (tokens.isNotEmpty) Wrap(spacing: 3, runSpacing: 2, alignment: WrapAlignment.center, children: [for (final p in tokens) Text('${p + 1}', style: TextStyle(color: partyColors[p], fontSize: 12, fontWeight: FontWeight.w900))]),
            if (step == 30 && tokens.isEmpty) const Icon(Icons.flag_rounded, color: Color(0xFFB7FF2A), size: 18),
          ])));
      }),
    const SizedBox(height: 16),
    if (_game.lastPlayer >= 0) Text('${_game.names[_game.lastPlayer]} sacó ${_game.lastDie} y llegó a ${_game.positions[_game.lastPlayer]}.', style: const TextStyle(color: Colors.white70), textAlign: TextAlign.center),
    const SizedBox(height: 12), FilledButton.icon(key: const ValueKey('race-roll'), onPressed: _game.finished ? null : () => _act(() => _game.roll()),
      icon: const Icon(Icons.casino_rounded), label: Text(_game.finished ? '¡Meta alcanzada!' : 'Tirar dado · ${_game.names[_game.turn]}')),
  ]);
}
