import 'app_lang.dart';

/// Every user-visible string in the app, in both languages.
///
/// Strings are looked up by a stable key rather than by their English text, so
/// adding a language never means hunting through the widgets. Widgets and the
/// data files (component specs, block catalog, lessons) all call [S.t]; the
/// catalogue holds *keys*, and the text is resolved when it is drawn.
///
/// A placeholder in a string is written `{name}` and filled in by passing a map
/// to [S.t], e.g. `S.t('arm.jointServo', {'n': 3})`.
class S {
  S._();

  /// The language new strings are resolved in. Defaults to Russian; the stored
  /// choice is applied at start-up by `LocaleController`.
  static AppLang _lang = AppLang.ru;

  static AppLang get lang => _lang;

  /// Switches the catalogue. Callers that need a repaint are responsible for
  /// notifying their listeners (`LocaleController` does that for the app).
  static void set(AppLang lang) => _lang = lang;

  static String t(String key, [Map<String, Object?>? args]) {
    final table = _lang == AppLang.ru ? ru : en;
    var value = table[key] ?? en[key] ?? key;
    if (args != null && args.isNotEmpty) {
      args.forEach((name, replacement) {
        value = value.replaceAll('{$name}', '$replacement');
      });
    }
    return value;
  }

  /// Keys that exist in both tables; used by the tests to keep them in step.
  static Set<String> get keys => en.keys.toSet();

  // ------------------------------------------------------------------ english

