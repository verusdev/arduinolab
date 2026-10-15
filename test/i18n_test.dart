import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:arduino_lab/blocks/block_catalog.dart';
import 'package:arduino_lab/examples/examples.dart';
import 'package:arduino_lab/i18n/app_lang.dart';
import 'package:arduino_lab/i18n/locale_controller.dart';
import 'package:arduino_lab/i18n/strings.dart';
import 'package:arduino_lab/main.dart';
import 'package:arduino_lab/models/component_type.dart';
import 'package:arduino_lab/state/app_state.dart';

void main() {
  tearDown(() => S.set(AppLang.ru));

  group('Catalogue', () {
    test('both languages define exactly the same keys', () {
      expect(S.ru.keys.toSet(), S.en.keys.toSet());
    });

    test('no translation is left empty', () {
      for (final entry in S.ru.entries) {
        expect(entry.value, isNotEmpty, reason: 'ru ${entry.key}');
      }
      for (final entry in S.en.entries) {
        expect(entry.value, isNotEmpty, reason: 'en ${entry.key}');
      }
    });

    test('English keeps the wording the original interface used', () {
      S.set(AppLang.en);
      expect(S.t('project.new'), 'New project');
      expect(S.t('tab.blocks'), 'Blocks');
      expect(S.t('tab.inspector'), 'Inspector');
      expect(S.t('component.led'), 'LED');
      expect(S.t('component.arduinoUno'), 'Arduino UNO');
      expect(S.t('inspector.notConnected'), 'Not connected');
      expect(S.t('category.Robotics').toUpperCase(), 'ROBOTICS');
    });

    test('Russian is the default language', () {
      expect(S.lang, AppLang.ru);
      expect(S.t('project.new'), 'Новый проект');
      expect(S.t('tab.blocks'), 'Блоки');
      expect(S.t('component.led'), 'Светодиод');
    });

    test('arguments are substituted', () {
      expect(S.t('arm.jointServo', {'n': 3}), 'J3 · сервопривод');
      expect(S.t('inspector.connections', {'n': 4}), 'Соединения (4)');
      expect(S.t('canvas.wireTitle', {'name': 'D13', 'pin': 'A0'}),
          contains('D13'));
    });

    test('an unknown key falls back to the key itself', () {
      expect(S.t('this.key.does.not.exist'), 'this.key.does.not.exist');
    });
  });

  group('Every key the app builds is defined', () {
    test('component and category keys', () {
      for (final type in ComponentType.values) {
        final spec = ComponentSpecs.of(type);
        expect(S.keys, contains('component.${type.name}'));
        expect(S.keys, contains('category.${spec.category}'));
      }
    });

    test('block and parameter keys', () {
      for (final def in BlockCatalog.all) {
        expect(S.keys, contains('blk.${def.kind.name}'),
            reason: 'block ${def.kind.name}');
        expect(S.keys, contains('blockcat.${def.category}'),
            reason: 'category ${def.category}');
        for (final param in def.params) {
          if (param.label.isEmpty) continue;
          expect(S.keys, contains('par.${param.label}'),
              reason: 'param ${param.label} of ${def.kind.name}');
        }
      }
    });

    test('lesson title, summary and every step', () {
      for (final example in Examples.all) {
        expect(S.keys, contains('lesson.${example.id}.title'));
        expect(S.keys, contains('lesson.${example.id}.summary'));
        for (var i = 0; i < example.steps.length; i++) {
          expect(S.keys, contains('lesson.${example.id}.s${i + 1}'),
              reason: '${example.id} step ${i + 1}');
        }
      }
    });

    test('every literal S.t key in lib has a catalogue entry', () {
      // A key that is missing from the table silently falls back to the key
      // itself, so the dialog would read "examples.title". Guard against that
      // by scanning the source for literal keys; interpolated keys are covered
      // by the checks above.
      final usage = RegExp(r"S\.t\('([^'$]+)'");
      final missing = <String>{};
      final seen = <String>{};
      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        if (entity.path.replaceAll(r'\', '/').contains('lib/i18n/')) continue;
        for (final match in usage.allMatches(entity.readAsStringSync())) {
          final key = match.group(1)!;
          seen.add(key);
          if (!S.keys.contains(key)) missing.add('$key  (${entity.path})');
        }
      }
      // Make sure the scan really found the UI's keys, so the check below
      // cannot pass by accident on an empty match.
      expect(seen, contains('tab.blocks'));
      expect(seen.length, greaterThan(50));
      expect(missing, isEmpty);
    });
  });

  group('Language switcher', () {
    testWidgets('starts in Russian and switches to English', (tester) async {
      tester.view.physicalSize = const Size(1600, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      S.set(AppLang.ru);
      final locale = LocaleController();
      await tester.pumpWidget(ArduinoLabApp(locale: locale));
      await tester.pump();

      // Russian by default: tabs, palette header and a component name.
      expect(find.text('Блоки'), findsOneWidget);
      expect(find.text('Инспектор'), findsOneWidget);
      expect(find.text('КОМПОНЕНТЫ'), findsOneWidget);
      expect(find.text('Светодиод'), findsOneWidget);

      // Open the language menu and pick English.
      await tester.tap(find.text('RU'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(CheckedPopupMenuItem<AppLang>, 'English'),
      );
      await tester.pumpAndSettle();

      expect(S.lang, AppLang.en);
      expect(find.text('Blocks'), findsOneWidget);
      expect(find.text('Inspector'), findsOneWidget);
      expect(find.text('COMPONENTS'), findsOneWidget);
      expect(find.text('LED'), findsOneWidget);
      // The old wording is gone.
      expect(find.text('Блоки'), findsNothing);
      expect(find.text('Светодиод'), findsNothing);
    });
  });

  test('a loaded lesson is named after itself in the active language', () {
    S.set(AppLang.ru);
    final app = AppState()..loadExample('blink');
    expect(app.project.circuit.components, isNotEmpty);
    expect(app.project.name, 'Мигание');
  });
}
