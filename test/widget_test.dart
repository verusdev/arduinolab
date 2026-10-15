import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:arduino_lab/main.dart';
import 'package:arduino_lab/models/circuit.dart';
import 'package:arduino_lab/models/component_type.dart';
import 'package:arduino_lab/state/app_state.dart';
import 'package:arduino_lab/ui/widgets/palette.dart';
import 'package:arduino_lab/ui/widgets/properties_panel.dart';

void main() {
  testWidgets('app boots into the workspace', (tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ArduinoLabApp());
    await tester.pump();

    expect(find.text('New project'), findsOneWidget);
    expect(find.text('Run'), findsOneWidget);
    expect(find.byType(Palette), findsOneWidget);
    expect(find.text('Blocks'), findsOneWidget);
    expect(find.text('Inspector'), findsOneWidget);
  });

  testWidgets('tapping a palette entry places a component', (tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ArduinoLabApp());
    await tester.pump();

    final app = Provider.of<AppState>(
      tester.element(find.byType(Palette)),
      listen: false,
    );
    expect(app.project.circuit.components, isEmpty);

    await tester.tap(find.text('LED'));
    await tester.pump();

    expect(app.project.circuit.components, hasLength(1));
  });

  testWidgets('canvas explains the two-tap wiring gesture', (tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ArduinoLabApp());
    await tester.pump();

    expect(find.textContaining('draw a wire'), findsOneWidget);
  });

  testWidgets('inspector prints every sensor pin and its connections',
      (tester) async {
    final app = AppState()
      ..addComponent(ComponentType.ultrasonic, 100, 100);

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: app,
        child: const MaterialApp(home: Scaffold(body: PropertiesPanel())),
      ),
    );
    await tester.pump();

    expect(find.text('VCC'), findsOneWidget);
    expect(find.text('TRIG'), findsOneWidget);
    expect(find.text('ECHO'), findsOneWidget);
    expect(find.text('GND'), findsOneWidget);
    expect(find.text('Not connected'), findsNWidgets(4));
    // The distance slider is still reachable above the pin list.
    expect(find.text('Distance'), findsOneWidget);
  });

  testWidgets('inspector reports what a pin is wired to', (tester) async {
    final app = AppState();
    app.addComponent(ComponentType.arduinoUno, 0, 0);
    app.addComponent(ComponentType.ultrasonic, 400, 100);

    final uno = app.project.circuit.components.first;
    final sensor = app.project.circuit.components.last;
    app.project.circuit.wires.add(
      Wire(
        id: 'w-test',
        aComponent: sensor.id,
        aPin: 'TRIG',
        bComponent: uno.id,
        bPin: 'D7',
      ),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: app,
        child: const MaterialApp(home: Scaffold(body: PropertiesPanel())),
      ),
    );
    await tester.pump();

    expect(find.textContaining('Arduino UNO · D7'), findsOneWidget);
    expect(find.text('Not connected'), findsNWidgets(3));
  });
}
