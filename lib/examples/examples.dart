import '../blocks/block_catalog.dart';
import '../blocks/block_model.dart';
import '../models/circuit.dart';
import '../models/component_type.dart';
import '../models/project.dart';

/// A ready-made lesson: schematic + blocks + explanation.
///
/// The [title], [summary] and [steps] are the English reference wording; the
/// examples dialog shows their translations, looked up as
/// `lesson.<id>.title` / `.summary` / `.s<n>`.
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
      id: 'joystick_servo',
      title: 'Joystick steers a servo',
      summary: 'Read both axes of a joystick and aim a servo with them.',
      steps: [
        'The joystick is two potentiometers and a button on one module: VCC and '
            'GND to the board, VRX to A0, and SW to D2.',
        'analogRead(A0) returns 0 at one end of the X travel, 1023 at the '
            'other, and about 512 with the stick untouched.',
        'Wire VRY to a spare analog pin to read the Y axis the same way.',
        'SW is a button to GND, so INPUT_PULLUP makes digitalRead(2) read 0 '
            'while the stick is pushed in.',
        'Drag the stick on the board: the servo follows the X axis and the LED '
            'lights up when you push the stick in.',
      ],
      build: () => _project(
        'Joystick',
        [
          _c('uno', ComponentType.arduinoUno, 40, 40),
          _c('joy1', ComponentType.joystick, 380, 60),
          _c('servo1', ComponentType.servo, 380, 200),
          _c('r1', ComponentType.resistor, 620, 200,
              props: {'resistance': 220.0}),
          _c('led1', ComponentType.led, 620, 276),
        ],
        [
          _w('joy1', 'VCC', 'uno', '5V0'),
          _w('joy1', 'GND', 'uno', 'GND3'),
          _w('joy1', 'VRX', 'uno', 'A0'),
          _w('joy1', 'SW', 'uno', 'D2'),
          _w('servo1', 'VCC', 'uno', '5V0'),
          _w('servo1', 'GND', 'uno', 'GND3'),
          _w('servo1', 'SIG', 'uno', 'D9'),
          _w('uno', 'D13', 'r1', '1'),
          _w('r1', '2', 'led1', 'A'),
          _w('led1', 'C', 'uno', 'GND4'),
        ],
        [
          _b(BlockKind.setPinMode, {'pin': 13, 'mode': 'OUTPUT'}),
          _b(BlockKind.setPinMode, {'pin': 2, 'mode': 'INPUT_PULLUP'}),
        ],
        [
          _b(BlockKind.servoWrite, {
            'pin': 9,
            'angle': Value.call('map', [
              Value.call('analogRead', [Value.num(14)]),
              Value.num(0),
              Value.num(1023),
              Value.num(0),
              Value.num(180),
            ]),
          }),
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
    LabExample(
      id: 'robot_car',
      title: 'Robot car 4WD: avoid the walls',
      summary: 'Drive a four wheel drive car and steer it away from the border.',
      steps: [
        'Each motor has its own direction pair A/B and its own enable: '
            'M1A/M1B/EN1 to D4/D7/D3, M2A/M2B/EN2 to D8/D12/D5, '
            'M3A/M3B/EN3 to D10/D11/D6, M4A/M4B/EN4 to D13/D2/D9.',
        'M1 is front-left, M2 front-right, M3 rear-left, M4 rear-right, so the '
            'left pair is M1+M3 and the right pair M2+M4.',
        'The nose is the front: the wall it measures is the edge of the board.',
        'The rear rangefinder is wired to A2/A3 as well - read it with another '
            '"read distance" block to add a reverse gear.',
        'Press Run: it drives forward and spins on the spot before the edge.',
      ],
      build: () => _project(
        'Robot car 4WD',
        [
          _c('uno', ComponentType.arduinoUno, 40, 40),
          _c('car', ComponentType.robotCar, 460, 120),
        ],
        [
          _w('car', '5V', 'uno', '5V0'),
          _w('car', 'GND', 'uno', 'GND3'),
          // Front-left.
          _w('car', 'M1A', 'uno', 'D4'),
          _w('car', 'M1B', 'uno', 'D7'),
          _w('car', 'EN1', 'uno', 'D3'),
          // Front-right.
          _w('car', 'M2A', 'uno', 'D8'),
          _w('car', 'M2B', 'uno', 'D12'),
          _w('car', 'EN2', 'uno', 'D5'),
          // Rear-left.
          _w('car', 'M3A', 'uno', 'D10'),
          _w('car', 'M3B', 'uno', 'D11'),
          _w('car', 'EN3', 'uno', 'D6'),
          // Rear-right.
          _w('car', 'M4A', 'uno', 'D13'),
          _w('car', 'M4B', 'uno', 'D2'),
          _w('car', 'EN4', 'uno', 'D9'),
          // Front and rear rangefinders.
          _w('car', 'TRIG', 'uno', 'A0'),
          _w('car', 'ECHO', 'uno', 'A1'),
          _w('car', 'TRIG2', 'uno', 'A2'),
          _w('car', 'ECHO2', 'uno', 'A3'),
        ],
        [
          for (final pin in [2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13])
            _b(BlockKind.setPinMode, {'pin': pin, 'mode': 'OUTPUT'}),
          _b(BlockKind.setPinMode, {'pin': 15, 'mode': 'INPUT'}),
          _b(BlockKind.setPinMode, {'pin': 17, 'mode': 'INPUT'}),
        ],
        [
          _b(BlockKind.readUltrasonic,
              {'name': 'ahead', 'trig': 14, 'echo': 15}),
          _b(
            BlockKind.ifElse,
            {
              'condition': Value.binary(
                  '<', Value.varRef('ahead'), Value.num(25)),
            },
            [
              // Spin on the spot: the left pair backs up, the right pair drives.
              _b(BlockKind.digitalWrite, {'pin': 4, 'value': 'LOW'}),
              _b(BlockKind.digitalWrite, {'pin': 7, 'value': 'HIGH'}),
              _b(BlockKind.digitalWrite, {'pin': 10, 'value': 'LOW'}),
              _b(BlockKind.digitalWrite, {'pin': 11, 'value': 'HIGH'}),
              _b(BlockKind.digitalWrite, {'pin': 8, 'value': 'HIGH'}),
              _b(BlockKind.digitalWrite, {'pin': 12, 'value': 'LOW'}),
              _b(BlockKind.digitalWrite, {'pin': 13, 'value': 'HIGH'}),
              _b(BlockKind.digitalWrite, {'pin': 2, 'value': 'LOW'}),
              _b(BlockKind.analogWrite, {'pin': 3, 'value': 130.0}),
              _b(BlockKind.analogWrite, {'pin': 5, 'value': 130.0}),
              _b(BlockKind.analogWrite, {'pin': 6, 'value': 130.0}),
              _b(BlockKind.analogWrite, {'pin': 9, 'value': 130.0}),
              _b(BlockKind.wait, {'ms': 220.0}),
            ],
            [
              // Clear road: all four wheels forward.
              _b(BlockKind.digitalWrite, {'pin': 4, 'value': 'HIGH'}),
              _b(BlockKind.digitalWrite, {'pin': 7, 'value': 'LOW'}),
              _b(BlockKind.digitalWrite, {'pin': 10, 'value': 'HIGH'}),
              _b(BlockKind.digitalWrite, {'pin': 11, 'value': 'LOW'}),
              _b(BlockKind.digitalWrite, {'pin': 8, 'value': 'HIGH'}),
              _b(BlockKind.digitalWrite, {'pin': 12, 'value': 'LOW'}),
              _b(BlockKind.digitalWrite, {'pin': 13, 'value': 'HIGH'}),
              _b(BlockKind.digitalWrite, {'pin': 2, 'value': 'LOW'}),
              _b(BlockKind.analogWrite, {'pin': 3, 'value': 170.0}),
              _b(BlockKind.analogWrite, {'pin': 5, 'value': 170.0}),
              _b(BlockKind.analogWrite, {'pin': 6, 'value': 170.0}),
              _b(BlockKind.analogWrite, {'pin': 9, 'value': 170.0}),
            ],
          ),
        ],
      ),
    ),
    LabExample(
      id: 'robot_arm',
      title: 'Robot arm: pick and place',
      summary: 'Swing a segmented arm through a pick and place cycle.',
      steps: [
        'J1-J4 to D3/D5/D6/D9, plus 5V and GND. Each joint is one servo.',
        'Set how many segments the arm has in the Inspector, and fit a servo to '
            'the joints you want the program to drive.',
        'The last joint works the jaws, so J4 opens and closes the gripper.',
        'A joint with no servo just holds the angle you dial in by hand, so you '
            'can pose the arm and animate one joint at a time.',
        'Press Run to replay the pick and place cycle.',
      ],
      build: () => _project(
        'Robot arm',
        [
          _c('uno', ComponentType.arduinoUno, 40, 40),
          _c('arm', ComponentType.robotArm, 460, 140),
        ],
        [
          _w('arm', '5V', 'uno', '5V0'),
          _w('arm', 'GND', 'uno', 'GND3'),
          _w('arm', 'J1', 'uno', 'D3'),
          _w('arm', 'J2', 'uno', 'D5'),
          _w('arm', 'J3', 'uno', 'D6'),
          _w('arm', 'J4', 'uno', 'D9'),
        ],
        const [],
        [
          _b(BlockKind.servoWrite, {'pin': 3, 'angle': 40.0}),
          _b(BlockKind.servoWrite, {'pin': 5, 'angle': 120.0}),
          _b(BlockKind.servoWrite, {'pin': 6, 'angle': 135.0}),
          _b(BlockKind.wait, {'ms': 600.0}),
          _b(BlockKind.servoWrite, {'pin': 9, 'angle': 165.0}),
          _b(BlockKind.wait, {'ms': 600.0}),
          _b(BlockKind.servoWrite, {'pin': 5, 'angle': 65.0}),
          _b(BlockKind.servoWrite, {'pin': 6, 'angle': 100.0}),
          _b(BlockKind.wait, {'ms': 600.0}),
          _b(BlockKind.servoWrite, {'pin': 3, 'angle': 135.0}),
          _b(BlockKind.wait, {'ms': 800.0}),
          _b(BlockKind.servoWrite, {'pin': 9, 'angle': 20.0}),
          _b(BlockKind.wait, {'ms': 600.0}),
        ],
      ),
    ),
    LabExample(
      id: 'robot_arm_kit',
      title: 'Robot arm: build it out of parts',
      summary: 'Bolt a pedestal, two links and a gripper together, '
          'with a servo at the joint that has to move.',
      steps: [
        'Drag an Arm Base, an Arm Link, an Arm Gripper and Servo Motors onto '
            'the board. Every part has a gold socket where the next one goes.',
        'Drag a part so its foot lands on a socket and let go: it snaps on and '
            'stays put. Drag it again to pull it off.',
        'A servo bolted into a joint swings everything above it by the angle '
            'you write to its signal pin - that is what makes it an arm.',
        'A servo bolted onto the gripper\'s socket works the jaws: 0 shuts '
            'them, 180 opens them wide.',
        'Wiring: the shoulder servo is on D3, the elbow on D5, the jaws on D6.',
        'Press Run to sweep the arm and work the gripper.',
      ],
      build: () => _project(
        'Arm kit',
        [
          _c('uno', ComponentType.arduinoUno, 40, 40),
          _c('base', ComponentType.armBase, 560, 400),
          _c('shoulder', ComponentType.servo, 560, 400,
              props: {'parent': 'base'}),
          _c('link1', ComponentType.armLink, 560, 400,
              props: {'parent': 'shoulder'}),
          _c('elbow', ComponentType.servo, 560, 400,
              props: {'parent': 'link1'}),
          _c('link2', ComponentType.armLink, 560, 400,
              props: {'parent': 'elbow'}),
          _c('grip', ComponentType.armGripper, 560, 400,
              props: {'parent': 'link2', 'openness': 0.0}),
          _c('jaws', ComponentType.servo, 560, 400, props: {'parent': 'grip'}),
        ],
        [
          _w('shoulder', 'SIG', 'uno', 'D3'),
          _w('elbow', 'SIG', 'uno', 'D5'),
          _w('jaws', 'SIG', 'uno', 'D6'),
          _w('shoulder', 'VCC', 'uno', '5V0'),
          _w('shoulder', 'GND', 'uno', 'GND3'),
          _w('elbow', 'VCC', 'uno', '5V0'),
          _w('elbow', 'GND', 'uno', 'GND3'),
          _w('jaws', 'VCC', 'uno', '5V0'),
          _w('jaws', 'GND', 'uno', 'GND3'),
        ],
        const [],
        [
          _b(BlockKind.servoWrite, {'pin': 3, 'angle': 120.0}),
          _b(BlockKind.wait, {'ms': 600.0}),
          _b(BlockKind.servoWrite, {'pin': 5, 'angle': 60.0}),
          _b(BlockKind.wait, {'ms': 600.0}),
          _b(BlockKind.servoWrite, {'pin': 6, 'angle': 160.0}),
          _b(BlockKind.wait, {'ms': 600.0}),
          _b(BlockKind.servoWrite, {'pin': 6, 'angle': 20.0}),
          _b(BlockKind.wait, {'ms': 600.0}),
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
