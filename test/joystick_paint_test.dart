import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:arduino_lab/models/component_type.dart';
import 'package:arduino_lab/state/app_state.dart';
import 'package:arduino_lab/ui/canvas/canvas_view.dart';

// The colours the joystick is drawn with.
const Color _bodyColour = Color(0xFF1B3A5C);
const Color _bootColour = Color(0xFF0E2338);
const Color _knobColour = Color(0xFFCFD8DC);
const Color _knobCore = Color(0xFF37474F);
const Color _padColour = Color(0xFF7FA8C9);
const Color _padHeld = Color(0xFFEF6C00);

const double _canvasWidth = 800;
const double _canvasHeight = 600;

/// The module's top-left corner on the workspace. The canvas maps 1:1 onto the
/// widget, so a point [dx], [dy] of the component is at the pixel
/// ([dx] + [_base].dx, [dy] + [_base].dy).
const Offset _base = Offset(300, 300);

int _px(double local) => (_base.dx + local).round();
int _py(double local) => (_base.dy + local).round();

Color _pixel(ByteData data, double dx, double dy) {
  final i = (_py(dy) * _canvasWidth.toInt() + _px(dx)) * 4;
  return Color.fromARGB(data.getUint8(i + 3), data.getUint8(i),
      data.getUint8(i + 1), data.getUint8(i + 2));
}

/// How many pixels of the component's own space, from ([left], [top]) to
/// ([right], [bottom]), carry [colour].
int _count(ByteData data, Color colour, double left, double top, double right,
    double bottom) {
  var found = 0;
  for (var y = top.round(); y <= bottom.round(); y++) {
    for (var x = left.round(); x <= right.round(); x++) {
      if (_near(_pixel(data, x.toDouble(), y.toDouble()), colour)) found++;
    }
  }
  return found;
}

bool _near(Color a, Color b, [int tolerance = 24]) {
  int d(double x, double y) => ((x * 255).round() - (y * 255).round()).abs();
  return d(a.r, b.r) <= tolerance &&
      d(a.g, b.g) <= tolerance &&
      d(a.b, b.b) <= tolerance;
}

/// Paints one joystick with its stick at ([x], [y]) and returns the pixels.
Future<ByteData> _render(
    WidgetTester tester, double x, double y, bool held) async {
  tester.view.physicalSize = const Size(_canvasWidth, _canvasHeight);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final app = AppState();
  app.addComponent(ComponentType.joystick, _base.dx, _base.dy);
  final id = app.project.circuit.components.single.id;
  app.setJoystick(id, x, y);
  app.setButtonPressed(id, held);

  final boundary = GlobalKey();
  await tester.pumpWidget(
    ChangeNotifierProvider<AppState>.value(
      value: app,
      child: MaterialApp(
        home: RepaintBoundary(
          key: boundary,
          child: const SizedBox(
            width: _canvasWidth,
            height: _canvasHeight,
            child: CanvasView(),
          ),
        ),
      ),
    ),
  );
  await tester.pump();

  late ByteData data;
  await tester.runAsync(() async {
    final render =
        boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await render.toImage();
    data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    image.dispose();
  });
  return data;
}

void main() {
  testWidgets('the stick is drawn where the wipers put it', (tester) async {
    // Untouched: the knob covers the middle of the boot.
    final centred = await _render(tester, 0.5, 0.5, false);
    expect(_near(_pixel(centred, 32, 27), _knobCore), isTrue,
        reason: 'knob centre with the stick untouched');

    // Pushed to the top right: the knob goes with it and leaves the old spot.
    final pushed = await _render(tester, 1, 1, false);
    expect(_near(_pixel(pushed, 42, 17), _knobCore), isTrue,
        reason: 'knob centre at the far end of the travel');
    expect(_near(_pixel(pushed, 22, 37), _knobColour), isFalse,
        reason: 'the knob must not be left behind at the other end');
  });

  testWidgets('the boot and the body are painted around the stick',
      (tester) async {
    final data = await _render(tester, 0.5, 0.5, false);

    expect(_near(_pixel(data, 46, 27), _bootColour), isTrue,
        reason: 'the boot beside the knob');
    expect(_near(_pixel(data, 56, 20), _bodyColour), isTrue,
        reason: 'the module body at its top right corner');
  });

  testWidgets('the SW pad lights up while it is held', (tester) async {
    final free = await _render(tester, 0.5, 0.5, false);
    final held = await _render(tester, 0.5, 0.5, true);

    // The pad is only a few pixels tall and its label covers the middle, so
    // count what it paints rather than trusting a single sample.
    const left = 2.0, top = 2.0, right = 19.0, bottom = 14.0;
    final open = _count(free, _padColour, left, top, right, bottom);
    expect(open, greaterThan(10),
        reason: 'the pad is pale blue while the button is open');
    expect(_count(held, _padHeld, left, top, right, bottom), greaterThan(10),
        reason: 'and orange while it is pressed');
    expect(open > _count(held, _padColour, left, top, right, bottom), isTrue,
        reason: 'the pad stops being pale blue once it is held');
  });
}
