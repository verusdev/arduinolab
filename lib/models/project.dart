import '../blocks/block_model.dart';
import 'circuit.dart';

/// A saved workspace: schematic + block program + view state.
class Project {
  Project({
    this.name = 'Untitled',
    Circuit? circuit,
    BlockProgram? program,
    this.panX = 0,
    this.panY = 0,
    this.zoom = 1,
    this.tutorialId,
  })  : circuit = circuit ?? Circuit(),
        program = program ?? BlockProgram();

  static const int schemaVersion = 1;

  String name;
  Circuit circuit;
  BlockProgram program;
  double panX;
  double panY;
  double zoom;
  String? tutorialId;

  Project copy() => Project(
        name: name,
        circuit: circuit.copy(),
        program: program.copy(),
        panX: panX,
        panY: panY,
        zoom: zoom,
        tutorialId: tutorialId,
      );

  Map<String, Object?> toJson() => {
        'schemaVersion': schemaVersion,
        'name': name,
        'circuit': circuit.toJson(),
        'program': program.toJson(),
        'view': {'panX': panX, 'panY': panY, 'zoom': zoom},
        'tutorialId': tutorialId,
      };

  factory Project.fromJson(Map<String, Object?> j) {
    final view = (j['view'] as Map?)?.cast<String, Object?>() ?? const {};
    return Project(
      name: j['name'] as String? ?? 'Untitled',
      circuit: Circuit.fromJson(
          (j['circuit'] as Map?)?.cast<String, Object?>() ?? const {}),
      program: BlockProgram.fromJson(
          (j['program'] as Map?)?.cast<String, Object?>() ?? const {}),
      panX: (view['panX'] as num?)?.toDouble() ?? 0,
      panY: (view['panY'] as num?)?.toDouble() ?? 0,
      zoom: (view['zoom'] as num?)?.toDouble() ?? 1,
      tutorialId: j['tutorialId'] as String?,
    );
  }
}
