import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../engine/robotics.dart';
import '../../models/circuit.dart';
import '../../models/component_type.dart';
import '../../models/geometry.dart';
import '../../state/app_state.dart';
import 'component_painter.dart';
import 'component_visual.dart';

/// The interactive workspace: grid, wires and draggable components.
class CanvasView extends StatelessWidget {
  const CanvasView({super.key});

  static const double canvasWidth = kWorkspaceWidth;
  static const double canvasHeight = kWorkspaceHeight;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Stack(
      children: [
        Positioned.fill(
          child: Container(
            color: const Color(0xFFFBFCFD),
            child: InteractiveViewer(
              constrained: false,
              boundaryMargin: const EdgeInsets.all(800),
              minScale: 0.3,
              maxScale: 2.5,
              child: SizedBox(
                width: canvasWidth,
                height: canvasHeight,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(painter: _GridPainter()),
                      ),
                    ),
                    for (final c in app.project.circuit.components)
                      _ComponentNode(key: ValueKey(c.id), id: c.id),
                    // Wires sit above the parts: every board pin lives inside
                    // the board body, so a wire drawn underneath would vanish
                    // under the board instead of landing on its pin.
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _WiresPainter(
                            circuit: app.project.circuit,
                            selectedWire: app.selectedWireId,
                            pending: app.pendingWire,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const Positioned(left: 12, top: 12, child: _WiringHint()),
      ],
    );
  }
}

/// Smallest gap between two pins of [type], used to size each pin's tap target
/// so densely packed headers stay individually selectable.
final Map<ComponentType, double> _pinHitCache = <ComponentType, double>{};

double _pinHitSize(ComponentType type) =>
    _pinHitCache.putIfAbsent(type, () {
      final pins = ComponentSpecs.of(type).pins;
      var best = 24.0;
      for (var i = 0; i < pins.length; i++) {
        for (var j = i + 1; j < pins.length; j++) {
          final d = (pins[i].dx - pins[j].dx).abs() +
              (pins[i].dy - pins[j].dy).abs();
          if (d < best) best = d;
        }
      }
      return best.clamp(10.0, 24.0);
    });

/// The dotted work grid, painted beneath every part.
class _GridPainter extends CustomPainter {
  const _GridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()..color = const Color(0xFFE9EEF3);
    for (var x = 0.0; x < size.width; x += 40) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (var y = 0.0; y < size.height; y += 40) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter old) => false;
}

class _WiresPainter extends CustomPainter {
  _WiresPainter({
    required this.circuit,
    required this.selectedWire,
    required this.pending,
  });

  final Circuit circuit;
  final String? selectedWire;
  final PendingWire? pending;

  @override
  void paint(Canvas canvas, Size size) {
    // Several wires may meet on one pin; the terminal is drawn only once.
    final terminated = <String>{};

    for (final wire in circuit.wires) {
      final a = circuit.componentById(wire.aComponent);
      final b = circuit.componentById(wire.bComponent);
      if (a == null || b == null) continue;
      final pa = a.pinPositionById(wire.aPin);
      final pb = b.pinPositionById(wire.bPin);
      final color = Color(wire.color);
      _drawWire(
        canvas,
        Offset(pa.$1, pa.$2),
        Offset(pb.$1, pb.$2),
        color,
        wire.id == selectedWire ? 5 : 3,
      );
      _terminal(canvas, circuit, wire.aComponent, wire.aPin, color, terminated);
      _terminal(canvas, circuit, wire.bComponent, wire.bPin, color, terminated);
    }

    final start = pending;
    if (start != null) {
      final c = circuit.componentById(start.componentId);
      if (c != null) {
        final p = c.pinPositionById(start.pinId);
        canvas.drawCircle(
          Offset(p.$1, p.$2),
          10,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = const Color(0xFFFF9800),
        );
      }
    }
  }

  /// Marks the exact pin a wire lands on, in the wire's own colour, so the
  /// connection stays readable wherever the wire runs.
  void _terminal(Canvas canvas, Circuit circuit, String componentId,
      String pinId, Color color, Set<String> terminated) {
    if (!terminated.add('$componentId:$pinId')) return;
    final component = circuit.componentById(componentId);
    if (component == null) return;
    final p = component.pinPositionById(pinId);
    final at = Offset(p.$1, p.$2);
    canvas.drawCircle(at, 3.6, Paint()..color = color);
    canvas.drawCircle(
      at,
      3.6,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Colors.white,
    );
  }

