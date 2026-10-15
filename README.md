# Arduino Lab

A cross-platform Tinkercad-Circuits-style playground for Arduino: place
components, wire them up, build a program from blocks, and watch the circuit
simulate in real time.

Built with Flutter and a pure-Dart simulation core, so the same code runs on
Windows, the web, Android and iOS.

## Features

- **Schematic editor** — drag components from the palette onto the canvas,
  rotate them and connect pins with wires. Per-component properties (resistor
  value, LED colour, potentiometer position, sensor values, ...) are editable
  in the properties panel.
- **Block programming** — build a sketch from blocks (pins, delays, loops,
  conditionals, variables, serial, servo, buzzer, LCD and sensors), grouped
  into `setup` and `loop`.
- **Two views of the same program** — the block tree is the intermediate
  representation:
  - `SketchPrinter` renders a readable Arduino C++ sketch (read-only preview).
  - `SketchCompiler` compiles the same tree to bytecode for the built-in VM.
- **Live simulation** — a modified nodal analysis solver computes node
  voltages every frame; LEDs glow, servos move, the serial monitor prints,
  and sensors (ultrasonic, DHT11) feed real values back into the sketch.
- **Projects as JSON** — save/load slots via `shared_preferences`, plus JSON
  export/import. No native file dialogs required.
- **Eight built-in lessons** — Blink, Button + LED, Potentiometer dims an LED,
  Servo sweep, Buzzer melody, LCD hello, Ultrasonic distance and DHT11.
- **Responsive UI** — a wide three-column layout on desktop/web and a
  tabbed layout on phones.

## Getting started

```sh
flutter pub get
flutter run -d windows      # or: chrome, android, ios
```

## Quality checks

```sh
flutter analyze             # 0 issues
flutter test                # widget + engine unit tests
```

`test/engine_test.dart` covers the netlist (wires merge pins into nets), the
solver (LED brightness, `analogRead` on a potentiometer), the VM (a blink loop
toggles the pin), the sketch printer, project JSON round-tripping, and that
every built-in example compiles and ticks without throwing.

## Project layout

```
lib/
  blocks/            block model, catalog, C++ printer
  engine/            netlist, solver (MNA), VM, simulation engine
  models/            circuit, pins, component specs, project
  examples/          the built-in lessons
  services/          JSON persistence
  state/             AppState (ChangeNotifier)
  ui/                theme, screens, canvas rendering, widgets
  main.dart
```

The models and engine import only `dart:*` and never Flutter, which keeps the
simulation core unit-testable and portable.

## Simulation notes

- Virtual time is in microseconds; `delay()` jumps it forward.
- Execution is cooperative: each frame advances the VM within a fixed
  instruction budget, so a runaway `forever` loop cannot freeze the UI.
- The solver models LEDs as 180 Ω resistors, `INPUT_PULLUP` as a 40 kΩ pull-up
  to 5 V, and pins currently driving an output as fixed-voltage nodes.
