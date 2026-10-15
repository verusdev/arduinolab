import '../models/circuit.dart';

/// Disjoint-set union helper used to merge pins into electrical nets.
class _Dsu {
  final Map<String, String> _parent = {};

  Iterable<String> get keys => _parent.keys;

  bool contains(String x) => _parent.containsKey(x);

  void add(String x) {
    _parent.putIfAbsent(x, () => x);
  }

  String find(String x) {
    add(x);
    var root = x;
    while (_parent[root] != root) {
      root = _parent[root]!;
    }
    var cur = x;
    while (_parent[cur] != root) {
      final next = _parent[cur]!;
      _parent[cur] = root;
      cur = next;
    }
    return root;
  }

  void union(String a, String b) => _parent[find(a)] = find(b);
}

/// Result of merging every pin (through wires and implicit internal
/// connections) into electrical nets.
class Netlist {
  Netlist._(this._netOfPin, this.nets);

  final Map<String, int> _netOfPin;
  final List<Set<String>> nets;

  int get netCount => nets.length;

  int netOf(String componentId, String pinId) =>
      _netOfPin[Circuit.pinKey(componentId, pinId)] ?? -1;

  Iterable<String> pinsOfNet(int net) => nets[net];

  static Netlist build(Circuit circuit) {
    final dsu = _Dsu();
    for (final c in circuit.components) {
      for (final p in c.spec.pins) {
        dsu.add(Circuit.pinKey(c.id, p.id));
      }
      for (final group in c.spec.implicitGroups) {
        for (var i = 1; i < group.length; i++) {
          dsu.union(
              Circuit.pinKey(c.id, group[0]), Circuit.pinKey(c.id, group[i]));
        }
      }
    }
    for (final w in circuit.wires) {
      final ka = Circuit.pinKey(w.aComponent, w.aPin);
      final kb = Circuit.pinKey(w.bComponent, w.bPin);
      if (dsu.contains(ka) && dsu.contains(kb)) dsu.union(ka, kb);
    }

    final rootToIndex = <String, int>{};
    final nets = <Set<String>>[];
    final netOf = <String, int>{};
    for (final key in dsu.keys) {
      final root = dsu.find(key);
      var idx = rootToIndex[root];
      if (idx == null) {
        idx = nets.length;
        rootToIndex[root] = idx;
        nets.add(<String>{});
      }
      nets[idx].add(key);
      netOf[key] = idx;
    }
    return Netlist._(netOf, nets);
  }
}