  static const Map<String, String> en = {
    // App bar.
    'bar.components': 'Components',
    'bar.resetSimulation': 'Reset simulation',
    'bar.examples': 'Examples & lessons',
    'bar.project': 'Project',
    'bar.run': 'Run',
    'bar.stop': 'Stop',
    'bar.language': 'Language',

    // Project menu.
    'menu.examples': 'Examples & lessons',
    'menu.rename': 'Rename project',
    'menu.saveToSlot': 'Save to slot...',
    'menu.openSlot': 'Open slot…',
    'menu.exportJson': 'Export JSON…',
    'menu.importJson': 'Import JSON…',
    'menu.newProject': 'New project',

    // Dialogs.
    'common.cancel': 'Cancel',
    'common.close': 'Close',
    'common.delete': 'Delete',
    'common.copy': 'Copy',
    'common.save': 'Save',
    'common.rename': 'Rename',
    'common.import': 'Import',
    'dialog.rename.title': 'Rename project',
    'dialog.rename.field': 'Project name',
    'dialog.new.title': 'New project?',
    'dialog.new.body':
        'Unsaved changes to the current project will be lost.',
    'dialog.new.action': 'Start new',
    'dialog.save.title': 'Save project',
    'dialog.save.slot': 'Slot name',
    'dialog.save.slots': 'Saved slots',
    'dialog.open.title': 'Open project',
    'dialog.open.empty': 'No saved projects yet.',
    'dialog.export.title': 'Project JSON',
    'dialog.import.title': 'Import project JSON',
    'dialog.import.hint': 'Paste exported JSON here',
    'dialog.paste': 'Paste',

    // Examples dialog.
    'examples.title': 'Examples & lessons',
    'examples.load': 'Load this example',

    // Tabs.
    'tab.blocks': 'Blocks',
    'tab.sketch': 'Sketch',
    'tab.serial': 'Serial',
    'tab.inspector': 'Inspector',

    // Palette.
    'palette.title': 'COMPONENTS',
    'category.Boards': 'Boards',
    'category.Output': 'Output',
    'category.Basic': 'Basic',
    'category.Input': 'Input',
    'category.Display': 'Display',
    'category.Sensors': 'Sensors',
    'category.Robotics': 'Robotics',

    // Components.
    'component.arduinoUno': 'Arduino UNO',
    'component.breadboard': 'Breadboard',
    'component.led': 'LED',
    'component.rgbLed': 'RGB LED',
    'component.resistor': 'Resistor',
    'component.pushButton': 'Push Button',
    'component.potentiometer': 'Potentiometer',
    'component.servo': 'Servo Motor',
    'component.buzzer': 'Piezo Buzzer',
    'component.lcd16x2': 'LCD 16x2 (I2C)',
    'component.ultrasonic': 'Ultrasonic HC-SR04',
    'component.dht11': 'DHT11 Temp/Humidity',
    'component.photoresistor': 'Photoresistor',
    'component.joystick': 'Joystick',
    'component.robotCar': 'Robot Car 4WD',
    'component.robotArm': 'Robot Arm',
    'component.armBase': 'Arm Base',
    'component.armLink': 'Arm Link',
    'component.armGripper': 'Arm Gripper',

    // Inspector.
    'inspector.nothingSelected': 'Nothing selected.',
    'inspector.nothingSelectedHint':
        'Tap a part to inspect it. Its pin names are printed on the canvas — '
            'tap one pin, then another pin, to draw a wire between them.',
    'inspector.sc.doubleTap': 'Double-tap',
    'inspector.sc.doubleTapText': 'rotate the part',
    'inspector.sc.longPress': 'Long-press',
    'inspector.sc.longPressText': 'delete the part',
    'inspector.sc.drag': 'Drag',
    'inspector.sc.dragText': 'move the part',
    'inspector.rotate90': 'Rotate 90°',
    'inspector.connections': 'Connections ({n})',
    'inspector.pinHint': 'Tap a pin to start a wire from it.',
    'inspector.warnings': 'Warnings',
    'inspector.wires': 'Wires ({n})',
    'inspector.noWires': 'No wires yet.',
    'inspector.notConnected': 'Not connected',
    'inspector.deleteWire': 'Delete wire',
    'inspector.noProperties': 'No adjustable properties.',

    // Robot car.
    'car.wallSensors': 'Wall sensors',
    'car.wallSensorsHint':
        'The front and rear rangefinders track the walls themselves',
    'car.distanceAhead': 'Distance ahead',
    'car.distanceBehind': 'Distance behind',
    'car.wheel1': 'M1 front-left',
    'car.wheel2': 'M2 front-right',
    'car.wheel3': 'M3 rear-left',
    'car.wheel4': 'M4 rear-right',
    'car.heading': 'Heading',
    'car.sensorAhead': 'Sensor ahead',
    'car.sensorBehind': 'Sensor behind',

    // Robot arm.
    'arm.hint':
        'Fit a servo to the joints you want to drive; every other joint '
            'holds the angle you dial in by hand.',
    'arm.segments': 'Segments',
    'arm.jointServo': 'J{n} · servo',
    'arm.jointGripper': 'J{n} · gripper servo',
    'arm.jointGripperSub': 'Opens and closes the jaws',
    'arm.jointSub': 'Drives segment {n} off pin J{n}',
    'arm.jointCommanded': 'J{n} commanded',
    'arm.jointRest': 'J{n} rest angle',
    'arm.roleBase': 'Pedestal. Bolt a servo or a link onto the socket on top.',
    'arm.roleLink':
        'One segment. Its foot swings on whatever it is bolted to.',
    'arm.roleGripper':
        'Jaws. Bolt a servo onto its socket to open and close them.',
    'arm.boltedTo': 'Bolted to',
    'arm.nothing': 'nothing yet',
    'arm.angle': 'Angle',
    'arm.jaws': 'Jaws',
    'arm.jawsOpen': '{value} open',
    'arm.unbolt': 'Unbolt',

    // Generic component properties.
    'prop.pressed': 'Pressed',
    'prop.resistance': 'Resistance',
    'prop.knob': 'Knob',
    'prop.lightLevel': 'Light level',
    'prop.stick': 'Stick position',
    'prop.axisX': 'X axis (VRX)',
    'prop.axisY': 'Y axis (VRY)',
    'prop.axisValue': '{percent}% · {volts} V',
    'prop.centre': 'Back to the centre',
    'prop.swPressed': 'SW pressed',
    'prop.distance': 'Distance',
    'prop.temperature': 'Temperature',
    'prop.humidity': 'Humidity',
    'prop.colour': 'Colour',

    // Block editor.
    'block.setup': 'Setup',
    'block.loop': 'Loop',
    'block.empty':
        'No blocks yet.\nTap "Add block" to start building your program.',
    'block.addBlock': 'Add block',
    'block.else': 'else',
    'block.do': 'do',
    'block.add': 'add',
    'block.emptyBody': '(empty)',
    'block.moveUp': 'Move up',
    'block.moveDown': 'Move down',
    'block.delete': 'Delete',

    // Block categories (the keys the catalogue groups by).
    'blockcat.Control': 'Control',
    'blockcat.Pins': 'Pins',
    'blockcat.Variables': 'Variables',
    'blockcat.Serial': 'Serial',
    'blockcat.Components': 'Components',
    'blockcat.Sensors': 'Sensors',
    'blockcat.Display': 'Display',

    // Block names.
    'blk.wait': 'wait',
    'blk.repeatTimes': 'repeat',
    'blk.forever': 'forever',
    'blk.ifDo': 'if … then',
    'blk.ifElse': 'if … then / else',
    'blk.setPinMode': 'set pin mode',
    'blk.digitalWrite': 'digital write',
    'blk.analogWrite': 'analog write (PWM)',
    'blk.setVar': 'set',
    'blk.changeVar': 'change',
    'blk.serialBegin': 'Serial begin',
    'blk.serialPrint': 'Serial print',
    'blk.serialPrintln': 'Serial println',
    'blk.servoWrite': 'servo write',
    'blk.tone': 'play tone',
    'blk.noTone': 'stop tone',
    'blk.lcdInit': 'LCD init',
    'blk.lcdClear': 'LCD clear',
    'blk.lcdSetCursor': 'LCD cursor',
    'blk.lcdPrint': 'LCD print',
    'blk.readUltrasonic': 'read distance (cm)',
    'blk.readTemperature': 'read temperature',
    'blk.readHumidity': 'read humidity',

    // Block parameter labels.
    'par.ms': 'ms',
    'par.times': 'times',
    'par.pin': 'pin',
    'par.mode': 'mode',
    'par.value': 'value',
    'par.value 0-255': 'value 0-255',
    'par.name': 'name',
    'par.to': 'to',
    'par.by': 'by',
    'par.baud': 'baud',
    'par.angle': 'angle',
    'par.hz': 'hz',
    'par.into': 'into',
    'par.trig': 'trig',
    'par.echo': 'echo',
    'par.col': 'col',
    'par.row': 'row',

    // Value editor kinds (the function names stay as written in the sketch).
    'val.number': 'number',
    'val.variable': 'variable',
    'val.text': 'text',
    'val.analogRead': 'analogRead',
    'val.digitalRead': 'digitalRead',
    'val.millis': 'millis',

    // Sketch editor.
    'sketch.title': 'Sketch',
    'sketch.copy': 'Copy',
    'sketch.copied': 'Sketch copied',
    'sketch.rebuild': 'Rebuild from blocks',
    'sketch.hint': 'Write the sketch here — the blocks follow along',
    'sketch.errors': 'Problems: {count} — the blocks were left as they were',
    'sketch.line': 'Line {line}',

    // Why a stretch of sketch could not be turned into blocks.
    'parse.noSections': 'no setup() or loop() to read',
    'parse.unknownStatement': 'there is no block for this statement',
    'parse.unknownFunction': 'there is no block for this function',
    'parse.expectedToken': 'the statement is unfinished',
    'parse.unexpectedToken': 'stray text outside any statement',
    'parse.badDelay': 'a wait needs a plain number of milliseconds',
    'parse.badFor': 'only a "repeat N times" loop has a block',
    'parse.badWhile': 'only a "forever" loop (while true) has a block',
    'parse.badCondition': 'the condition could not be read',
    'parse.badExpression': 'the expression could not be read',
    'parse.badPin': 'this is not a pin',
    'parse.badValue': 'this value is not accepted here',
    'parse.badName': 'this is not a name',
    'parse.unterminated': 'the sketch ends before the block is closed',

    // Serial monitor.
    'serial.title': 'Serial monitor',
    'serial.clear': 'Clear',
    'serial.empty': '(no output yet — press Run)',

    // Canvas hints.
    'canvas.hintTitle': 'Tap a pin, then tap another pin to draw a wire',
    'canvas.hintSubtitle':
        'Double-tap a part to rotate · long-press to delete',
    'canvas.wireTitle': 'From {name} · {pin} — now tap the target pin',
    'canvas.wireSubtitle':
        'Orange pins are ready to connect · tap it again to cancel',
    'canvas.cancelWire': 'Cancel wire',

    // Silkscreen printed on the parts themselves.
    'silk.robotCar': 'ROBOT CAR 4WD',
    'silk.robotArm': 'ROBOT ARM',
    'silk.base': 'BASE',
    'silk.joystick': 'KY-023',
    'silk.digital': 'DIGITAL',
    'silk.analogPower': 'ANALOG / POWER',

    // Snack bar messages.
    'msg.addBlocks': 'Add blocks to your program first.',
    'msg.placeArduino': 'Place an Arduino UNO on the board to run.',
    'msg.newProject': 'New project created.',
    'msg.loadedExample': 'Loaded example "{title}".',
    'msg.savedSlot': 'Saved to slot "{slot}".',
    'msg.slotEmpty': 'Slot "{slot}" is empty.',
    'msg.openedSlot': 'Opened slot "{slot}".',
    'msg.imported': 'Project imported.',
    'msg.importFailed': 'Import failed: {error}',

    // Default project name.
    'project.new': 'New project',

    // Solver warnings.
    'warn.ledCurrent':
        'LED {id} draws too much current; add a resistor.',
    'warn.ultrasonicEcho': 'Wire the ultrasonic ECHO pin to a digital pin.',
    'warn.dhtData': 'Wire the DHT11 DATA pin to a digital pin.',

    // Lessons.
    'lesson.blink.title': 'Blink',
    'lesson.blink.summary': 'Classic: turn an LED on and off every second.',
    'lesson.blink.s1': 'LED anode goes through a 220 Ω resistor to pin D13.',
    'lesson.blink.s2': 'LED cathode goes to GND.',
    'lesson.blink.s3': 'Every second the pin alternates HIGH and LOW.',

    'lesson.button_led.title': 'Button + LED',
    'lesson.button_led.summary':
        'Read a push button and mirror its state on an LED.',
    'lesson.button_led.s1':
        'Wire the button between D2 and GND and use INPUT_PULLUP.',
    'lesson.button_led.s2': 'if (digitalRead(2) == 0) the button is pressed.',
    'lesson.button_led.s3':
        'Mirror the state on the LED connected to D13.',

    'lesson.pot_led.title': 'Potentiometer dims an LED',
    'lesson.pot_led.summary':
        'Read an analog input and use it to dim an LED with PWM.',
    'lesson.pot_led.s1':
        'Potentiometer outer legs to 5V and GND, wiper to A0.',
    'lesson.pot_led.s2': 'analogRead(A0) returns 0..1023.',
    'lesson.pot_led.s3':
        'map() scales it to 0..255 for analogWrite on D9.',

    'lesson.joystick_servo.title': 'Joystick steers a servo',
    'lesson.joystick_servo.summary':
        'Read both axes of a joystick and aim a servo with them.',
    'lesson.joystick_servo.s1':
        'The joystick is two potentiometers and a button on one module: VCC and '
        'GND to the board, VRX to A0, and SW to D2.',
    'lesson.joystick_servo.s2':
        'analogRead(A0) returns 0 at one end of the X travel, 1023 at the '
        'other, and about 512 with the stick untouched.',
    'lesson.joystick_servo.s3':
        'Wire VRY to a spare analog pin to read the Y axis the same way.',
    'lesson.joystick_servo.s4':
        'SW is a button to GND, so INPUT_PULLUP makes digitalRead(2) read 0 '
        'while the stick is pushed in.',
    'lesson.joystick_servo.s5':
        'Drag the stick on the board: the servo follows the X axis and the LED '
        'lights up when you push the stick in.',

    'lesson.servo_sweep.title': 'Servo sweep',
    'lesson.servo_sweep.summary': 'Sweep a servo motor from 0° to 180° and back.',
    'lesson.servo_sweep.s1':
        'Wire the servo signal pin to D9 (PWM), plus 5V and GND.',
    'lesson.servo_sweep.s2':
        'servo write moves the horn to the requested angle.',

    'lesson.buzzer_melody.title': 'Buzzer melody',
    'lesson.buzzer_melody.summary':
        'Play a three note melody with a piezo buzzer.',
    'lesson.buzzer_melody.s1': 'Buzzer + to D8, buzzer - to GND.',
    'lesson.buzzer_melody.s2':
        'tone(pin, hz) starts a note, noTone(pin) stops it.',

    'lesson.lcd_hello.title': 'LCD hello',
    'lesson.lcd_hello.summary':
        'Print a greeting on a 16x2 I2C character display.',
    'lesson.lcd_hello.s1': 'LCD SDA/SCL go to A4/A5, plus 5V and GND.',
    'lesson.lcd_hello.s2':
        'lcd init wakes the display up, then print text.',

    'lesson.ultrasonic.title': 'Ultrasonic distance',
    'lesson.ultrasonic.summary':
        'Measure distance with an HC-SR04 and print it to the Serial monitor.',
    'lesson.ultrasonic.s1': 'TRIG to D7, ECHO to D6, plus 5V and GND.',
    'lesson.ultrasonic.s2':
        'Drag the distance slider to change the measured value.',
    'lesson.ultrasonic.s3': 'The result appears in the Serial monitor.',

    'lesson.dht11.title': 'Temperature & humidity',
    'lesson.dht11.summary': 'Read a DHT11 sensor and print the temperature.',
    'lesson.dht11.s1': 'DHT DATA to D2, plus 5V and GND.',
    'lesson.dht11.s2':
        'Use the sliders to change temperature and humidity.',

    'lesson.robot_car.title': 'Robot car 4WD: avoid the walls',
    'lesson.robot_car.summary':
        'Drive a four wheel drive car and steer it away from the border.',
    'lesson.robot_car.s1':
        'Each motor has its own direction pair A/B and its own enable: '
            'M1A/M1B/EN1 to D4/D7/D3, M2A/M2B/EN2 to D8/D12/D5, '
            'M3A/M3B/EN3 to D10/D11/D6, M4A/M4B/EN4 to D13/D2/D9.',
    'lesson.robot_car.s2':
        'M1 is front-left, M2 front-right, M3 rear-left, M4 rear-right, so the '
            'left pair is M1+M3 and the right pair M2+M4.',
    'lesson.robot_car.s3':
        'The nose is the front: the wall it measures is the edge of the board.',
    'lesson.robot_car.s4':
        'The rear rangefinder is wired to A2/A3 as well - read it with another '
            '"read distance" block to add a reverse gear.',
    'lesson.robot_car.s5':
        'Press Run: it drives forward and spins on the spot before the edge.',

    'lesson.robot_arm.title': 'Robot arm: pick and place',
    'lesson.robot_arm.summary':
        'Swing a segmented arm through a pick and place cycle.',
    'lesson.robot_arm.s1':
        'J1-J4 to D3/D5/D6/D9, plus 5V and GND. Each joint is one servo.',
    'lesson.robot_arm.s2':
        'Set how many segments the arm has in the Inspector, and fit a servo '
            'to the joints you want the program to drive.',
    'lesson.robot_arm.s3':
        'The last joint works the jaws, so J4 opens and closes the gripper.',
    'lesson.robot_arm.s4':
        'A joint with no servo just holds the angle you dial in by hand, so '
            'you can pose the arm and animate one joint at a time.',
    'lesson.robot_arm.s5': 'Press Run to replay the pick and place cycle.',

    'lesson.robot_arm_kit.title': 'Robot arm: build it out of parts',
    'lesson.robot_arm_kit.summary':
        'Bolt a pedestal, two links and a gripper together, '
            'with a servo at the joint that has to move.',
    'lesson.robot_arm_kit.s1':
        'Drag an Arm Base, an Arm Link, an Arm Gripper and Servo Motors onto '
            'the board. Every part has a gold socket where the next one goes.',
    'lesson.robot_arm_kit.s2':
        'Drag a part so its foot lands on a socket and let go: it snaps on and '
            'stays put. Drag it again to pull it off.',
    'lesson.robot_arm_kit.s3':
        'A servo bolted into a joint swings everything above it by the angle '
            'you write to its signal pin - that is what makes it an arm.',
    'lesson.robot_arm_kit.s4':
        'A servo bolted onto the gripper\'s socket works the jaws: 0 shuts '
            'them, 180 opens them wide.',
    'lesson.robot_arm_kit.s5':
        'Wiring: the shoulder servo is on D3, the elbow on D5, the jaws on D6.',
    'lesson.robot_arm_kit.s6':
        'Press Run to sweep the arm and work the gripper.',
  };

