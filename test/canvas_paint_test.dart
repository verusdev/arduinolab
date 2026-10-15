import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:arduino_lab/i18n/app_lang.dart';
import 'package:arduino_lab/i18n/strings.dart';
import 'package:arduino_lab/models/circuit.dart';
import 'package:arduino_lab/models/component_type.dart';
import 'package:arduino_lab/state/app_state.dart';
import 'package:arduino_lab/ui/canvas/canvas_view.dart';

const Color _boardTeal = Color(0xFF0B3C49);
const Color _boardInner = Color(0xFF12556B);
const Color _wireBlue = Color(0xFF2F6FED);

Color _pixel(ByteData data, int width, int x, int y) {
  final i = (y * width + x) * 4;
  return Color.fromARGB(
    data.getUint8(i + 3),
    data.getUint8(i),
    data.getUint8(i + 1),
    data.getUint8(i + 2),
  );
}

bool _near(Color a, Color b, [int tolerance = 24]) {
  int d(double x, double y) => ((x * 255).round() - (y * 255).round()).abs();
  return d(a.r, b.r) <= tolerance &&
      d(a.g, b.g) <= tolerance &&
      d(a.b, b.b) <= tolerance;
}

/// True when [want] shows up anywhere in the column [x] between [y0] and [y1].
bool _columnHas(ByteData data, int width, int x, int y0, int y1, Color want) {
  for (var y = y0; y <= y1; y++) {
    if (_near(_pixel(data, width, x, y), want)) return true;
  }
  return false;
}

void main() {
  // The pixel samples below were taken with the English chrome, and the wiring
  // hint that floats over the canvas takes up more room in other languages, so
  // pin the language to keep this layering test deterministic.
  setUp(() => S.set(AppLang.en));

  testWidgets('a wire is drawn on top of the board its pin lives inside',
      (tester) async {
    const w = 600;
    tester.view.physicalSize = const Size(600, 400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final app = AppState();
    // Board at the top-left, LED to the right: the wire crosses the board body.
    app.addComponent(ComponentType.arduinoUno, 0, 120);
    app.addComponent(ComponentType.led, 400, 120);
    final uno = app.project.circuit.components.first;
    final led = app.project.circuit.components.last;
    app.project.circuit.wires.add(Wire(
      id: 'w1',
      aComponent: uno.id,
      aPin: 'D13',
      bComponent: led.id,
      bPin: 'A',
    ));

    final boundary = GlobalKey();
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: app,
        child: MaterialApp(
          home: RepaintBoundary(
            key: boundary,
            child: const SizedBox(
              width: 600,
              height: 400,
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
      // Both calls must happen in the real async zone: inside the test's fake
      // async zone the engine callbacks never fire and the test hangs.
      data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      image.dispose();
    });

    // Sanity: the board body really is painted where this test looks. The
    // sample sits on the board but well away from the wire's path.
    final boardPixel = _pixel(data, w, 246, 250);
    expect(
        _near(boardPixel, _boardTeal) || _near(boardPixel, _boardInner), isTrue,
        reason: 'board body should cover x=246, y=250 (got $boardPixel)');

    // D13 sits at (230.5, 132) and the LED's anode at (409, 166), so the wire
    // passes through x=241 while still over the board. If wires were painted
    // below the parts this column would hold nothing but board colour.
    expect(_columnHas(data, w, 241, 126, 140, _wireBlue), isTrue,
        reason: 'the wire must stay visible over the board body');
    expect(_columnHas(data, w, 241, 126, 140, _boardTeal), isTrue,
        reason: 'and the board must still be visible around it');

    // The same wire is of course visible once it leaves the board.
    expect(_columnHas(data, w, 320, 143, 156, _wireBlue), isTrue,
        reason: 'the wire should span the gap to the LED');
  });
}
