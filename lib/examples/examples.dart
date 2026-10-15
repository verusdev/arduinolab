import '../blocks/block_catalog.dart';
import '../blocks/block_model.dart';
import '../models/circuit.dart';
import '../models/component_type.dart';
import '../models/project.dart';

/// A ready-made lesson: schematic + blocks + explanation.
class LabExample {
  LabExample({
    required this.id,
    required this.title,
    required this.summary,
    required this.steps,
    required this.build,
  });

  final String id;
  final String title;
  final String summary;
  final List<String> steps;
  final Project Function() build;
}

PlacedComponent _c(String id, ComponentType type, double x, double y,
        {Map<String, Object?>? props, double rot = 0}) =>
    PlacedComponent(
        id: id, type: type, x: x, y: y, rotation: rot, properties: props);

Wire _w(String a, String ap, String b, String bp) => Wire(
    id: '${a}_${ap}_${b}_$bp',
    aComponent: a,
    aPin: ap,
    bComponent: b,
    bPin: bp);

Block _b(BlockKind kind,
    [Map<String, Object?> params = const {},
    List<Block> body = const [],
    List<Block> elseBody = const []]) {
  final block = BlockCatalog.def(kind).build();
  block.params.addAll(params);
  block.body.addAll(body);
  block.elseBody.addAll(elseBody);
  return block;
}

Project _project(
  String name,
  List<PlacedComponent> components,
  List<Wire> wires,
  List<Block> setup,
  List<Block> loop,
) =>
    Project(
      name: name,
      circuit: Circuit(components: components, wires: wires),
      program: BlockProgram(setup: setup, loop: loop),
    );

