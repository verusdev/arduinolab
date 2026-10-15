import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:arduino_lab/engine/robotics.dart';
import 'package:arduino_lab/i18n/app_lang.dart';
import 'package:arduino_lab/i18n/strings.dart';
import 'package:arduino_lab/main.dart';
import 'package:arduino_lab/examples/examples.dart';
import 'package:arduino_lab/models/circuit.dart';
import 'package:arduino_lab/models/component_type.dart';
import 'package:arduino_lab/state/app_state.dart';
import 'package:arduino_lab/ui/widgets/palette.dart';
import 'package:arduino_lab/ui/widgets/properties_panel.dart';

void main() {
  // The interface ships in Russian by default; these tests assert the English
  // wording, so they pin the language for the whole file.
  setUp(() => S.set(AppLang.en));

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

  testWidgets('the palette offers the robotics parts', (tester) async {
    // A tall window so the whole palette is laid out and every entry can be
    // tapped without scrolling.
    tester.view.physicalSize = const Size(1600, 1700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ArduinoLabApp());
    await tester.pump();

    final app = Provider.of<AppState>(
      tester.element(find.byType(Palette)),
      listen: false,
    );

    expect(find.text('ROBOTICS'), findsOneWidget);
    expect(find.text('Robot Car 4WD'), findsOneWidget);
    expect(find.text('Robot Arm'), findsOneWidget);
    expect(find.text('Arm Base'), findsOneWidget);
    expect(find.text('Arm Link'), findsOneWidget);
    expect(find.text('Arm Gripper'), findsOneWidget);

    await tester.tap(find.text('Robot Car 4WD'));
    await tester.pump();

    expect(app.project.circuit.components, hasLength(1));
    expect(app.project.circuit.components.single.type, ComponentType.robotCar);

    // An arm part drops in the same way, so the kit can be built up by hand.
    await tester.tap(find.text('Arm Link'));
    await tester.pump();
    expect(app.project.circuit.components, hasLength(2));
    expect(app.project.circuit.components.last.type, ComponentType.armLink);
  });

  testWidgets('inspector shows robot car telemetry', (tester) async {
    final app = AppState()..addComponent(ComponentType.robotCar, 100, 100);

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: app,
        child: const MaterialApp(home: Scaffold(body: PropertiesPanel())),
      ),
    );
    await tester.pump();

    expect(find.text('Wall sensors'), findsOneWidget);
    // One line per wheel, plus both rangefinders.
    for (final wheel in const [
      'M1 front-left',
      'M2 front-right',
      'M3 rear-left',
      'M4 rear-right',
    ]) {
      expect(find.text(wheel), findsOneWidget);
    }
    expect(find.text('Sensor ahead'), findsOneWidget);
    expect(find.text('Sensor behind'), findsOneWidget);
    expect(find.text('100 cm'), findsNWidgets(2));
  });

  testWidgets('inspector configures each robot arm joint', (tester) async {
    final app = AppState()..addComponent(ComponentType.robotArm, 100, 100);

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: app,
        child: const MaterialApp(home: Scaffold(body: PropertiesPanel())),
      ),
    );
    await tester.pump();

    expect(find.text('Segments'), findsOneWidget);
    // The default four segment arm is a shoulder, an elbow, a wrist and jaws.
    for (var j = 1; j <= 4; j++) {
      expect(find.text(j == 4 ? 'J$j · gripper servo' : 'J$j · servo'),
          findsOneWidget);
    }
    expect(find.text('J4 · gripper servo'), findsOneWidget);
    expect(find.text('J5 · servo'), findsNothing, reason: 'only four segments');
    expect(find.textContaining('Fit a servo'), findsOneWidget);
  });

  testWidgets('running the robot car lesson actually drives it', (tester) async {
    final app = AppState();
    addTearDown(app.dispose);
    app.replaceProject(Examples.byId('robot_car')!.build());

    final car = app.project.circuit.components
        .firstWhere((c) => c.type == ComponentType.robotCar);
    final startX = car.x;

    app.run();
    await tester.pump();
    // Let the 16 ms simulation timer fire a hundred or so times.
    await tester.pump(const Duration(milliseconds: 1600));
    app.stop();

    expect(car.x, greaterThan(startX), reason: 'the car drives forward');
    expect(car.rotation, closeTo(0, 1), reason: 'the road ahead is clear');
    // The onboard sensor keeps writing a live reading into the properties.
    final distance = (car.properties['distance'] as num).toDouble();
    expect(distance, lessThan(300));
    expect(distance, greaterThan(0));
  });

  testWidgets('Reset parks the car back where Run started it', (tester) async {
    final app = AppState();
    addTearDown(app.dispose);
    app.replaceProject(Examples.byId('robot_car')!.build());

    final car = app.project.circuit.components
        .firstWhere((c) => c.type == ComponentType.robotCar);
    final startX = car.x;
    final startY = car.y;

    app.run();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1200));
    final drove = car.x;
    app.stop();

    app.resetSimulation();
    await tester.pump();

    expect(drove, isNot(startX), reason: 'it moved during the run');
    expect(car.x, startX);
    expect(car.y, startY);
    expect(car.rotation, 0);
    // Every wheel stops where it started, ready for another run.
    for (var i = 1; i <= 4; i++) {
      expect(car.properties['phase$i'], 0.0);
    }
  });

  testWidgets('a servo can be bolted into an arm and swings it', (tester) async {
    final app = AppState();
    addTearDown(app.dispose);
    app.replaceProject(Examples.byId('robot_arm_kit')!.build());

    final base = app.project.circuit.componentById('base')!;
    final link1 = app.project.circuit.componentById('link1')!;
    // The kit arrives already assembled, standing straight up.
    expect(link1.y, lessThan(base.y));
    expect(link1.rotation, 0);

    app.run();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    app.stop();

    expect(link1.rotation, isNot(0),
        reason: 'the shoulder servo swings the link above it');
  });

  testWidgets('a dropped arm part bolts onto the socket it landed on',
      (tester) async {
    final app = AppState();
    addTearDown(app.dispose);
    app.replaceProject(Examples.byId('robot_arm_kit')!.build());
    final circuit = app.project.circuit;
    final link1 = circuit.componentById('link1')!;

    // Pull the elbow off, which takes the rest of the arm with it.
    app.detachArmPart('elbow');
    expect(ArmAssembly.parentOf(circuit.componentById('elbow')!), isNull);
    expect(ArmAssembly.parentOf(circuit.componentById('link2')!), 'elbow');

    // Drop it straight back onto the socket on top of the first link.
    final socket = ArmAssembly.socketWorld(link1);
    app.moveComponent('elbow', socket.$1 - 30, socket.$2 - 30);
    app.dropArmPart('elbow');

    expect(ArmAssembly.parentOf(circuit.componentById('elbow')!), 'link1');
    // And the whole arm is one chain again.
    expect(ArmAssembly.pivotWorld(circuit.componentById('elbow')!), socket);
    expect(ArmAssembly.pivotWorld(circuit.componentById('link2')!),
        ArmAssembly.socketWorld(circuit.componentById('elbow')!));
  });

  testWidgets('deleting a part leaves the rest of the arm where it was',
      (tester) async {
    final app = AppState();
    addTearDown(app.dispose);
    app.replaceProject(Examples.byId('robot_arm_kit')!.build());
    final circuit = app.project.circuit;
    final link1 = circuit.componentById('link1')!;
    final before = (link1.x, link1.y, link1.rotation);

    app.deleteComponent('shoulder');

    // The link is freed but does not move: it is still the arm it was.
    expect(ArmAssembly.parentOf(link1), isNull);
    expect((link1.x, link1.y, link1.rotation), before);
  });
}