  // ------------------------------------------------------------------ russian

  static const Map<String, String> ru = {
    // App bar.
    'bar.components': 'Компоненты',
    'bar.resetSimulation': 'Сбросить симуляцию',
    'bar.examples': 'Примеры и уроки',
    'bar.project': 'Проект',
    'bar.run': 'Запустить',
    'bar.stop': 'Остановить',
    'bar.language': 'Язык',

    // Project menu.
    'menu.examples': 'Примеры и уроки',
    'menu.rename': 'Переименовать проект',
    'menu.saveToSlot': 'Сохранить в слот…',
    'menu.openSlot': 'Открыть слот…',
    'menu.exportJson': 'Экспорт JSON…',
    'menu.importJson': 'Импорт JSON…',
    'menu.newProject': 'Новый проект',

    // Dialogs.
    'common.cancel': 'Отмена',
    'common.close': 'Закрыть',
    'common.delete': 'Удалить',
    'common.copy': 'Копировать',
    'common.save': 'Сохранить',
    'common.rename': 'Переименовать',
    'common.import': 'Импортировать',
    'dialog.rename.title': 'Переименовать проект',
    'dialog.rename.field': 'Имя проекта',
    'dialog.new.title': 'Новый проект?',
    'dialog.new.body':
        'Несохранённые изменения текущего проекта будут потеряны.',
    'dialog.new.action': 'Начать заново',
    'dialog.save.title': 'Сохранить проект',
    'dialog.save.slot': 'Имя слота',
    'dialog.save.slots': 'Сохранённые слоты',
    'dialog.open.title': 'Открыть проект',
    'dialog.open.empty': 'Пока нет сохранённых проектов.',
    'dialog.export.title': 'JSON проекта',
    'dialog.import.title': 'Импорт JSON проекта',
    'dialog.import.hint': 'Вставьте сюда экспортированный JSON',
    'dialog.paste': 'Вставить',

    // Examples dialog.
    'examples.title': 'Примеры и уроки',
    'examples.load': 'Загрузить пример',

    // Tabs.
    'tab.blocks': 'Блоки',
    'tab.sketch': 'Скетч',
    'tab.serial': 'Порт',
    'tab.inspector': 'Инспектор',

    // Palette.
    'palette.title': 'КОМПОНЕНТЫ',
    'category.Boards': 'Платы',
    'category.Output': 'Выходы',
    'category.Basic': 'Базовые',
    'category.Input': 'Входы',
    'category.Display': 'Дисплей',
    'category.Sensors': 'Датчики',
    'category.Robotics': 'Роботы',

    // Components.
    'component.arduinoUno': 'Arduino UNO',
    'component.breadboard': 'Макетная плата',
    'component.led': 'Светодиод',
    'component.rgbLed': 'RGB-светодиод',
    'component.resistor': 'Резистор',
    'component.pushButton': 'Кнопка',
    'component.potentiometer': 'Потенциометр',
    'component.servo': 'Сервопривод',
    'component.buzzer': 'Пьезо-зуммер',
    'component.lcd16x2': 'Дисплей LCD 16x2 (I2C)',
    'component.ultrasonic': 'Дальномер HC-SR04',
    'component.dht11': 'DHT11 (темп./влажн.)',
    'component.photoresistor': 'Фоторезистор',
    'component.joystick': 'Джойстик',
    'component.robotCar': 'Машинка 4WD',
    'component.robotArm': 'Механическая рука',
    'component.armBase': 'Основание руки',
    'component.armLink': 'Звено руки',
    'component.armGripper': 'Захват руки',

    // Inspector.
    'inspector.nothingSelected': 'Ничего не выбрано.',
    'inspector.nothingSelectedHint':
        'Коснитесь детали, чтобы её настроить. Имена её контактов подписаны на '
            'рабочем поле — коснитесь одного контакта, затем другого, чтобы '
            'проложить между ними провод.',
    'inspector.sc.doubleTap': 'Двойной клик',
    'inspector.sc.doubleTapText': 'повернуть деталь',
    'inspector.sc.longPress': 'Долгое нажатие',
    'inspector.sc.longPressText': 'удалить деталь',
    'inspector.sc.drag': 'Перетаскивание',
    'inspector.sc.dragText': 'переместить деталь',
    'inspector.rotate90': 'Повернуть на 90°',
    'inspector.connections': 'Соединения ({n})',
    'inspector.pinHint': 'Коснитесь контакта, чтобы начать от него провод.',
    'inspector.warnings': 'Предупреждения',
    'inspector.wires': 'Провода ({n})',
    'inspector.noWires': 'Проводов пока нет.',
    'inspector.notConnected': 'Не подключено',
    'inspector.deleteWire': 'Удалить провод',
    'inspector.noProperties': 'Нет настраиваемых свойств.',

    // Robot car.
    'car.wallSensors': 'Датчики стен',
    'car.wallSensorsHint':
        'Передний и задний дальномеры сами измеряют стены',
    'car.distanceAhead': 'Расстояние спереди',
    'car.distanceBehind': 'Расстояние сзади',
    'car.wheel1': 'M1 перед-лево',
    'car.wheel2': 'M2 перед-право',
    'car.wheel3': 'M3 зад-лево',
    'car.wheel4': 'M4 зад-право',
    'car.heading': 'Курс',
    'car.sensorAhead': 'Датчик спереди',
    'car.sensorBehind': 'Датчик сзади',

    // Robot arm.
    'arm.hint':
        'Установите сервопривод в те суставы, которыми хотите управлять; '
            'остальные суставы держат угол, заданный вручную.',
    'arm.segments': 'Сегменты',
    'arm.jointServo': 'J{n} · сервопривод',
    'arm.jointGripper': 'J{n} · сервопривод захвата',
    'arm.jointGripperSub': 'Открывает и закрывает челюсти',
    'arm.jointSub': 'Двигает сегмент {n} через пин J{n}',
    'arm.jointCommanded': 'J{n}: команда',
    'arm.jointRest': 'J{n}: угол покоя',
    'arm.roleBase':
        'Основание. Прикрутите сервопривод или звено к гнезду сверху.',
    'arm.roleLink':
        'Одно звено. Его основание поворачивается на том, к чему оно прикручено.',
    'arm.roleGripper':
        'Челюсти. Прикрутите сервопривод к гнезду, чтобы их открывать и закрывать.',
    'arm.boltedTo': 'Прикручено к',
    'arm.nothing': 'пока ни к чему',
    'arm.angle': 'Угол',
    'arm.jaws': 'Челюсти',
    'arm.jawsOpen': '{value} открыто',
    'arm.unbolt': 'Отцепить',

    // Generic component properties.
    'prop.pressed': 'Нажата',
    'prop.resistance': 'Сопротивление',
    'prop.knob': 'Ручка',
    'prop.lightLevel': 'Уровень света',
    'prop.stick': 'Положение ручки',
    'prop.axisX': 'Ось X (VRX)',
    'prop.axisY': 'Ось Y (VRY)',
    'prop.axisValue': '{percent}% · {volts} В',
    'prop.centre': 'Вернуть в центр',
    'prop.swPressed': 'Кнопка SW',
    'prop.distance': 'Расстояние',
    'prop.temperature': 'Температура',
    'prop.humidity': 'Влажность',
    'prop.colour': 'Цвет',

    // Block editor.
    'block.setup': 'Настройка',
    'block.loop': 'Цикл',
    'block.empty':
        'Блоков пока нет.\nНажмите «Добавить блок», чтобы начать собирать '
            'программу.',
    'block.addBlock': 'Добавить блок',
    'block.else': 'иначе',
    'block.do': 'выполнить',
    'block.add': 'добавить',
    'block.emptyBody': '(пусто)',
    'block.moveUp': 'Вверх',
    'block.moveDown': 'Вниз',
    'block.delete': 'Удалить',

    // Block categories (the keys the catalogue groups by).
    'blockcat.Control': 'Управление',
    'blockcat.Pins': 'Пины',
    'blockcat.Variables': 'Переменные',
    'blockcat.Serial': 'Порт',
    'blockcat.Components': 'Компоненты',
    'blockcat.Sensors': 'Датчики',
    'blockcat.Display': 'Дисплей',

    // Block names.
    'blk.wait': 'ждать',
    'blk.repeatTimes': 'повторить',
    'blk.forever': 'всегда',
    'blk.ifDo': 'если … то',
    'blk.ifElse': 'если … то / иначе',
    'blk.setPinMode': 'режим пина',
    'blk.digitalWrite': 'цифровой выход',
    'blk.analogWrite': 'аналоговый выход (ШИМ)',
    'blk.setVar': 'задать',
    'blk.changeVar': 'изменить',
    'blk.serialBegin': 'Serial: начало',
    'blk.serialPrint': 'Serial: печать',
    'blk.serialPrintln': 'Serial: печать строки',
    'blk.servoWrite': 'сервопривод: угол',
    'blk.tone': 'играть тон',
    'blk.noTone': 'стоп тон',
    'blk.lcdInit': 'LCD: инициализация',
    'blk.lcdClear': 'LCD: очистить',
    'blk.lcdSetCursor': 'LCD: курсор',
    'blk.lcdPrint': 'LCD: печать',
    'blk.readUltrasonic': 'измерить расстояние (см)',
    'blk.readTemperature': 'измерить температуру',
    'blk.readHumidity': 'измерить влажность',

    // Block parameter labels.
    'par.ms': 'мс',
    'par.times': 'раз',
    'par.pin': 'пин',
    'par.mode': 'режим',
    'par.value': 'значение',
    'par.value 0-255': 'значение 0–255',
    'par.name': 'имя',
    'par.to': 'в',
    'par.by': 'на',
    'par.baud': 'скорость',
    'par.angle': 'угол',
    'par.hz': 'Гц',
    'par.into': 'в перем.',
    'par.trig': 'trig',
    'par.echo': 'echo',
    'par.col': 'стлб',
    'par.row': 'стр',

    // Value editor kinds.
    'val.number': 'число',
    'val.variable': 'переменная',
    'val.text': 'текст',
    'val.analogRead': 'analogRead',
    'val.digitalRead': 'digitalRead',
    'val.millis': 'millis',

    // Sketch preview.
    'sketch.title': 'Скетч',
    'sketch.copy': 'Копировать',
    'sketch.copied': 'Скетч скопирован',
    'sketch.rebuild': 'Пересобрать из блоков',
    'sketch.hint': 'Пишите скетч здесь — блоки подстроятся',
    'sketch.errors': 'Проблем: {count} — блоки оставлены как были',
    'sketch.line': 'Строка {line}',

    'parse.noSections': 'нет ни setup(), ни loop()',
    'parse.unknownStatement': 'для этой строки нет блока',
    'parse.unknownFunction': 'для этой функции нет блока',
    'parse.expectedToken': 'строка не закончена',
    'parse.unexpectedToken': 'лишний текст вне строки',
    'parse.badDelay': 'задержке нужно обычное число миллисекунд',
    'parse.badFor': 'блок есть только у цикла «повторить N раз»',
    'parse.badWhile': 'блок есть только у цикла «всегда» (while true)',
    'parse.badCondition': 'не удалось прочитать условие',
    'parse.badExpression': 'не удалось прочитать выражение',
    'parse.badPin': 'это не пин',
    'parse.badValue': 'здесь такое значение не принимается',
    'parse.badName': 'это не имя',
    'parse.unterminated': 'скетч обрывается до закрытия блока',

    // Serial monitor.
    'serial.title': 'Монитор порта',
    'serial.clear': 'Очистить',
    'serial.empty': '(вывода пока нет — нажмите «Запустить»)',

    // Canvas hints.
    'canvas.hintTitle':
        'Коснитесь контакта, затем другого контакта, чтобы проложить провод',
    'canvas.hintSubtitle':
        'Двойной клик — повернуть деталь · долгое нажатие — удалить',
    'canvas.wireTitle': 'От {name} · {pin} — теперь коснитесь целевого контакта',
    'canvas.wireSubtitle':
        'Оранжевые контакты готовы к соединению · коснитесь снова, чтобы отменить',
    'canvas.cancelWire': 'Отменить провод',

    // Silkscreen printed on the parts themselves.
    'silk.robotCar': 'МАШИНКА 4WD',
    'silk.robotArm': 'РУКА',
    'silk.base': 'БАЗА',
    'silk.joystick': 'KY-023',
    'silk.digital': 'ЦИФРОВЫЕ',
    'silk.analogPower': 'АНАЛОГ / ПИТАНИЕ',

    // Snack bar messages.
    'msg.addBlocks': 'Сначала добавьте блоки в программу.',
    'msg.placeArduino': 'Поставьте на поле плату Arduino UNO, чтобы запустить.',
    'msg.newProject': 'Создан новый проект.',
    'msg.loadedExample': 'Загружен пример «{title}».',
    'msg.savedSlot': 'Сохранено в слот «{slot}».',
    'msg.slotEmpty': 'Слот «{slot}» пуст.',
    'msg.openedSlot': 'Открыт слот «{slot}».',
    'msg.imported': 'Проект импортирован.',
    'msg.importFailed': 'Ошибка импорта: {error}',

    // Default project name.
    'project.new': 'Новый проект',

    // Solver warnings.
    'warn.ledCurrent':
        'Светодиод {id} потребляет слишком большой ток; добавьте резистор.',
    'warn.ultrasonicEcho':
        'Подключите контакт ECHO дальномера к цифровому пину.',
    'warn.dhtData': 'Подключите контакт DATA датчика DHT11 к цифровому пину.',

    // Lessons.
    'lesson.blink.title': 'Мигание',
    'lesson.blink.summary':
        'Классика: включаем и выключаем светодиод каждую секунду.',
    'lesson.blink.s1':
        'Анод светодиода через резистор 220 Ω идёт к пину D13.',
    'lesson.blink.s2': 'Катод светодиода идёт к GND.',
    'lesson.blink.s3':
        'Каждую секунду пин переключается между HIGH и LOW.',

    'lesson.button_led.title': 'Кнопка + светодиод',
    'lesson.button_led.summary':
        'Считываем кнопку и повторяем её состояние на светодиоде.',
    'lesson.button_led.s1':
        'Подключите кнопку между D2 и GND и используйте INPUT_PULLUP.',
    'lesson.button_led.s2':
        'если (digitalRead(2) == 0) — кнопка нажата.',
    'lesson.button_led.s3':
        'Повторяем состояние на светодиоде, подключённом к D13.',

    'lesson.pot_led.title': 'Потенциометр регулирует яркость',
    'lesson.pot_led.summary':
        'Считываем аналоговый вход и плавно меняем яркость светодиода через '
            'ШИМ.',
    'lesson.pot_led.s1':
        'Крайние выводы потенциометра — к 5V и GND, средний — к A0.',
    'lesson.pot_led.s2': 'analogRead(A0) возвращает 0..1023.',
    'lesson.pot_led.s3':
        'map() масштабирует это в 0..255 для analogWrite на D9.',

    'lesson.joystick_servo.title': 'Джойстик управляет сервоприводом',
    'lesson.joystick_servo.summary':
        'Читаем обе оси джойстика и наводим по ним сервопривод.',
    'lesson.joystick_servo.s1':
        'Джойстик — это два потенциометра и кнопка в одном модуле: VCC и GND к '
        'плате, VRX на A0, SW на D2.',
    'lesson.joystick_servo.s2':
        'analogRead(A0) даёт 0 у одного края хода по X, 1023 у другого и около '
        '512, когда ручка не тронута.',
    'lesson.joystick_servo.s3':
        'Подключите VRY к свободному аналоговому пину, чтобы так же читать ось Y.',
    'lesson.joystick_servo.s4':
        'SW — это кнопка на GND, поэтому с INPUT_PULLUP digitalRead(2) даёт 0, '
        'пока ручка вдавлена.',
    'lesson.joystick_servo.s5':
        'Потяните ручку на плате: сервопривод следует за осью X, а светодиод '
        'загорается, когда ручку вдавливают.',
    'lesson.servo_sweep.title': 'Поворот сервопривода',
    'lesson.servo_sweep.summary':
        'Плавно поворачиваем сервопривод от 0° до 180° и обратно.',
    'lesson.servo_sweep.s1':
        'Подключите сигнальный вывод сервопривода к D9 (ШИМ), а также 5V и GND.',
    'lesson.servo_sweep.s2':
        'Блок «сервопривод: угол» поворачивает качалку на заданный угол.',

    'lesson.buzzer_melody.title': 'Мелодия зуммера',
    'lesson.buzzer_melody.summary':
        'Играем мелодию из трёх нот на пьезо-зуммере.',
    'lesson.buzzer_melody.s1': 'Плюс зуммера — к D8, минус — к GND.',
    'lesson.buzzer_melody.s2':
        'tone(pin, hz) включает ноту, noTone(pin) выключает её.',

    'lesson.lcd_hello.title': 'Привет на LCD',
    'lesson.lcd_hello.summary':
        'Выводим приветствие на символьный дисплей 16x2 с шиной I2C.',
    'lesson.lcd_hello.s1': 'SDA/SCL дисплея — к A4/A5, а также 5V и GND.',
    'lesson.lcd_hello.s2':
        'Блок «LCD: инициализация» включает дисплей, затем выводим текст.',

    'lesson.ultrasonic.title': 'Ультразвуковой дальномер',
    'lesson.ultrasonic.summary':
        'Измеряем расстояние датчиком HC-SR04 и выводим его в монитор порта.',
    'lesson.ultrasonic.s1': 'TRIG — к D7, ECHO — к D6, а также 5V и GND.',
    'lesson.ultrasonic.s2':
        'Двигайте ползунок расстояния, чтобы менять измеряемое значение.',
    'lesson.ultrasonic.s3': 'Результат появляется в мониторе порта.',

    'lesson.dht11.title': 'Температура и влажность',
    'lesson.dht11.summary': 'Считываем датчик DHT11 и выводим температуру.',
    'lesson.dht11.s1': 'DATA датчика — к D2, а также 5V и GND.',
    'lesson.dht11.s2': 'Меняйте температуру и влажность ползунками.',

    'lesson.robot_car.title': 'Машинка 4WD: объезд стен',
    'lesson.robot_car.summary':
        'Ведём полноприводную машинку и уводим её от границы поля.',
    'lesson.robot_car.s1':
        'У каждого мотора своя пара направления A/B и свой вход разрешения: '
            'M1A/M1B/EN1 → D4/D7/D3, M2A/M2B/EN2 → D8/D12/D5, '
            'M3A/M3B/EN3 → D10/D11/D6, M4A/M4B/EN4 → D13/D2/D9.',
    'lesson.robot_car.s2':
        'M1 — перед-лево, M2 — перед-право, M3 — зад-лево, M4 — зад-право, '
            'значит левая пара — M1+M3, а правая — M2+M4.',
    'lesson.robot_car.s3':
        'Нос — это перед: стена, которую он измеряет, — край поля.',
    'lesson.robot_car.s4':
        'Задний дальномер тоже подключён к A2/A3 — считайте его ещё одним '
            'блоком «измерить расстояние», чтобы добавить задний ход.',
    'lesson.robot_car.s5':
        'Нажмите «Запустить»: машинка едет вперёд и разворачивается на месте '
            'перед краем.',

    'lesson.robot_arm.title': 'Механическая рука: взять и положить',
    'lesson.robot_arm.summary':
        'Проводим сегментную руку по циклу «взять и положить».',
    'lesson.robot_arm.s1':
        'J1–J4 — к D3/D5/D6/D9, а также 5V и GND. Каждый сустав — это один '
            'сервопривод.',
    'lesson.robot_arm.s2':
        'Задайте число сегментов руки в инспекторе и установите сервоприводы в '
            'те суставы, которыми должна управлять программа.',
    'lesson.robot_arm.s3':
        'Последний сустав управляет челюстями: J4 открывает и закрывает '
            'захват.',
    'lesson.robot_arm.s4':
        'Сустав без сервопривода просто держит угол, заданный вручную, так что '
            'руку можно выставить вручную и анимировать по одному суставу за '
            'раз.',
    'lesson.robot_arm.s5':
        'Нажмите «Запустить», чтобы проиграть цикл «взять и положить».',

    'lesson.robot_arm_kit.title': 'Механическая рука: собрать из деталей',
    'lesson.robot_arm_kit.summary':
        'Соединяем основание, два звена и захват, ставя сервопривод в тот '
            'сустав, который должен двигаться.',
    'lesson.robot_arm_kit.s1':
        'Перетащите на поле основание руки, звено руки, захват руки и '
            'сервоприводы. У каждой детали есть золотое гнездо, куда '
            'вставляется следующая.',
    'lesson.robot_arm_kit.s2':
        'Перетащите деталь так, чтобы её основание попало на гнездо, и '
            'отпустите: она прищёлкнется и встанет на место. Потяните снова, '
            'чтобы отцепить.',
    'lesson.robot_arm_kit.s3':
        'Сервопривод, прикрученный в сустав, поворачивает всё, что выше него, '
            'на угол, записанный в его сигнальный пин, — именно это делает руку '
            'рукой.',
    'lesson.robot_arm_kit.s4':
        'Сервопривод, прикрученный к гнезду захвата, управляет челюстями: '
            '0 — закрыты, 180 — широко открыты.',
    'lesson.robot_arm_kit.s5':
        'Подключение: сервопривод плеча — на D3, локтя — на D5, челюстей — на '
            'D6.',
    'lesson.robot_arm_kit.s6':
        'Нажмите «Запустить», чтобы рука сделала движение и сработал захват.',
  };
}
