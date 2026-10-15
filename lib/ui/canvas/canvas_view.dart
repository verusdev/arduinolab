import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/circuit.dart';
import '../../models/component_type.dart';
import '../../state/app_state.dart';
import 'component_painter.dart';
import 'component_visual.dart';

/// The interactive workspace: grid, wires and draggable components.
class CanvasView extends StatelessWidget {
  const CanvasView({super.key});

  static const double canvasWidth = 2400;
  static const double canvasHeight = 1600;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Container(
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
              Positioned.fill(
                child: CustomPaint(
                  painter: _WiresPainter(
                    circuit: app.project.circuit,
                    selectedWire: app.selectedWireId,
                    pending: app.pendingWire,
                  ),
                ),
              ),
              for (final c in app.project.circuit.components)
                _ComponentNode(key: ValueKey(c.id), id: c.id),
            ],
          ),
        ),
      ),
    );
  }
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
    final grid = Paint()..color = const Color(0xFFE9EEF3);
    for (var x = 0.0; x < size.width; x += 40) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (var y = 0.0; y < size.height; y += 40) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    for (final wire in circuit.wires) {
      final a = circuit.componentById(wire.aComponent);
      final b = circuit.componentById(wire.bComponent);
      if (a == null || b == null) continue;
      final pa = a.pinPositionById(wire.aPin);
      final pb = b.pinPositionById(wire.bPin);
      _drawWire(
        canvas,
        Offset(pa.$1, pa.$2),
        Offset(pb.$1, pb.$2),
        Color(wire.color),
        wire.id == selectedWire ? 5 : 3,
      );
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
    final pendingPin = app.pendingWire?.componentId == component.id
        ? app.pendingWire?.pinId
        : null;

    return Positioned(
      left: component.x,
      top: component.y,
      width: component.width,
      height: component.height,
      child: Transform.rotate(
        angle: component.rotation * math.pi / 180.0,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            app.selectComponent(component.id);
            if (component.type == ComponentType.pushButton) {
              app.setButtonPressed(
                  component.id, !app.isButtonPressed(component.id));
            }
          },
          onDoubleTap: () => app.rotateComponent(component.id),
          onLongPress: () => app.deleteComponent(component.id),
          onPanUpdate: (details) => app.moveComponent(component.id,
              component.x + details.delta.dx, component.y + details.delta.dy),
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
                  ),
                ),
              ),
              for (final pin in component.spec.pins)
                Positioned(
                  left: pin.dx - 9,
                  top: pin.dy - 9,
                  width: 18,
                  height: 18,
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
