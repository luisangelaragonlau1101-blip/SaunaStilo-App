import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:saunastilo/games/party_match.dart';
import 'package:saunastilo/games/party_store.dart';
import 'package:saunastilo/screens/local_party_screen.dart';

void main() {
  final four = ['Ana', 'Beto', 'Caro', 'Dani'];
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('counts, names and invalid rolls cannot corrupt a match', () {
    expect(() => PartyMatch(PartyKind.race, ['Uno']), throwsArgumentError);
    expect(() => PartyMatch(PartyKind.memory, List.filled(5, 'X')), throwsArgumentError);
    expect(() => PartyMatch(PartyKind.memory, ['']), throwsArgumentError);
    final g = PartyMatch(PartyKind.race, four);
    expect(() => g.roll(die: 7), throwsArgumentError);
    expect(g.moves, 0);
  });
  test('four-player memory rotates on misses and preserves matched-pair turn', () {
    final g = PartyMatch(PartyKind.memory, four, random: Random(7));
    final miss = g.deck.indexWhere((v) => v != g.deck[0]);
    for (var p = 0; p < 4; p++) {
      expect(g.turn, p); g.flip(0); g.flip(miss);
      expect(g.waiting, true); expect(() => g.flip(3), throwsStateError);
      g.nextMemoryTurn();
    }
    expect(g.turn, 0);
    for (var pair = 0; pair < 12; pair++) {
      final ids = [for (var i = 0; i < 24; i++) if (g.deck[i] == pair) i];
      g.flip(ids[0]); expect(() => g.flip(ids[0]), throwsStateError); g.flip(ids[1]);
    }
    expect(g.finished, true); expect(g.scores, [12, 0, 0, 0]); expect(g.winners, [0]);
    expect(() => g.flip(0), throwsStateError);
  });
  test('territory rotates all four and a closing move keeps its owner turn', () {
    final g = PartyMatch(PartyKind.territory, four);
    g.drawEdge(0); g.drawEdge(3); g.drawEdge(12);
    expect(g.turn, 3); g.drawEdge(13);
    expect(g.boxes[0], 3); expect(g.turn, 3); expect(g.scores[3], 1);
    expect(() => g.drawEdge(13), throwsStateError);
    for (var e = 0; e < 24; e++) { if (g.edges[e] < 0) g.drawEdge(e); }
    expect(g.finished, true); expect(g.scores.reduce((a, b) => a + b), 9);
    expect(g.winners, isNotEmpty);
  });
  test('four-person race rotates, applies boosts and stops at the finish', () {
    final g = PartyMatch(PartyKind.race, four);
    for (var p = 0; p < 4; p++) { expect(g.turn, p); g.roll(die: 4); expect(g.positions[p], 7); }
    final random = Random(24);
    for (var i = 0; i < 1000 && !g.finished; i++) { g.roll(random: random); }
    expect(g.finished, true); expect(g.winners.length, 1);
    expect(g.positions.every((p) => p >= 0 && p <= 30), true);
    expect(() => g.roll(), throwsStateError);
  });
  test('every game survives an offline save including an open memory mismatch', () async {
    for (final kind in PartyKind.values) {
      final g = PartyMatch(kind, four, random: Random(1));
      switch (kind) {
        case PartyKind.memory: g.flip(0); g.flip(g.deck.indexWhere((v) => v != g.deck[0]));
        case PartyKind.territory: g.drawEdge(7);
        case PartyKind.race: g.roll(die: 3);
      }
      await PartyStore.save(g); final restored = await PartyStore.read();
      expect(restored!.toJson(), g.toJson());
    }
  });
  test('serial writes preserve the newest turn and malformed saves are rejected', () async {
    final g = PartyMatch(PartyKind.race, four);
    final writes = <Future<void>>[];
    for (var i = 0; i < 4; i++) { g.roll(die: 2); writes.add(PartyStore.save(g)); }
    await Future.wait(writes); expect((await PartyStore.read())!.moves, 4);
    expect(() => PartyMatch.fromJson({...g.toJson(), 'turn': 9}), throwsFormatException);
    expect(() => PartyMatch.fromJson({...g.toJson(), 'deck': [1, 1]}), throwsFormatException);
    final prefs = await SharedPreferences.getInstance(); await prefs.setString(PartyStore.key, 'not JSON');
    await expectLater(PartyStore.read(), throwsFormatException);
  });
  for (final kind in PartyKind.values) {
    testWidgets('${kind.name} plays with four people at 320px without Firebase', (tester) async {
      tester.view.physicalSize = const Size(320, 850); tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize); addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(theme: ThemeData.dark(useMaterial3: true), home: LocalPartyBoard(match: PartyMatch(kind, four))));
      await tester.pumpAndSettle();
      final target = find.byKey(ValueKey(switch (kind) { PartyKind.memory => 'memory-card-0', PartyKind.territory => 'territory-edge-0', PartyKind.race => 'race-roll' }));
      await tester.ensureVisible(target); await tester.tap(target); await tester.pumpAndSettle();
      expect(find.textContaining('Dani'), findsOneWidget); expect(tester.takeException(), isNull);
    });
  }
  testWidgets('lobby offers three games and starts four-player setup with optional names', (tester) async {
    await tester.pumpWidget(MaterialApp(theme: ThemeData.dark(useMaterial3: true), home: const LocalPartyScreen()));
    await tester.pumpAndSettle();
    final target = find.byKey(const ValueKey('party-select-memory'));
    await tester.ensureVisible(target); await tester.tap(target); await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('party-count-4'))); await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNWidgets(4));
    final start = find.byKey(const ValueKey('party-start')); await tester.ensureVisible(start); await tester.tap(start); await tester.pumpAndSettle();
    expect(find.byType(LocalPartyBoard), findsOneWidget); expect(find.textContaining('Jugador 4'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
