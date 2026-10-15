import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:arduino_lab/main.dart';
import 'package:arduino_lab/state/app_state.dart';
import 'package:arduino_lab/ui/widgets/palette.dart';

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
}