/// Library of built-in examples shown in the examples dialog.
class Examples {
  static final List<LabExample> all = [
    LabExample(
      id: 'blink',
      title: 'Blink',
      summary: 'Classic: turn an LED on and off every second.',
      steps: [
        'LED anode goes through a 220 Ω resistor to pin D13.',
        'LED cathode goes to GND.',
        'Every second the pin alternates HIGH and LOW.',
      ],
      build: () => _project(
        'Blink',
        [
          _c('uno', ComponentType.arduinoUno, 40, 40),
          _c('r1', ComponentType.resistor, 380, 120,
              props: {'resistance': 220.0}),
          _c('led1', ComponentType.led, 380, 196),
        ],
        [
          _w('uno', 'D13', 'r1', '1'),
          _w('r1', '2', 'led1', 'A'),
          _w('led1', 'C', 'uno', 'GND3'),
        ],
        [
          _b(BlockKind.setPinMode, {'pin': 13, 'mode': 'OUTPUT'}),
        ],
        [
          _b(BlockKind.digitalWrite, {'pin': 13, 'value': 'HIGH'}),
          _b(BlockKind.wait, {'ms': 1000.0}),
          _b(BlockKind.digitalWrite, {'pin': 13, 'value': 'LOW'}),
          _b(BlockKind.wait, {'ms': 1000.0}),
        ],
      ),
    ),
    LabExample(
      id: 'button_led',
      title: 'Button + LED',
      summary: 'Read a push button and mirror its state on an LED.',
      steps: [
        'Wire the button between D2 and GND and use INPUT_PULLUP.',
        'if (digitalRead(2) == 0) the button is pressed.',
        'Mirror the state on the LED connected to D13.',
      ],
      build: () => _project(
        'Button + LED',
        [
          _c('uno', ComponentType.arduinoUno, 40, 40),
          _c('btn1', ComponentType.pushButton, 380, 60),
          _c('r1', ComponentType.resistor, 380, 190,
              props: {'resistance': 220.0}),
          _c('led1', ComponentType.led, 380, 266),
        ],
        [
          _w('btn1', '1', 'uno', 'GND3'),
          _w('btn1', '3', 'uno', 'D2'),
          _w('uno', 'D13', 'r1', '1'),
          _w('r1', '2', 'led1', 'A'),
          _w('led1', 'C', 'uno', 'GND4'),
        ],
        [
          _b(BlockKind.setPinMode, {'pin': 13, 'mode': 'OUTPUT'}),
          _b(BlockKind.setPinMode, {'pin': 2, 'mode': 'INPUT_PULLUP'}),
        ],
        [
          _b(
            BlockKind.ifElse,
            {
              'condition': Value.binary('==',
                  Value.call('digitalRead', [Value.num(2)]), Value.num(0)),
            },
            [
              _b(BlockKind.digitalWrite, {'pin': 13, 'value': 'HIGH'}),
            ],
            [
              _b(BlockKind.digitalWrite, {'pin': 13, 'value': 'LOW'}),
            ],
          ),
        ],
      ),
    ),
    LabExample(
      id: 'pot_led',
      title: 'Potentiometer dims an LED',
      summary: 'Read an analog input and use it to dim an LED with PWM.',
      steps: [
        'Potentiometer outer legs to 5V and GND, wiper to A0.',
        'analogRead(A0) returns 0..1023.',
        'map() scales it to 0..255 for analogWrite on D9.',
      ],
      build: () => _project(
        'Potentiometer + LED',
        [
          _c('uno', ComponentType.arduinoUno, 40, 40),
          _c('pot1', ComponentType.potentiometer, 380, 60),
          _c('r1', ComponentType.resistor, 380, 190,
              props: {'resistance': 220.0}),
          _c('led1', ComponentType.led, 380, 266),
        ],
        [
          _w('pot1', '1', 'uno', '5V0'),
          _w('pot1', '3', 'uno', 'GND3'),
          _w('pot1', '2', 'uno', 'A0'),
          _w('uno', 'D9', 'r1', '1'),
          _w('r1', '2', 'led1', 'A'),
          _w('led1', 'C', 'uno', 'GND4'),
        ],
        [
          _b(BlockKind.setPinMode, {'pin': 9, 'mode': 'OUTPUT'}),
        ],
        [
          _b(BlockKind.analogWrite, {
            'pin': 9,
            'value': Value.call('map', [
              Value.call('analogRead', [Value.num(14)]),
              Value.num(0),
              Value.num(1023),
              Value.num(0),
              Value.num(255),
            ]),
          }),
        ],
      ),
    ),
    LabExample(
      id: 'servo_sweep',
      title: 'Servo sweep',
      summary: 'Sweep a servo motor from 0° to 180° and back.',
      steps: [
        'Wire the servo signal pin to D9 (PWM), plus 5V and GND.',
        'servo write moves the horn to the requested angle.',
      ],
      build: () => _project(
        'Servo sweep',
        [
          _c('uno', ComponentType.arduinoUno, 40, 40),
          _c('servo1', ComponentType.servo, 380, 120),
        ],
        [
          _w('servo1', 'VCC', 'uno', '5V0'),
          _w('servo1', 'GND', 'uno', 'GND3'),
          _w('servo1', 'SIG', 'uno', 'D9'),
        ],
        const [],
        [
          _b(BlockKind.servoWrite, {'pin': 9, 'angle': 0.0}),
          _b(BlockKind.wait, {'ms': 1000.0}),
          _b(BlockKind.servoWrite, {'pin': 9, 'angle': 180.0}),
          _b(BlockKind.wait, {'ms': 1000.0}),
        ],
      ),
    ),
    LabExample(
      id: 'buzzer_melody',
      title: 'Buzzer melody',
      summary: 'Play a three note melody with a piezo buzzer.',
      steps: [
        'Buzzer + to D8, buzzer - to GND.',
        'tone(pin, hz) starts a note, noTone(pin) stops it.',
      ],
      build: () => _project(
        'Buzzer melody',
        [
          _c('uno', ComponentType.arduinoUno, 40, 40),
          _c('buz1', ComponentType.buzzer, 380, 120),
        ],
        [
          _w('buz1', 'P', 'uno', 'D8'),
          _w('buz1', 'N', 'uno', 'GND3'),
        ],
        const [],
        [
          _b(BlockKind.tone, {'pin': 8, 'frequency': 440.0}),
          _b(BlockKind.wait, {'ms': 400.0}),
          _b(BlockKind.tone, {'pin': 8, 'frequency': 523.0}),
          _b(BlockKind.wait, {'ms': 400.0}),
          _b(BlockKind.tone, {'pin': 8, 'frequency': 659.0}),
          _b(BlockKind.wait, {'ms': 400.0}),
          _b(BlockKind.noTone, {'pin': 8}),
          _b(BlockKind.wait, {'ms': 400.0}),
        ],
      ),
    ),
    LabExample(
      id: 'lcd_hello',
      title: 'LCD hello',
      summary: 'Print a greeting on a 16x2 I2C character display.',
      steps: [
        'LCD SDA/SCL go to A4/A5, plus 5V and GND.',
        'lcd init wakes the display up, then print text.',
      ],
      build: () => _project(
        'LCD hello',
        [
          _c('uno', ComponentType.arduinoUno, 40, 40),
          _c('lcd1', ComponentType.lcd16x2, 380, 120),
        ],
        [
          _w('lcd1', 'GND', 'uno', 'GND3'),
          _w('lcd1', 'VCC', 'uno', '5V0'),
          _w('lcd1', 'SDA', 'uno', 'A4'),
          _w('lcd1', 'SCL', 'uno', 'A5'),
        ],
        [
          _b(BlockKind.lcdInit),
          _b(BlockKind.lcdSetCursor, {'col': 0.0, 'row': 0.0}),
          _b(BlockKind.lcdPrint, {'value': Value.text('Hello, Arduino!')}),
        ],
        [
          _b(BlockKind.wait, {'ms': 1000.0}),
        ],
      ),
    ),
    LabExample(
      id: 'ultrasonic',
      title: 'Ultrasonic distance',
      summary: 'Measure distance with an HC-SR04 and print it to the Serial monitor.',
      steps: [
        'TRIG to D7, ECHO to D6, plus 5V and GND.',
        'Drag the distance slider to change the measured value.',
        'The result appears in the Serial monitor.',
      ],
      build: () => _project(
        'Ultrasonic distance',
        [
          _c('uno', ComponentType.arduinoUno, 40, 40),
          _c('us1', ComponentType.ultrasonic, 380, 120,
              props: {'distance': 100.0}),
        ],
        [
          _w('us1', 'VCC', 'uno', '5V0'),
          _w('us1', 'GND', 'uno', 'GND3'),
          _w('us1', 'TRIG', 'uno', 'D7'),
          _w('us1', 'ECHO', 'uno', 'D6'),
        ],
        [
          _b(BlockKind.serialBegin, {'baud': 9600.0}),
        ],
        [
          _b(BlockKind.readUltrasonic,
              {'name': 'distance', 'trig': 7, 'echo': 6}),
          _b(BlockKind.serialPrintln, {'value': Value.varRef('distance')}),
          _b(BlockKind.wait, {'ms': 500.0}),
        ],
      ),
    ),
    LabExample(
      id: 'dht11',
      title: 'Temperature & humidity',
      summary: 'Read a DHT11 sensor and print the temperature.',
      steps: [
        'DHT DATA to D2, plus 5V and GND.',
        'Use the sliders to change temperature and humidity.',
      ],
      build: () => _project(
        'DHT11',
        [
          _c('uno', ComponentType.arduinoUno, 40, 40),
          _c('dht1', ComponentType.dht11, 380, 120,
              props: {'temperature': 24.0, 'humidity': 50.0}),
        ],
        [
          _w('dht1', 'VCC', 'uno', '5V0'),
          _w('dht1', 'GND', 'uno', 'GND3'),
          _w('dht1', 'DATA', 'uno', 'D2'),
        ],
        [
          _b(BlockKind.serialBegin, {'baud': 9600.0}),
        ],
        [
          _b(BlockKind.readTemperature, {'name': 'temp', 'pin': 2}),
          _b(BlockKind.serialPrintln, {'value': Value.varRef('temp')}),
          _b(BlockKind.wait, {'ms': 1000.0}),
        ],
      ),
    ),
  ];

  static LabExample? byId(String id) {
    for (final e in all) {
      if (e.id == id) return e;
    }
    return null;
  }
}
