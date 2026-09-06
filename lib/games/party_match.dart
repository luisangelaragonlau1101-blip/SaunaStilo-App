import 'dart:math';

/// Local, pass-and-play rules. No account, network, rewards or company records.
enum PartyKind { memory, territory, race }

class PartyMatch {
  final PartyKind kind;
  final List<String> names;
  final List<int> deck;
  final List<int> claimed;
  final List<int> edges;
  final List<int> boxes;
  final List<int> positions;
  int turn = 0, first = -1, second = -1, lastDie = 0, lastPlayer = -1, moves = 0;
  static const finish = 30;
  static const boosts = {4: 3, 10: 2, 15: -3, 22: 2, 27: -2};

  PartyMatch(this.kind, List<String> players, {Random? random})
      : names = List.unmodifiable(players),
        deck = List.generate(24, (i) => i ~/ 2)..shuffle(random ?? Random()),
        claimed = List.filled(24, -1),
        edges = List.filled(24, -1),
        boxes = List.filled(9, -1),
        positions = List.filled(players.length, 0) {
    if (players.length < (kind == PartyKind.memory ? 1 : 2) || players.length > 4 ||
        players.any((n) => n.trim().isEmpty || n.length > 24)) {
      throw ArgumentError('Elige de ${kind == PartyKind.memory ? 1 : 2} a 4 jugadores.');
    }
  }
  int get players => names.length;
  bool get waiting => kind == PartyKind.memory && second != -1;
  bool get finished => switch (kind) {
    PartyKind.memory => claimed.every((p) => p >= 0),
    PartyKind.territory => boxes.every((p) => p >= 0),
    PartyKind.race => positions.any((p) => p == finish),
  };
  List<int> get scores => List.generate(players, (p) => switch (kind) {
    PartyKind.memory => claimed.where((v) => v == p).length ~/ 2,
    PartyKind.territory => boxes.where((v) => v == p).length,
    PartyKind.race => positions[p],
  });
  List<int> get winners {
    if (!finished) return [];
    final points = scores, best = scores.reduce(max);
    return [for (var p = 0; p < players; p++) if (points[p] == best) p];
  }
  bool faceUp(int i) => claimed[i] >= 0 || i == first || i == second;
  void flip(int i) {
    if (kind != PartyKind.memory || finished || waiting || i < 0 || i >= 24 || claimed[i] >= 0 || first == i) {
      throw StateError('Esa carta no está disponible.');
    }
    if (first == -1) { first = i; return; }
    second = i; moves++;
    if (deck[first] == deck[second]) {
      claimed[first] = turn; claimed[second] = turn;
      first = -1; second = -1;
    }
  }
  void nextMemoryTurn() {
    if (!waiting) throw StateError('Todavía no hay un par por ocultar.');
    first = -1; second = -1; turn = (turn + 1) % players;
  }
  static List<int> boxEdges(int box) {
    final row = box ~/ 3, col = box % 3;
    return [row * 3 + col, (row + 1) * 3 + col, 12 + row * 4 + col, 12 + row * 4 + col + 1];
  }
  void drawEdge(int edge) {
    if (kind != PartyKind.territory || finished || edge < 0 || edge >= 24 || edges[edge] != -1) {
      throw StateError('Elige una línea libre.');
    }
    edges[edge] = turn; moves++;
    var gained = false;
    for (var i = 0; i < 9; i++) {
      if (boxes[i] < 0 && boxEdges(i).every((e) => edges[e] >= 0)) {
        boxes[i] = turn; gained = true;
      }
    }
    if (!gained) turn = (turn + 1) % players;
  }
  void roll({Random? random, int? die}) {
    if (kind != PartyKind.race || finished) throw StateError('La carrera terminó.');
    final value = die ?? (random ?? Random()).nextInt(6) + 1;
    if (value < 1 || value > 6) throw ArgumentError('Dado inválido.');
    lastDie = value; lastPlayer = turn; moves++;
    var target = min(finish, positions[turn] + value);
    if (target < finish) target = (target + (boosts[target] ?? 0)).clamp(0, finish);
    positions[turn] = target;
    if (!finished) turn = (turn + 1) % players;
  }
  Map<String, dynamic> toJson() => {
    'v': 1, 'kind': kind.name, 'names': names, 'deck': deck, 'claimed': claimed,
    'edges': edges, 'boxes': boxes, 'positions': positions, 'turn': turn,
    'first': first, 'second': second, 'lastDie': lastDie, 'lastPlayer': lastPlayer, 'moves': moves,
  };
  static PartyMatch fromJson(Map<String, dynamic> data) {
    if (data['v'] != 1) throw const FormatException('Versión de partida no compatible.');
    final kind = PartyKind.values.byName(data['kind'] as String);
    final m = PartyMatch(kind, List<String>.from(data['names'] as List), random: Random(0));
    void load(String key, List<int> target, int low, int high) {
      final values = List<int>.from(data[key] as List);
      if (values.length != target.length || values.any((n) => n < low || n > high)) {
        throw const FormatException('Partida local inválida.');
      }
      target.setAll(0, values);
    }
    int field(String key, int low, int high) {
      final n = data[key];
      if (n is! int || n < low || n > high) throw const FormatException('Turno inválido.');
      return n;
    }
    load('deck', m.deck, 0, 11); load('claimed', m.claimed, -1, m.players - 1);
    load('edges', m.edges, -1, m.players - 1); load('boxes', m.boxes, -1, m.players - 1);
    load('positions', m.positions, 0, finish);
    m.turn = field('turn', 0, m.players - 1); m.first = field('first', -1, 23);
    m.second = field('second', -1, 23); m.lastDie = field('lastDie', 0, 6);
    m.lastPlayer = field('lastPlayer', -1, m.players - 1); m.moves = field('moves', 0, 1000000);
    for (var value = 0; value < 12; value++) {
      final pair = [for (var i = 0; i < 24; i++) if (m.deck[i] == value) i];
      if (pair.length != 2 || m.claimed[pair[0]] != m.claimed[pair[1]]) {
        throw const FormatException('Pares inválidos.');
      }
    }
    if (m.first >= 0 && m.claimed[m.first] >= 0 ||
        m.second >= 0 && (m.first < 0 || m.first == m.second || m.claimed[m.second] >= 0 || m.deck[m.first] == m.deck[m.second])) {
      throw const FormatException('Cartas abiertas inválidas.');
    }
    for (var b = 0; b < 9; b++) {
      if ((m.boxes[b] >= 0) != boxEdges(b).every((e) => m.edges[e] >= 0)) {
        throw const FormatException('Territorio inválido.');
      }
    }
    return m;
  }
}