  void _drawWire(Canvas canvas, Offset a, Offset b, Color color, double width) {
    final bend = math.max(24.0, (b.dx - a.dx).abs() * 0.4);
    final dir = b.dx >= a.dx ? 1.0 : -1.0;
    final path = Path()
      ..moveTo(a.dx, a.dy)
      ..cubicTo(a.dx + bend * dir, a.dy, b.dx - bend * dir, b.dy, b.dx, b.dy);
    canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = width + 2.5
          ..strokeCap = StrokeCap.round
          ..color = Colors.white);
    canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round
          ..color = color);
  }

  @override
  bool shouldRepaint(covariant _WiresPainter old) => true;
}

/// A floating banner that explains, and tracks, the two-tap wiring gesture.
class _WiringHint extends StatelessWidget {
  const _WiringHint();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final pending = app.pendingWire;

    if (pending == null) {
      return const _HintCard(
        icon: Icons.ads_click,
        title: 'Tap a pin, then tap another pin to draw a wire',
        subtitle: 'Double-tap a part to rotate · long-press to delete',
      );
    }

    final component = app.project.circuit.componentById(pending.componentId);
    return _HintCard(
      icon: Icons.cable,
      title: 'From ${component?.spec.label ?? '?'} · ${pending.pinId}'
          ' — now tap the target pin',
      subtitle: 'Orange pins are ready to connect · tap it again to cancel',
      highlight: true,
      onCancel: app.cancelWire,
    );
  }
}

class _HintCard extends StatelessWidget {
  const _HintCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.highlight = false,
    this.onCancel,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool highlight;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 3,
      borderRadius: BorderRadius.circular(10),
      color: highlight ? const Color(0xFFFFF3E0) : Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 330),
        child: Padding(
          padding: EdgeInsets.fromLTRB(12, 8, onCancel == null ? 12 : 4, 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 18,
                  color: highlight
                      ? const Color(0xFFEF6C00)
                      : const Color(0xFF546E7A)),
              const SizedBox(width: 10),
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: const TextStyle(
                            fontSize: 11, color: Colors.black54)),
                  ],
                ),
              ),
              if (onCancel != null)
                IconButton(
                  tooltip: 'Cancel wire',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: onCancel,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ComponentNode extends StatelessWidget {
  const _ComponentNode({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final component = app.project.circuit.componentById(id);
    if (component == null) return const SizedBox.shrink();
    final visual = ComponentVisual.of(app, component);
    final selected = app.selectedComponentId == component.id;
    final wiring = app.pendingWire != null;
    final pendingPin = app.pendingWire?.componentId == component.id
        ? app.pendingWire?.pinId
        : null;
    final hit = _pinHitSize(component.type);
    // A car that is driving is positioned by the physics each frame, so letting
    // the user drag or rotate it would just fight the simulation.
    final driving =
        app.running && component.type == ComponentType.robotCar;
    // Parts of a built-up arm turn about their own pivot, not about the middle
    // of the box, so a bolted joint swings the way the physics says it does.
    final mount = component.spec.mount;
    final alignment = mount == null
        ? Alignment.center
        : Alignment(
            component.width == 0 ? 0 : mount.pivotX / (component.width / 2) - 1,
            component.height == 0 ? 0 : mount.pivotY / (component.height / 2) - 1,
          );
    // Only a free-standing part can be spun by hand; a bolted one is oriented
    // by the chain it hangs off.
    final rotatable = !driving &&
        (mount == null || ArmAssembly.parentOf(component) == null);

    return Positioned(
      left: component.x,
      top: component.y,
      width: component.width,
      height: component.height,
      child: Transform.rotate(
        angle: component.rotation * math.pi / 180.0,
        alignment: alignment,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            app.selectComponent(component.id);
            if (component.type == ComponentType.pushButton) {
              app.setButtonPressed(
                  component.id, !app.isButtonPressed(component.id));
            }
          },
          onDoubleTap:
              rotatable ? () => app.rotateComponent(component.id) : null,
          onLongPress: () => app.deleteComponent(component.id),
          // Dragging an arm part pulls it off the chain first, so it (and
          // everything bolted above it) follows the finger; letting go bolts it
          // onto whatever socket it landed nearest.
          onPanStart: driving || mount == null
              ? null
              : (_) => app.detachArmPart(component.id),
          onPanEnd: driving || mount == null
              ? null
              : (_) => app.dropArmPart(component.id),
          onPanUpdate: driving
              ? null
              : (details) => app.moveComponent(component.id,
                  component.x + details.delta.dx,
                  component.y + details.delta.dy),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: ComponentPainter(
                    component: component,
                    visual: visual,
                    selected: selected,
                    pendingPinId: pendingPin,
                    wiring: wiring,
                  ),
                ),
              ),
              for (final pin in component.spec.pins)
                Positioned(
                  left: pin.dx - hit / 2,
                  top: pin.dy - hit / 2,
                  width: hit,
                  height: hit,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => app.tapPin(component.id, pin.id),
                    child: const SizedBox.expand(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
