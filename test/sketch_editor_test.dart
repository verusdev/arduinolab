import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:arduino_lab/blocks/block_model.dart';
import 'package:arduino_lab/i18n/app_lang.dart';
import 'package:arduino_lab/i18n/strings.dart';
import 'package:arduino_lab/state/app_state.dart';
import 'package:arduino_lab/ui/widgets/sketch_editor.dart';

const _field = ValueKey('sketch.editor');

void main() {
  setUp(() => S.set(AppLang.en));
  tearDown(() => S.set(AppLang.ru));

  Future<AppState> pump(WidgetTester tester, {AppState? state}) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final app = state ?? AppState();
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: app,
        child: const MaterialApp(home: Scaffold(body: SketchEditor())),
      ),
    );
    await tester.pump();
    return app;
  }

  String shown(WidgetTester tester) =>
      tester.widget<TextField>(find.byKey(_field)).controller!.text;

  testWidgets('opens on the code the blocks printed', (tester) async {
    final app = await pump(
      tester,
      state: AppState()..addBlock(BlockKind.digitalWrite),
    );
    expect(shown(tester), app.sketchText);
    expect(shown(tester), contains('digitalWrite('));
  });

  testWidgets('typing a sketch builds the blocks', (tester) async {
    final app = await pump(tester);

    await tester.enterText(
        find.byKey(_field), 'void loop() {\n  digitalWrite(13, HIGH);\n}\n');
    await tester.pump();

    expect(app.project.program.loop.single.kind, BlockKind.digitalWrite);
    expect(app.project.program.loop.single.stringParam('value'), 'HIGH');
    expect(find.textContaining('Problems'), findsNothing);
  });

  testWidgets('code the blocks cannot hold is reported, and the blocks stay',
      (tester) async {
    final app = await pump(tester, state: AppState()..addBlock(BlockKind.wait));

    await tester.enterText(
        find.byKey(_field), 'void loop() {\n  frobnicate(1);\n}\n');
    await tester.pump();

    expect(app.project.program.loop.single.kind, BlockKind.wait);
    expect(find.textContaining('Problems: 1'), findsOneWidget);
    expect(find.textContaining('Line 2'), findsOneWidget);
    expect(find.textContaining('there is no block for this statement'),
        findsOneWidget);
  });

  testWidgets('rebuilding puts the blocks back into the text', (tester) async {
    await pump(tester, state: AppState()..addBlock(BlockKind.wait));
    await tester.enterText(
        find.byKey(_field), 'void loop() {\n  frobnicate(1);\n}\n');
    await tester.pump();

    await tester.tap(find.text('Rebuild from blocks'));
    await tester.pump();

    expect(shown(tester), isNot(contains('frobnicate')));
    expect(shown(tester), contains('delay('));
    expect(find.textContaining('Problems'), findsNothing);
  });

  testWidgets('a block added elsewhere lands in the text', (tester) async {
    final app = await pump(tester);

    app.addBlock(BlockKind.wait);
    await tester.pump();

    expect(shown(tester), contains('delay(1000);'));
  });

  testWidgets('an edit made elsewhere is not undone by a stale caret',
      (tester) async {
    final app = await pump(tester);
    await tester.enterText(find.byKey(_field), 'void loop() {\n  delay(t);\n}\n');
    await tester.pump();

    // The block side wins: the code is written out from the blocks again.
    app.addBlock(BlockKind.noTone);
    await tester.pump();

    expect(shown(tester), isNot(contains('delay(t)')));
    expect(shown(tester), contains('noTone('));
  });

  testWidgets('the popup offers what the word could become', (tester) async {
    await pump(tester);

    await tester.enterText(find.byKey(_field), 'digitalWri');
    await tester.pump();

    expect(find.text('digitalWrite('), findsOneWidget);
  });

  testWidgets('tab takes the suggestion', (tester) async {
    await pump(tester);
    await tester.enterText(find.byKey(_field), 'digitalWri');
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();

    expect(shown(tester), 'digitalWrite(');
  });

  testWidgets('escape closes the popup without touching the text',
      (tester) async {
    await pump(tester);
    await tester.enterText(find.byKey(_field), 'dig');
    await tester.pump();
    expect(find.textContaining('digitalWrite('), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    expect(find.textContaining('digitalWrite('), findsNothing);
    expect(shown(tester), 'dig');
  });

  testWidgets('the arrows move the choice', (tester) async {
    await pump(tester);
    await tester.enterText(find.byKey(_field), 'dig');
    await tester.pump();

    // The first row is digitalRead(; one step down is the next function.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();

    expect(shown(tester), isNot('dig'));
    expect(shown(tester), startsWith('digital'));
  });

  testWidgets('tab indents when there is nothing to complete', (tester) async {
    await pump(tester);
    await tester.enterText(find.byKey(_field), 'zz');
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();

    expect(shown(tester), 'zz  ');
  });
}
