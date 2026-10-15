# PLAN — arduino_lab

> Flutter-приложение: Tinkercad-подобная среда симуляции Arduino UNO с **блочным программированием**.
> Платформы: **Windows desktop, Web, Android/iOS** (адаптивный UI).
> Документ-владелец: `project-planner`. Исполнители: `backend-specialist`, `frontend-specialist`, `test-engineer`.
> Статус: **PLANNING (утверждено к реализации)**. Код приложения на этапе планирования не пишется.

---

## 1. Продукт и цели

### 1.1 Что это
`arduino_lab` — учебная/инженерная среда, в которой пользователь:
1. Собирает схему на холсте: ставит Arduino UNO, breadboard и компоненты, соединяет пины проводами.
2. Программирует плату **визуальными блоками** (как Tinkercad Blocks): категории, вложенность, выпадающие списки пинов.
3. Нажимает **Run** — блоки превращаются в Arduino C++ скетч (read-only preview) и **исполняются** собственным интерпретатором на Dart поверх виртуальной машины симуляции.
4. Видит живой отклик схемы: LED светится, серво крутится, LCD пишет текст, в Serial Monitor идут `println`.

### 1.2 Зачем (проблема → решение)
| Проблема Tinkercad-подобных решений | Решение в `arduino_lab` |
|---|---|
| Нужен avr-gcc/arduino-cli и облако | Симуляция целиком на Dart, без внешних тулчейнов |
| Текстовый код сложен для новичка | Блочный редактор, текст только как preview |
| Нет оффлайна на desktop/mobile | Save/Load в JSON-файл + localStorage, 8 примеров из коробки |

### 1.3 Границы MVP (что входит)
- Компоненты: **Arduino UNO, breadboard, LED, RGB LED, резистор, push button, потенциометр, servo, пьезо-buzzer, LCD 16x2 (I2C), HC-SR04, DHT11, фоторезистор**, 7-segment — *опционально (P3)*.
- Холст: grid, drag&drop, поворот, выделение, удаление, провода между пинами, валидация соединений.
- Электрическая модель: netlist (провода + внутренние дорожки breadboard), шины 5V/GND/3.3V, вычисление состояний (яркость LED, кнопки тянут пин, потенциометр → `analogRead`).
- Arduino runtime API: `pinMode, digitalWrite, digitalRead, analogRead, analogWrite(PWM), delay, delayMicroseconds, millis, micros, tone/noTone, map, constrain, Serial.begin/print/println/available/read/readLine`, + **`pulseIn`** (требуется для HC-SR04).
- Блочный редактор: категории Control / Pins / Math / Logic / Text / Serial / Variables / Components.
- Симуляционный цикл: `setup()` один раз, `loop()` повторно, виртуальное время, защита от бесконечного цикла, кооперативное выполнение (UI не блокируется).
- Save/Load: сериализация схемы + блоков в JSON (файл и localStorage).
- Примеры из коробки: Blink, Button+LED, Potentiometer→LED brightness, Servo sweep, Buzzer melody, LCD hello, Ultrasonic distance, DHT11 read.

### 1.4 НЕ входит в MVP (out of scope)
Текстовый редактор скетчей, реальная компиляция AVR, прошивка физической платы, 3D-вид, осциллограф/графики сигналов, облако/аккаунты, мультиплеер, библиотеки сторонних датчиков (всё сверх core-API идёт **блоками компонентов**, а не интерпретацией C++ библиотек).

### 1.5 Критерии успеха (измеримые)
| # | Критерий | Метрика |
|---|---|---|
| S1 | Все 8 примеров запускаются без ошибок | `flutter test` — тест `examples_integrity_test` зелёный, каждый пример прогоняется ≥ 5 виртуальных секунд |
| S2 | Блоки → валидный скетч | golden-тесты `sketch_printer`: 20+ блок-программ → ожидаемый C++ текст |
| S3 | Электрика корректна | unit-тесты: делитель напряжения ±1%, ток LED ±5%, pull-up кнопка = HIGH при отпускании |
| S4 | UI не фризится | при бесконечном `loop {}` без delay — авто-пауза ≤ 1 c, кадры ≥ 30 fps |
| S5 | Сборка на 3 платформах | `flutter build web --release` + `flutter build windows --release` + `flutter analyze` — успех |
| S6 | round-trip сохранения | `project → JSON → project` побайтово эквивалентен по семантике (тест `serialization_roundtrip_test`) |

---

## 2. Технологический стек

| Слой | Технология | Почему |
|---|---|---|
| Framework | Flutter 3.47 / Dart 3.13 (stable, из env) | Один код на desktop/web/mobile |
| State | `provider` (`ChangeNotifier`) | Задано решением #3; без оверхеда Riverpod |
| Рендер холста | `CustomPaint` + `Canvas` | Полный контроль над grid/проводами/пинами, без тяжёлых graph-движков |
| Идентификаторы | `uuid` | Стабильные id компонентов/блоков для JSON и undo |
| Персистентность | `path_provider` (файл: desktop/mobile), `shared_preferences` (web/localStorage), `file_picker` (диалоги импорта/экспорта) | Нативный save/load на каждой платформе |
| Сериализация | **Ручные `toJson`/`fromJson`** (без `json_serializable`/`build_runner`) | Меньше шагов сборки, полный контроль версионирования схемы |
| Тесты | `flutter_test` + golden-тесты | Unit + golden для painter/printer |
| Линт | `flutter_lints` + `analysis_options.yaml` (strict) | `flutter analyze` = 0 ошибок |
| Опасные зависимости | запрещено тянуть WebView/JS-движки, onnx, ffmpeg и т.п. | Симуляция — чистый Dart |

`pubspec.yaml` (целевые зависимости): `provider`, `uuid`, `path_provider`, `shared_preferences`, `file_picker`. Dev: `flutter_test`, `flutter_lints`.

---

## 3. Архитектура и контракты между слоями

```
┌──────────────────────────────────────────────────────────────────────────┐
│ UI (Flutter widgets)                      ui/, state/                    │
│  Canvas │ BlockEditor │ Palette │ Inspector │ Serial │ SketchPreview     │
└───────────────▲──────────────────────────────────────────┬───────────────┘
                │ Provider notify                           │ user intents
┌───────────────┴──────────────────────────────────────────▼───────────────┐
│ Application services                       services/                     │
│  ProjectRepository · StorageBackend · ExamplesService · SettingsService  │
└───────────────▲──────────────────────────────────────────┬───────────────┘
                │                                          │
┌───────────────┴──────────────┐        ┌──────────────────▼───────────────┐
│ Blocks layer  blocks/        │        │ Simulation layer  engine/        │
│  BlockProgram ──generator──► │        │  SimulationEngine                │
│  SketchIR ──printer──► C++    │───────►│   ├─ ArduinoRuntime (VM+clock)   │
│         └──(IR)──────────────┼───────►│   ├─ CircuitSolver (MNA)         │
└──────────────────────────────┘        │   └─ Device registry             │
                                        └──────────────────▲───────────────┘
┌───────────────────────────────────────────────────────────┴──────────────┐
│ Domain models  models/  (Component, Pin, Wire, Circuit, Board, Project)  │
│  Чистый Dart. Ноль зависимостей от Flutter.                               │
└──────────────────────────────────────────────────────────────────────────┘
```

**Правила зависимостей (жёсткие):**
- `models/` → не импортирует ничего из `engine/`, `blocks/`, `ui/`, `Flutter`.
- `engine/` и `blocks/` → зависят только от `models/` + `core/` + Dart. **Никакого `package:flutter/material.dart`.**
- `services/` → `models/` + `blocks/` + `engine/` (для прогонки примеров) + платформенные плагины.
- `ui/`, `state/` → всё выше + Flutter.
- Инверсия: UI никогда не вызывает VM напрямую — только через `SimulationProvider` → `SimulationEngine`.

### 3.1 ADR (ключевые решения, обязательны к соблюдению)

**ADR-1. Единый источник истины — `SketchIR`, а не C++-текст.**
Блоки → `SketchIR` (AST) → (а) `SketchPrinter` печатает read-only C++; (б) `SketchCompiler` компилирует IR в инструкции VM. *Rationale:* писать парсер C++ — прямой путь к багам; генератор под нашим контролем, поэтому IR детерминирован, тестируем golden-тестами, а текст — честная проекция IR. Требование «интерпретатор скетча» выполняется: интерпретируется семантическая форма скетча. Импорт чужого C++ — stretch-цель P3 (упрощённый парсер), в MVP не нужен.

**ADR-2. Электрика через Modified Nodal Analysis (MNA).**
Netlist строится из проводов + **неявных** внутренних дорожек breadboard. Пассивные устройства — проводимости; LED — кусочно-линейная модель диода (порог `Vf` + динамическое сопротивление) с fixed-point итерацией (2–3 прохода); кнопка — идеальный ключ (`1e9 Ω` / `0.01 Ω`); потенциометр — два резистора и узел wiper; пин платы — источник (OUTPUT HIGH/LOW) или резистор подтяжки (INPUT_PULLUP 20–50 кΩ) или высокоомный вход. *Rationale:* детерминированно, тестируемо, покрывает все компоненты MVP.

**ADR-3. Виртуальная машина — стековая, с кооперативным `YIELD`.**
`delay`/`delayMicroseconds` компилируются в `YIELD virtualTime += dt`. Движок исполняет N инструкций за кадр (бюджет ~2–5 мс реального времени). Компилятор хранит карту `instructionIndex → blockId` для подсветки ошибки и защиты от бесконечного цикла. *Rationale:* рекурсивный tree-walking тяжело останавливать в `delay`; стековая VM легко шагается и тестируется.

**ADR-4. Сторонние Arduino-библиотеки не интерпретируются.**
`Servo`, `LiquidCrystal_I2C`, `DHT`, `Wire` не существуют как код. Их API (**и только он**) доступно через блоки категории Components и компилируется в builtin-инструкции, адресующие соответствующее `Device` (I2C-шина — виртуальная, LCD слушает адрес `0x27`).

**ADR-5. `models/` = immutable-значения + `copyWith`.** Мутации идут через `ChangeNotifier`-провайдеры, чтобы можно было делать snapshot/undo.

---

### 3.2 Контракт: доменные модели (`lib/models/`)

```dart
// units/coords: экранные координаты в "мировых" единицах холста (1 unit = 1 px при zoom=1)
enum PinKind { digital, analog, pwm, power, ground, i2cSda, i2cScl, special }
enum PinDirection { input, output, bidirectional, passive, power }

class Pin {
  final String id;            // локально уникален внутри компонента: 'D13','A0','5V','GND','SDA'
  final String label;         // отображаемое имя
  final PinKind kind;
  final PinDirection direction;
  final Offset localPosition; // позиция относительно центра компонента (в его локальной СК)
  final int? logicalDigitalNumber; // 13 для D13, 14..19 для A0..A5, null для питания
}

enum ComponentType { arduinoUno, breadboard, led, rgbLed, resistor, pushButton,
                     potentiometer, servo, buzzer, lcdI2c, ultrasonicHcSr04,
                     dht11, photoresistor, sevenSegment }

abstract class Component {
  final String id;              // uuid
  final ComponentType type;
  final String label;
  final Offset position;        // центр в мировых координатах
  final double rotationDeg;     // 0/90/180/270
  final Map<String, dynamic> props; // тип-специфичные (resistance, color, lightLevel, ...)
  List<Pin> get pins;           // абсолютные позиции пинов вычисляются: position + rotate(localPosition)
  Map<String, dynamic> toJson();
  Component copyWith({...});
  Offset pinPosition(String pinId); // с учётом rotation
}

class Wire {
  final String id;
  final String fromComponentId; final String fromPinId;
  final String toComponentId;   final String toPinId;
  final int colorArgb;
}

class Circuit {                 // схема как данные (immutable)
  final List<Component> components;
  final List<Wire> wires;
  final String boardId;         // id Arduino UNO в components
  Circuit copyWith({...});
  Circuit addComponent(Component c);
  Circuit addWire(Wire w);
  Circuit removeComponent(String id);   // + каскадно удаляет инцидентные провода
  Circuit removeWire(String id);
}

class Project {                 // корень документа
  final int schemaVersion;      // = 1
  final ProjectMeta meta;       // name, author, description, createdAt, updatedAt
  final Circuit circuit;
  final BlockProgram blocks;
  final ViewState view;         // camera offset + zoom
  final List<String>? tutorialGoals; // для уроков/примеров
}
```

**Breadboard** — обычный `Component`, но его `pins` включают: `top+`, `top-`, `bot+`, `bot-` (шины) и `1a..30j` (30 колонок × 10 рядов a–j). Внутренние (неявные) связи описаны в `BreadboardNetRules`:
- `top+`, `top-`, `bot+`, `bot-` — продольные шины (все точки шины соединены);
- внутри колонки: `a–b–c–d–e` соединены между собой; `f–g–h–i–j` соединены между собой; между `e` и `f` — **разрыв** (центральный жёлоб).

### 3.3 Контракт: электрический движок (`lib/engine/`)

```dart
/// Узел netlist'а (электрически общая точка).
class Net { final int id; final List<PinRef> pins; }        // PinRef = (componentId, pinId)
class PinRef { final String componentId; final String pinId; }
class Netlist { final List<Net> nets; int netOf(PinRef pin); }

abstract class NetlistBuilder {
  /// Провода → узлы; затем breadboard-дорoжки → слияние узлов (union-find).
  Netlist build(Circuit circuit);
}

/// Модель устройства для решателя: вклад в матрицу проводимостей.
abstract class DeviceModel {
  void stamp(MnaMatrix m, Netlist nl);
  void updateFromSolution(MnaMatrix m, Netlist nl); // ток/мощность/напряжение
  List<DeviceProbe> get probes;                     // для тестов и UI
}

abstract class CircuitSolver {
  /// Решает схему при текущих состояниях пинов и возвращает срез физики.
  CircuitSolution solve(Circuit circuit, Netlist netlist, PinDriveStates drives);
}

class CircuitSolution {
  final Map<String, double> nodeVoltages;      // netId → V
  final Map<String, double> pinVoltages;       // 'compId:pinId' → V
  final Map<String, double> ledCurrents;       // A
  final Map<String, int> analogReadValues;     // 'compId:pinId' → 0..1023 (для analog-пинов)
  final Map<String, bool> digitalPinReads;     // результат digitalRead для входных пинов
  final List<String> warnings;                 // короткое замыкание, нет GND, пин висит
}

class PinDriveStates { // что runtime сейчас "выдаёт" наружу
  Map<int, DigitalDrive> digital; // logicalPin → {high, pullup, hiZ}
  Map<int, int> pwmDuty;          // логический пин → 0..255 (для analogWrite)
}
```

**Модели устройств (stamp-правила):**

| Устройство | Stamp в MNA | Примечание |
|---|---|---|
| `Resistor(Ω)` | `G = 1/R` между двумя узлами | базовый элемент |
| `Led` | кусочно-линейный диод: выше `Vf` → `G = 1/Rdyn`; ниже → `G ≈ 1e-9` | fixed-point итерация до 3 раз |
| `RgbLed` | 3 независимых LED | каналы R/G/B |
| `PushButton` | ключ: замкнут `0.01 Ω`, разомкнут `1e9 Ω`; `pressed` из UI | |
| `Potentiometer` | `R_total` делится на `R1=αR`, `R2=(1-α)R`, между ними узел wiper | `α` = позиция слайдера |
| `Photoresistor` | резистор с `R(lightLevel)` (логарифмическая шкала) | слайдер освещённости из UI |
| `Servo/Buzzer/Lcd/Ultrasonic/Dht11/SevenSeg` | **не влияют** на MNA (потребители-датчики/актуаторы), считывают/управляются через `Device` | |
| Плата `5V/3.3V/GND` | идеальный источник (VSET 5.0/3.3/0.0) | VIN = 5.0 для MVP |
| Плата `D0..D13/A0..A5` | источник HIGH/LOW при OUTPUT; `INPUT_PULLUP` → 30 кΩ к 5V; `INPUT` → 100 МΩ | PWM: HIGH-доля = duty/255 |

### 3.4 Контракт: устройство и окружение (`lib/engine/devices/`)

```dart
/// Каждое устройство знает, как реагировать на физику и на runtime.
abstract class Device {
  String get hangingOnComponentId;
  void onCircuitSolution(CircuitSolution solution); // физика → внутреннее состояние
  void onRuntimeEvent(RuntimeEvent event);          // tone(), servo.write(), lcd.print()
  DeviceSnapshot snapshot();                        // то, что рисует UI (immutable)
  List<double> get analogOutputs;                   // что устройство "выдаёт" в сеть (HC-SR04 echo, DHT данные)
}

class DeviceContext {          // мост Device ↔ ArduinoRuntime
  double get virtualTimeSeconds;
  void scheduleEvent(double atVirtualTime, void Function() cb);
  int analogReadRaw(int logicalPin);
  bool digitalReadRaw(int logicalPin);
  void emitSerial(String s);
}
```

`DeviceRegistry` создаёт `Device` на каждый компонент типа «устройство» при старте симуляции.

### 3.5 Контракт: Arduino runtime и VM (`lib/engine/runtime/`, `lib/engine/vm/`)

```dart
abstract class ArduinoRuntime {
  void reset(Program program, CircuitSolutionProvider physics);
  /// Выполнить до budgetMs реального времени (или до следующего YIELD). Coop.
  RuntimeTick tick(double realElapsedMs);
  bool get isPaused; String? get runtimeError;
  // Публичные builtins, сгруппированы по API:
  //   Pins:    pinMode, digitalWrite, digitalRead, analogRead, analogWrite, pulseIn
  //   Time:    delay, delayMicroseconds, millis, micros
  //   Audio:   tone, noTone
  //   Math:    map, constrain, min, max, abs, random, randomSeed
  //   Serial:  begin, print, println, available, read, readLine, flush
  //   Servo:   attach, detach, write, read
  //   LCD:     lcdInit, lcdBacklight, lcdClear, lcdSetCursor, lcdPrint
  //   Sensors: ultrasonicDistance, dhtTemperature, dhtHumidity
  //   RGB/7seg: rgbWrite(r,g,b), segWrite(digit)
  SerialLog get serialLog;
}

class RuntimeTick {
  final double virtualTimeAdvancedMs;
  final int instructionsExecuted;
  final bool yieldedOnDelay;
  final bool budgetExhausted;     // → двигаемся дальше, ждём следующий кадр
  final RuntimeFault? fault;      // infinite loop / division by zero / bad pin
}

class RuntimeFault {
  final RuntimeFaultKind kind;
  final String message;
  final String? blockId;          // для подсветки блока в редакторе
  final int? instructionIndex;
}
```

**VM — набор инструкций (`instruction.dart`):**

```
PUSH_CONST k | DUP | POP
LOAD_VAR slot | STORE_VAR slot
LOAD_PIN_STATE | BIN_OP(op) | UN_OP(op) | CAST(toType)
CALL_BUILTIN id(argc) | CALL_USER addr(argc) | RET
JMP addr | JMP_IF_FALSE addr | JMP_IF_TRUE addr
YIELD_DELAY ms | YIELD_MICROS us | YIELD_FRAME      // кооперативная отдача управления
HALT
```

- `Setup` и `loop` компилируются как две `FunctionDef`; драйвер цикла: `setup()` → `while(true) loop()`.
- Защита: `maxInstructionsPerTick` (по умолчанию 200 000) и `maxLoopIterationsPerTick`; при превышении → `RuntimeFault(infiniteLoop)` → пауза + тост в UI + подсветка блока по `blockId`.
- Отладочная карта `debug_map.dart`: `instructionIndex → blockId`.

### 3.6 Контракт: блочная модель (`lib/blocks/model/`)

```dart
enum BlockCategory { control, pins, math, logic, text, serial, variables, components }

class BlockDefinition {
  final String type;              // 'control_if','pins_digitalWrite','components_lcd_print'
  final BlockCategory category;
  final String label;             // 'digital write %1 %2'
  final List<BlockSlot> slots;    // statement-слоты (вложенность) и value-слоты
  final List<BlockField> fields;  // dropdown/число/текст
}

class BlockField { final String name; final BlockFieldKind kind; final List<String>? options; final dynamic defaultValue; }
enum BlockFieldKind { dropdown, numberInput, textInput, pinDropdown, colorPicker }

class BlockInstance {
  final String id;                       // uuid
  final String type;                     // → BlockDefinition
  final Map<String, dynamic> fields;     // значения dropdown/чисел
  final Map<String, String?> inputs;     // value-слот → id блока-значения
  final Map<String, List<String>> statements; // statement-слот → список id детей
  final String? next;                    // следующий блок в цепочке (как в Scratch)
}

class BlockProgram {                     // корень блочной программы
  final Map<String, BlockInstance> blocks; // id → блок (плоская карта, связи по id)
  final String? setupFirst, loopFirst;     // головы цепочек setup()/loop()
  final List<String> globals;              // объявленные переменные
  final List<UserFunction> functions;      // пользовательские функции из блоков
}
```

**Категории и блоки MVP:**

| Категория | Блоки |
|---|---|
| **Control** | `if`, `if_else`, `repeat_n`, `while`, `for_range`, `forever`, `wait_ms`, `wait_us`, `break_loop` *(опц.)*, `call_function` |
| **Pins** | `pinMode(pin, mode)`, `digitalWrite(pin, HIGH/LOW)`, `digitalRead(pin)` → value, `analogWrite(pin, 0..255)`, `analogRead(pin)` → value, `pulseIn(pin)` → value |
| **Math** | `+ - × ÷`, `%`, `map()`, `constrain()`, `min/max`, `abs`, `random(min,max)` |
| **Logic** | `=, ≠, <, ≤, >, ≥`, `and`, `or`, `not`, `true/false` |
| **Text** | строковый литерал, `join(a,b)`, `number→string` |
| **Variables** | объявить, `set`, `change(+1)`, `get` |
| **Serial** | `begin(baud)`, `print(x)`, `println(x)`, `available()`, `read()`, `readLine()` |
| **Components** | `servo.attach/write/read`, `tone/noTone`, `rgb.setColor(r,g,b)`, `lcd.init/backlight/clear/setCursor/print`, `ultrasonic.distance(trig,echo)`, `dht.temperature(pin)`, `dht.humidity(pin)`, `sevenSeg.show(digit)` *(опц.)* |

### 3.7 Контракт: кодогенерация (`lib/blocks/codegen/`)

```dart
// 1) Блоки → IR
abstract class SketchGenerator {
  GenerationResult generate(BlockProgram program, Circuit circuit);
}
class GenerationResult { final SketchIR ir; final List<CodegenDiagnostic> diagnostics; }

// 2) IR → C++ текст (read-only preview)
abstract class SketchPrinter { String print(SketchIR ir); }

// 3) IR → инструкции VM
abstract class SketchCompiler { CompiledProgram compile(SketchIR ir); }
class CompiledProgram { final List<Instruction> instructions; final DebugMap debug; final int setupAddr, loopAddr; }
```

**IR (AST) — узлы:** `FunctionDef(setup|loop|user)`, `VarDecl`, `Assign`, `ExprStmt`, `If`, `While`, `For`, `BlockStmt`, `Call(name, args)`, `Builtin(name, args)`, `Binary(op,l,r)`, `Unary(op,x)`, `Literal`, `VarRef`, `PinConstant(pinId, HIGH|LOW|INPUT|OUTPUT|INPUT_PULLUP)`.

**Пример кодогенерации (golden):**
```
Blocks:              setup: pinMode(D13, OUTPUT)
                     loop:  digitalWrite(D13,HIGH); delay(500); digitalWrite(D13,LOW); delay(500)
        ↓ SketchPrinter
void setup() {
  pinMode(13, OUTPUT);
}
void loop() {
  digitalWrite(13, HIGH);
  delay(500);
  digitalWrite(13, LOW);
  delay(500);
}
```

### 3.8 Контракт: JSON-схема проекта (schemaVersion = 1)

```jsonc
{
  "schemaVersion": 1,
  "meta": { "name": "Blink", "author": "arduino_lab", "description": "...",
            "createdAt": "2026-10-13T10:00:00Z", "updatedAt": "2026-10-13T10:00:00Z" },
  "board": { "componentId": "c-uno-1" },
  "components": [
    { "id": "c-uno-1", "type": "arduinoUno", "label": "Arduino UNO",
      "position": { "x": 200, "y": 160 }, "rotationDeg": 0, "props": {} },
    { "id": "c-led-1", "type": "led", "label": "LED", "position": { "x": 520, "y": 320 },
      "rotationDeg": 90, "props": { "color": "#FF3B30", "forwardVoltage": 1.9 } },
    { "id": "c-bb-1", "type": "breadboard", "label": "Breadboard", "position": { "x": 700, "y": 200 },
      "rotationDeg": 0, "props": { "columns": 30 } }
  ],
  "wires": [
    { "id": "w-1", "from": { "componentId": "c-uno-1", "pinId": "D13" },
      "to": { "componentId": "c-bb-1", "pinId": "10a" }, "color": "#E53935" }
  ],
  "blocks": {
    "setupFirst": "b-s1",
    "loopFirst": "b-l1",
    "blocks": {
      "b-s1": { "type": "pins_pinMode", "fields": { "pin": "D13", "mode": "OUTPUT" },
                "inputs": {}, "statements": {}, "next": null },
      "b-l1": { "type": "pins_digitalWrite", "fields": { "pin": "D13", "value": "HIGH" },
                "inputs": {}, "statements": {}, "next": "b-l2" },
      "b-l2": { "type": "control_wait_ms", "fields": { "ms": 500 }, "inputs": {},
                "statements": {}, "next": "b-l3" }
    },
    "globals": [], "functions": []
  },
  "view": { "camera": { "x": 0, "y": 0 }, "zoom": 1.0 },
  "tutorialGoals": ["Заставить LED мигать раз в секунду"]
}
```

**Правила версионирования:** `schemaVersion` обязателен; `ProjectCodec.fromJson` кидает `UnsupportedSchemaError` при `version > supported`; при `version < supported` — прогоняет миграции `migrations.dart` (цепочка `v1→v2→…`).

---

## 4. Дерево каталогов `lib/` (с назначением каждого файла)

```
arduino_lab/
├── pubspec.yaml
├── analysis_options.yaml                 # strict lints, 0 ошибок analyze
├── README.md                             # быстрый старт, скриншоты
├── PLAN.md                               # этот план (копия)
├── assets/
│   ├── icons/                            # иконки категорий блоков, палитры
│   └── lessons/                          # тексты уроков/подсказок (ru/en)
└── lib/
    ├── main.dart                         # runApp, MultiProvider-обвязка
    ├── app.dart                          # MaterialApp, роутинг, тема, локале-заглушка
    │
    ├── core/
    │   ├── constants.dart                # константы: размеры сетки, лимиты VM, цвета пинов
    │   ├── ids.dart                      # генерация uuid, IdFactory (детерминируемая в тестах)
    │   ├── result.dart                   # Result<T,E>, не кидать исключения на границах слоёв
    │   ├── json_utils.dart               # безопасное чтение полей (int/double/Offset)
    │   └── units.dart                    # Offset/Vector, преобразование мировых ↔ экранных координат
    │
    ├── models/                           # ЧИСТЫЙ DART (без Flutter)
    │   ├── pin.dart                      # Pin, PinKind, PinDirection, PinRef, логические номера
    │   ├── component.dart                # abstract Component + copyWith + pinPosition()
    │   ├── components/
    │   │   ├── arduino_uno.dart          # 14 digital (D0–D13) + 6 analog (A0–A5) + POWER (5V/3.3V/GND/VIN)
    │   │   ├── breadboard.dart           # 30 колонок a–j + 4 шины; BreadboardNetRules (неявные связи)
    │   │   ├── led.dart                  # Vf, цвет, полярность
    │   │   ├── rgb_led.dart              # 3 канала R/G/B + общий катод/анод
    │   │   ├── resistor.dart             # номинал
    │   │   ├── push_button.dart          # 4 вывода (два Refs-пина), состояние pressed
    │   │   ├── potentiometer.dart        # 3 пина, положение 0..1 → делитель
    │   │   ├── servo.dart                # сигнальный + питание, угол 0..180
    │   │   ├── buzzer.dart               # пьезо, частота/нота
    │   │   ├── lcd_i2c.dart              # GND/VCC/SDA/SCL, I2C 0x27, 2×16
    │   │   ├── ultrasonic_hc_sr04.dart   # VCC/TRIG/ECHO/GND
    │   │   ├── dht11.dart                # VCC/DATA/GND, диапазоны T/RH
    │   │   ├── photoresistor.dart        # R(lightLevel)
    │   │   ├── seven_segment.dart        # ОПЦИОНАЛЬНО: a–g,dp
    │   │   └── component_factory.dart    # type → конкретный Component (единственная точка создания)
    │   ├── wire.dart                     # Wire: from/to (componentId,pinId), цвет
    │   ├── circuit.dart                  # агрегат Circuit + операции add/remove + валидация
    │   ├── project.dart                  # Project = meta + circuit + blocks + view (+tutorialGoals)
    │   ├── project_meta.dart             # name/author/createdAt/updatedAt
    │   ├── view_state.dart               # camera x/y, zoom
    │   └── serialization/
    │       ├── schema_version.dart       # SUPPORTED_VERSION = 1
    │       ├── project_codec.dart        # Project → JSON → Project (ручной, без codegen)
    │       └── migrations.dart           # цепочка миграций версий схемы
    │
    ├── engine/                           # ЧИСТЫЙ DART, ядро симуляции
    │   ├── net/
    │   │   ├── pin_ref.dart              # PinRef (componentId, pinId), равенство/хеш
    │   │   ├── net.dart                  # Net: электрически общий узел
    │   │   ├── union_find.dart           # DSU для слияния узлов
    │   │   └── netlist_builder.dart      # провода + breadboard-дорожки → Netlist
    │   ├── solver/
    │   │   ├── mna_matrix.dart           # разреженная матрица + right-hand side
    │   │   ├── linear_solver.dart        # Гаусс с частичным выбором ведущего элемента
    │   │   ├── device_models.dart        # stamp-правила: Resistor, Led, Switch, Pot, Source, Pullup
    │   │   ├── convergence.dart          # fixed-point итерация для нелинейных (LED)
    │   │   └── circuit_solver.dart       # сборка MNA + решение + CircuitSolution
    │   ├── runtime/
    │   │   ├── arduino_runtime.dart      # фасад публичного Arduino API
    │   │   ├── virtual_clock.dart        # виртуальное время, микрос/миллис, масштаб скорости
    │   │   ├── pin_state.dart            # режимы пинов, drive states, PWM duty
    │   │   ├── serial_log.dart           # буфер Serial Monitor + очередь входных данных
    │   │   ├── scheduler.dart            # отложенные события (tone(duration), servo-анимация)
    │   │   └── builtins.dart             # map, constrain, min/max/abs, random, tone/noTone
    │   ├── vm/
    │   │   ├── instruction.dart          # opcode + операнды + трассировка
    │   │   ├── compiler.dart             # SketchIR → инструкции + DebugMap
    │   │   ├── debug_map.dart            # instructionIndex → blockId
    │   │   ├── value.dart                # Value (int/double/bool/String) + арифметика Arduino-семантики
    │   │   └── interpreter.dart          # стековая VM с YIELD и бюджетом инструкций
    │   ├── devices/
    │   │   ├── device.dart               # интерфейс Device + DeviceSnapshot
    │   │   ├── device_context.dart       # мост Device ↔ runtime (analogReadRaw, scheduleEvent)
    │   │   ├── device_registry.dart      # создание устройств по компонентам схемы
    │   │   ├── led_device.dart           # яркость из тока
    │   │   ├── rgb_led_device.dart
    │   │   ├── button_device.dart        # pressed → к схеме (управляет ключом)
    │   │   ├── potentiometer_device.dart # wiper → analogRead
    │   │   ├── photoresistor_device.dart
    │   │   ├── servo_device.dart         # угол, плавная анимация к целевой позиции
    │   │   ├── buzzer_device.dart        # активная нота/частота, длительность
    │   │   ├── lcd_device.dart           # буфер 2×16, курсор, backlight
    │   │   ├── ultrasonic_device.dart    # выдаёт ECHO-импульс по TRIG-событию
    │   │   ├── dht11_device.dart         # T/RH с шумом, фиксированный seed в тестах
    │   │   └── seven_segment_device.dart # ОПЦИОНАЛЬНО
    │   ├── simulation_engine.dart        # оркестратор: init/runs/step/pause/reset, cadence
    │   ├── simulation_config.dart        # fps, speedMultiplier, instructionBudget, limits
    │   └── errors.dart                   # RuntimeFault, RuntimeFaultKind, SolverError
    │
    ├── blocks/                           # ЧИСТЫЙ DART, блочный язык
    │   ├── model/
    │   │   ├── block_category.dart       # enum + метаданные (иконка, цвет)
    │   │   ├── block_definition.dart     # описание блока (слоты, поля)
    │   │   ├── block_instance.dart       # экземпляр блока (id, поля, связи)
    │   │   ├── block_program.dart        # корень программы (плоская карта блоков)
    │   │   ├── user_function.dart        # пользовательская функция из блоков
    │   │   ├── block_ops.dart            # операции над программой: add/remove/move/attach/detach
    │   │   └── defs/
    │   │       ├── control_blocks.dart
    │   │       ├── pin_blocks.dart
    │   │       ├── math_blocks.dart
    │   │       ├── logic_blocks.dart
    │   │       ├── text_blocks.dart
    │   │       ├── serial_blocks.dart
    │   │       ├── variable_blocks.dart
    │   │       ├── component_blocks.dart
    │   │       └── block_registry.dart   # type → BlockDefinition (единая точка)
    │   └── codegen/
    │       ├── sketch_ir.dart            # AST-узлы IR
    │       ├── sketch_generator.dart     # BlockProgram → SketchIR + диагностика
    │       ├── sketch_printer.dart       # SketchIR → C++ текст (preview)
    │       ├── codegen_diagnostic.dart   # ошибки: пустой пин, неверный тип слота
    │       └── codegen_golden/           # вход/ожидаемый C++ для golden-тестов
    │
    ├── services/
    │   ├── project_repository.dart       # load/save/import/export через StorageBackend
    │   ├── storage/
    │   │   ├── storage_backend.dart      # интерфейс: read/write/list/delete
    │   │   ├── file_storage_backend.dart # desktop/mobile через path_provider
    │   │   └── local_storage_backend.dart# web через shared_preferences
    │   ├── examples_service.dart         # доступ к встроенной библиотеке примеров
    │   ├── lesson_service.dart           # проверка целей урока по состоянию симуляции
    │   ├── settings_service.dart         # тема, последний проект, скорость симуляции
    │   └── share_export_service.dart     # экспорт/импорт .arduinolab (JSON) через file_picker
    │
    ├── state/                            # Provider ChangeNotifier-провайдеры
    │   ├── circuit_provider.dart         # схема: add/remove/rotate/выделение, провода
    │   ├── editor_tool_provider.dart     # активный инструмент: select/wire/pan, черновик провода
    │   ├── block_provider.dart           # блочная программа + undo/redo
    │   ├── simulation_provider.dart      # run/pause/stop/reset/speed, snapshot'ы устройств
    │   ├── serial_monitor_provider.dart  # лог + отправка строк в runtime
    │   ├── project_provider.dart         # текущий Project, dirty-флаг, сохранение
    │   └── examples_provider.dart        # список/загрузка примеров
    │
    ├── examples/                         # встроенные проекты (данные, не логика)
    │   ├── example_registry.dart         # список ExampleDefinition (имя, код, сборщик)
    │   ├── example_definition.dart       # метаданные + построение Project
    │   ├── blink.dart
    │   ├── button_led.dart
    │   ├── potentiometer_led.dart
    │   ├── servo_sweep.dart
    │   ├── buzzer_melody.dart
    │   ├── lcd_hello.dart
    │   ├── ultrasonic_distance.dart
    │   └── dht11_read.dart
    │
    ├── ui/
    │   ├── screens/
    │   │   ├── home_screen.dart          # старт: недавние, примеры, новый проект
    │   │   ├── workspace_screen.dart     # главный экран (адаптивная раскладка)
    │   │   └── examples_screen.dart      # галерея уроков/примеров
    │   ├── layout/
    │   │   ├── adaptive_scaffold.dart    # desktop: 3 колонки; mobile: табы/шторки; web: 2 колонки
    │   │   └── panel_layout.dart         # resizable-панели, запоминание размеров
    │   ├── canvas/
    │   │   ├── circuit_canvas.dart       # GestureDetector-хост + стек слоёв
    │   │   ├── canvas_painter.dart       # grid, провода (кривые), выделение
    │   │   ├── grid_painter.dart         # оптимизированный grid при zoom/pan
    │   │   ├── canvas_controller.dart    # камера, zoom/pan, snap-to-grid, hit-test
    │   │   ├── hit_test.dart             # компонент/пин/провод под курсором
    │   │   ├── wire_draft_layer.dart     # «резиновая» линия при рисовании провода
    │   │   └── selection_box.dart        # рамка выделения, множественный выбор
    │   ├── widgets/
    │   │   ├── component_palette.dart    # палитра компонентов (drag-source)
    │   │   ├── component_inspector.dart  # свойства выбранного + поворот/удаление
    │   │   ├── property_editors.dart     # слайдеры: сопротивление, угол серво, свет, α потенц.
    │   │   ├── simulation_toolbar.dart   # Run/Pause/Stop/Reset, скорость, статус
    │   │   ├── serial_monitor.dart       # лог + поле ввода (Serial.read)
    │   │   ├── sketch_preview.dart       # read-only C++ с подсветкой (без редактирования)
    │   │   ├── pin_badge.dart            # подпись пина на холсте
    │   │   └── fault_banner.dart         # баннер ошибки runtime + переход к блоку
    │   ├── components/                   # отрисовка компонентов на холсте
    │   │   ├── component_renderer.dart   # диспетчер type → painter виджета
    │   │   └── renderers/
    │   │       ├── arduino_uno_view.dart
    │   │       ├── breadboard_view.dart
    │   │       ├── led_view.dart         # свечение ∝ яркости
    │   │       ├── rgb_led_view.dart
    │   │       ├── resistor_view.dart
    │   │       ├── push_button_view.dart
    │   │       ├── potentiometer_view.dart
    │   │       ├── servo_view.dart       # стрелка угла
    │   │       ├── buzzer_view.dart
    │   │       ├── lcd_view.dart         # текст 2×16, курсор
    │   │       ├── ultrasonic_view.dart
    │   │       ├── dht11_view.dart
    │   │       ├── photoresistor_view.dart
    │   │       └── seven_segment_view.dart
    │   ├── blocks/
    │   │   ├── block_canvas.dart         # холст блочной программы (скролл/зум)
    │   │   ├── block_palette.dart        # палитра блоков по категориям
    │   │   ├── block_widget.dart         # отрисовка одного блока (слоты/поля)
    │   │   ├── block_field_widgets.dart  # dropdown пинов, числовые/текстовые поля
    │   │   ├── block_snap.dart           # поиск цели при drop (statement/value-слот)
    │   │   ├── block_geometry.dart       # метрики: размеры по слотам, отступы, notch
    │   │   └── block_highlighter.dart    # подсветка блока при RuntimeFault
    │   └── theme/
    │       ├── app_theme.dart            # светлая/тёмная тема
    │       └── design_tokens.dart        # цвета пинов/проводов/категорий (НЕ purple/violet!)
    │
    └── utils/
        ├── geometry.dart                 # поворот точки, пересечение отрезков, bounding box
        └── extensions.dart               # Iterable/Offset/Color удобства
```

**Итого:** ~118 Dart-файлов (без тестов), ≈ 11–14 k строк кода.

---

## 5. Этапы (milestones) и задачи

### Граф зависимостей

```
M0 Bootstrap ──► M1 Models+JSON ──┬─► M2 Electricity ──┐
                                  ├─► M3 Runtime/VM ───┼─► M5 SimulationEngine ──┐
                                  └─► M4 Blocks/Codegen┘                        │
                                  └─► M6 Services+Examples ─────────────────────┤
M1 ─────────────────────────────────────► M7 Canvas ──► M8 Renderers ──► M10 Panels/Layout ─┐
M4 ─────────────────────────────────────► M9 Block Editor ────────────────────────────────┴─► M11 Examples UX ──► M12 Verification
```

**Правило параллелизма:** `backend-specialist` ведёт M1–M6 (чистый Dart), `frontend-specialist` — M7–M11 (Flutter UI) начиная с M7 сразу после M1. Конфликтов нет: разные каталоги, интерфейсы зафиксированы в §3.

---

### M0 — Bootstrap проекта
**Agent:** frontend-specialist · **Depends:** — · **DoD:** проект собирается, analyze чистый.

| ID | Задача | Agent | Skill | Depends | INPUT → OUTPUT → VERIFY |
|---|---|---|---|---|---|
| T0.1 | `flutter create` c платформами windows/web/android/ios | frontend-specialist | clean-code | — | IN: пустая папка · OUT: `C:\develop\arduino_lab` со скелетом · VERIFY: `flutter run -d windows` запускает Counter |
| T0.2 | Зависимости (`provider, uuid, path_provider, shared_preferences, file_picker`) | frontend-specialist | clean-code | T0.1 | IN: pubspec · OUT: обновлённый pubspec.yaml · VERIFY: `flutter pub get` без конфликтов |
| T0.3 | `analysis_options.yaml` strict + каталоги `lib/{core,models,engine,blocks,services,state,examples,ui,utils}` с `.gitkeep` | frontend-specialist | lint-and-validate | T0.1 | IN: скелет · OUT: структура + линт · VERIFY: `flutter analyze` = 0 issues |
| T0.4 | `design_tokens.dart` + `app_theme.dart` (свободные от purple-запрета палитры) | frontend-specialist | frontend-design | T0.3 | IN: токены · OUT: тема приложения · VERIFY: визуальный smoke + отсутствие violet-хексов |
| T0.5 | Копия плана в `arduino_lab/PLAN.md`, план-чеклист в README | project-planner | plan-writing | T0.1 | IN: PLAN_arduino_lab.md · OUT: PLAN.md · VERIFY: файл читается, секции на месте |

---

### M1 — Доменные модели + сериализация (чистый Dart)
**Agent:** backend-specialist · **Depends:** M0 · **DoD:** модели сериализуются round-trip, тесты зелёные.

| ID | Задача | Agent | Skill | Depends | INPUT → OUTPUT → VERIFY |
|---|---|---|---|---|---|
| T1.1 | `core/`: `ids, result, json_utils, units, constants` | backend-specialist | clean-code | T0.3 | IN: требования §3.2 · OUT: 5 файлов core · VERIFY: unit-тест json_utils на устойчивость к мусору |
| T1.2 | `pin.dart` + `component.dart` (abstract, `pinPosition`, `copyWith`) | backend-specialist | clean-code | T1.1 | IN: контракт Pin/Component · OUT: 2 файла · VERIFY: тест поворота: пин D13 при 90° лежит где ожидается |
| T1.3 | Все `models/components/*` + `component_factory` (13 типов, seven_segment — stub) | backend-specialist | clean-code | T1.2 | IN: таблица пинов каждого компонента · OUT: 15 файлов · VERIFY: тест «для каждого типа: pins непротиворечивы, нет дублей id» |
| T1.4 | `breadboard.dart` + `BreadboardNetRules` (шины + 2 группы по 5 в колонке, разрыв e/f) | backend-specialist | architecture | T1.3 | IN: правила §3.2 · OUT: 1 файл · VERIFY: тест: `10a` соединён с `10e`, но НЕ с `10f`; `top+` соединён по всей длине |
| T1.5 | `wire.dart`, `circuit.dart`, `project*.dart`, `view_state.dart` | backend-specialist | clean-code | T1.3 | IN: контракт Circuit/Project · OUT: 5 файлов · VERIFY: тест каскадного удаления компонента вместе с проводами |
| T1.6 | `serialization/project_codec.dart` + `schema_version.dart` + `migrations.dart` | backend-specialist | clean-code | T1.5, T4.1 | IN: JSON-схема §3.8 · OUT: 3 файла · VERIFY: round-trip тест на всех 8 примерах |
| T1.7 | Тесты моделей: `test/models/*_test.dart` | test-engineer | testing-patterns | T1.6 | IN: контракты · OUT: ≥ 5 тест-файлов · VERIFY: `flutter test test/models` зелёный, покрытие models ≥ 90% |

---

### M2 — Электрический движок (netlist + MNA)
**Agent:** backend-specialist · **Depends:** M1 · **DoD:** физика корректна на эталонных схемах.

| ID | Задача | Agent | Skill | Depends | INPUT → OUTPUT → VERIFY |
|---|---|---|---|---|---|
| T2.1 | `net/pin_ref, net, union_find` | backend-specialist | clean-code | T1.4 | IN: PinRef/Net · OUT: 3 файла · VERIFY: DSU-тест на 1000 слияний |
| T2.2 | `net/netlist_builder.dart`: провода → узлы, затем breadboard-дорoжки | backend-specialist | architecture | T2.1 | IN: Circuit · OUT: 1 файл · VERIFY: тест «LED через breadboard 10a→10e даёт один узел» |
| T2.3 | `solver/mna_matrix.dart` + `linear_solver.dart` (Гаусс) | backend-specialist | clean-code | T1.1 | IN: MNA-теория · OUT: 2 файла · VERIFY: тест линейной системы 5×5 с известным ответом ±1e-9 |
| T2.4 | `solver/device_models.dart`: Resistor, Switch, Source, Pullup, Pot | backend-specialist | architecture | T2.3 | IN: stamp-таблица §3.3 · OUT: 1 файл · VERIFY: тест делителя: 5V–R1(1k)–узел–R2(1k)–GND → 2.5V ±1% |
| T2.5 | `solver/device_models.dart`: LED (кусочно-линейный) + `convergence.dart` | backend-specialist | architecture | T2.4 | IN: Vf≈1.9, Rdyn≈150Ω · OUT: 2 файла · VERIFY: тест: LED+R(220Ω) к 5V → I ≈ 13–15 мА ±10% |
| T2.6 | `solver/circuit_solver.dart` → `CircuitSolution` (напряжения, токи LED, analogRead, digitalRead, warnings) | backend-specialist | architecture | T2.5 | IN: PinDriveStates · OUT: 1 файл · VERIFY: тест кнопки: INPUT_PULLUP + кнопка на GND → HIGH при отпускании, LOW при нажатии |
| T2.7 | Тесты электрики: `test/engine/electricity/*_test.dart` | test-engineer | testing-patterns | T2.6 | IN: эталонные схемы · OUT: ≥ 6 тест-файлов (делитель, LED, pot, pullup, short-circuit warning, breadboard) | VERIFY: зелёные, допуски S3 выполнены |

---

### M3 — Arduino runtime + стековая VM
**Agent:** backend-specialist · **Depends:** M1, M2 · **DoD:** скетч исполняется кооперативно, `delay` не блокирует UI, бесконечный цикл ловится.

| ID | Задача | Agent | Skill | Depends | INPUT → OUTPUT → VERIFY |
|---|---|---|---|---|---|
| T3.1 | `runtime/virtual_clock.dart` + `scheduler.dart` | backend-specialist | clean-code | T1.1 | IN: виртуальное время · OUT: 2 файла · VERIFY: тест: 1000×delay(1) → 1.000 с виртуального времени |
| T3.2 | `runtime/pin_state.dart` + `serial_log.dart` | backend-specialist | clean-code | T3.1 | IN: PinDriveStates/Serial · OUT: 2 файла · VERIFY: тест Serial буфера (print + println + available/read) |
| T3.3 | `vm/value.dart` (int/double/bool/String, Arduino-семантика: int×int=int, деление на 0 → fault) | backend-specialist | clean-code | T3.1 | IN: правила типов · OUT: 1 файл · VERIFY: тест: 5/2 = 2; 5.0/2 = 2.5; map(512,0,1023,0,255)=127 |
| T3.4 | `vm/instruction.dart` + `vm/compiler.dart` + `debug_map.dart` | backend-specialist | architecture | T3.3, T4.3 | IN: IR §3.7 · OUT: 3 файла · VERIFY: тест: компиляция blink-IR даёт ожидаемую последовательность opcode |
| T3.5 | `vm/interpreter.dart` (стек, вызовы, YIELD, бюджеты, fault) | backend-specialist | architecture | T3.4 | IN: инструкции · OUT: 1 файл · VERIFY: тест: `while(true){}` → fault `infiniteLoop` за ≤ 200k инструкций; `delay(500)` → `yieldedOnDelay=true` |
| T3.6 | `runtime/builtins.dart`: полный API §3.5 (Pins/Time/Math/Serial/Audio) + `RuntimeEvent` | backend-specialist | clean-code | T3.2, T3.5 | IN: список API · OUT: 1 файл · VERIFY: тест каждого builtin минимум одним кейсом |
| T3.7 | `runtime/arduino_runtime.dart`: фасад, `setup`+`loop` драйвер, `reset`, `tick` | backend-specialist | architecture | T3.6 | IN: интерфейс §3.5 · OUT: 1 файл · VERIFY: тест: blink-программа за 2 виртуальные секунды даёт 2 переключения D13 |
| T3.8 | `engine/errors.dart` (RuntimeFault*), интеграция fault → `blockId` | backend-specialist | clean-code | T3.7 | IN: DebugMap · OUT: 1 файл · VERIFY: тест: fault в loop несёт непустой blockId |
| T3.9 | Тесты runtime/VM: `test/engine/runtime/*_test.dart`, `test/engine/vm/*_test.dart` | test-engineer | tdd-workflow | T3.8 | IN: API · OUT: ≥ 8 тест-файлов · VERIFY: зелёные; покрытие engine/vm ≥ 85% |

---

### M4 — Блочная модель и кодогенерация
**Agent:** backend-specialist · **Depends:** M1 · **DoD:** блок-программа → корректный C++ и корректный IR.

| ID | Задача | Agent | Skill | Depends | INPUT → OUTPUT → VERIFY |
|---|---|---|---|---|---|
| T4.1 | `blocks/model/`: category, definition, instance, program, user_function, block_ops | backend-specialist | clean-code | T1.5 | IN: контракт §3.6 · OUT: 6 файлов · VERIFY: тест: attach/detach/next-цепочка сохраняет отсутствие циклов-сирот |
| T4.2 | `blocks/model/defs/*` + `block_registry` (все блоки таблицы §3.6) | backend-specialist | clean-code | T4.1 | IN: таблица блоков · OUT: 9 файлов · VERIFY: тест: registry содержит все типы, у каждого поля есть default |
| T4.3 | `blocks/codegen/sketch_ir.dart` (AST) | backend-specialist | architecture | T4.1 | IN: §3.7 · OUT: 1 файл · VERIFY: тест сериализации IR в debug-строку |
| T4.4 | `sketch_generator.dart`: блоки → IR + диагностика (пустой пин, неверный тип слота) | backend-specialist | architecture | T4.2, T4.3 | IN: BlockProgram + Circuit · OUT: 2 файла · VERIFY: тест: блок с pin='' → diagnostic `pinNotSelected`, IR не содержит мусора |
| T4.5 | `sketch_printer.dart`: IR → C++ (отступы в 2 пробела, `void setup/loop`, `#define` для констант пинов) | backend-specialist | clean-code | T4.4 | IN: IR · OUT: 1 файл · VERIFY: golden: пустая программа → `void setup() {}\nvoid loop() {}` |
| T4.6 | Golden-набор `codegen_golden/` (≥ 20 программ: blink, if/else, for, map, serial, servo, lcd) | test-engineer | testing-patterns | T4.5 | IN: примеры блоков · OUT: ≥ 20 пар файлов + `test/blocks/sketch_printer_golden_test.dart` · VERIFY: `flutter test` зелёный (S2) |
| T4.7 | Тесты блочной модели: `test/blocks/*_test.dart` | test-engineer | testing-patterns | T4.5 | IN: API block_ops · OUT: ≥ 4 тест-файла · VERIFY: зелёные, покрытие blocks ≥ 85% |

---

### M5 — SimulationEngine (интеграция)
**Agent:** backend-specialist · **Depends:** M2, M3, M4 · **DoD:** end-to-end: пример Blink даёт мигающий LED в snapshot.

| ID | Задача | Agent | Skill | Depends | INPUT → OUTPUT → VERIFY |
|---|---|---|---|---|---|
| T5.1 | `devices/device.dart` + `device_context.dart` + `device_registry.dart` | backend-specialist | architecture | T3.7 | IN: интерфейс Device · OUT: 3 файла · VERIFY: тест: registry создаёт ровно по одному Device на каждый компонент-устройство |
| T5.2 | `led_device`, `rgb_led_device`, `button_device`, `potentiometer_device`, `photoresistor_device` | backend-specialist | clean-code | T5.1 | IN: stamp/снапшот-правила · OUT: 5 файлов · VERIFY: тест: LED snapshot.brightness ∈ [0,1] и ∝ току |
| T5.3 | `servo_device`, `buzzer_device`, `lcd_device`, `ultrasonic_device`, `dht11_device` | backend-specialist | clean-code | T5.1 | IN: протоколы устройств · OUT: 5 файлов · VERIFY: тест servo: write(90) → снапшот угла 90; тест LCD: print("Hi") → буфер «Hi» |
| T5.4 | `simulation_config.dart` + `simulation_engine.dart` (init/step/pause/reset, каденс, snapshot-шина) | backend-specialist | architecture | T5.2, T5.3 | IN: §3.5–3.6 · OUT: 2 файла · VERIFY: тест: 60 шагов по 16.6мс не превышают бюджет инструкций на шаг |
| T5.5 | Авто-детект бесконечного цикла → пауза + fault (S4) | backend-specialist | architecture | T5.4 | IN: бюджеты · OUT: изменение в engine + `test/engine/infinite_loop_test.dart` · VERIFY: `while(true){}` → paused=true, fault.infiniteLoop, ≤ 1000 мс |
| T5.6 | Интеграционные тесты примеров: `test/integration/example_run_test.dart` (8 примеров × 5 вирт. секунд) | test-engineer | webapp-testing | T5.5, M6 | IN: 8 примеров · OUT: тест-файл · VERIFY: зелёный (S1) |

---

### M6 — Сервисы, персистентность, библиотека примеров
**Agent:** backend-specialist · **Depends:** M1, M4 · **DoD:** 8 примеров существуют как данные, save/load работает.

| ID | Задача | Agent | Skill | Depends | INPUT → OUTPUT → VERIFY |
|---|---|---|---|---|---|
| T6.1 | `storage_backend.dart` + `file_storage_backend.dart` + `local_storage_backend.dart` | backend-specialist | clean-code | T1.6 | IN: платформенная специфика · OUT: 3 файла · VERIFY: тест с fake-backend: write→list→read→delete |
| T6.2 | `project_repository.dart` + `share_export_service.dart` (`.arduinolab` JSON) | backend-specialist | clean-code | T6.1 | IN: ProjectCodec · OUT: 2 файла · VERIFY: тест: save→load возвращает идентичный Project |
| T6.3 | `settings_service.dart` (тема, скорость, последний проект) | backend-specialist | clean-code | T6.1 | IN: настройки · OUT: 1 файл · VERIFY: тест round-trip настроек |
| T6.4 | `example_definition.dart` + `example_registry.dart` | backend-specialist | clean-code | T4.2 | IN: 8 примеров · OUT: 2 файла · VERIFY: тест: registry.get('blink').build() даёт непустые circuit+blocks |
| T6.5 | 8 примеров: `blink, button_led, potentiometer_led, servo_sweep, buzzer_melody` | backend-specialist | clean-code | T6.4 | IN: спеки примеров · OUT: 5 файлов · VERIFY: тест: схема+блоки каждого проходят валидацию (нет висячих проводов) |
| T6.6 | 3 примера с устройствами: `lcd_hello, ultrasonic_distance, dht11_read` | backend-specialist | clean-code | T6.5 | IN: спеки · OUT: 3 файла · VERIFY: unit: sketch_printer выдаёт корректный C++ для каждого |
| T6.7 | `lesson_service.dart` (проверка tutorialGoals по CircuitSolution/snapshots) | backend-specialist | clean-code | T6.6, T5.4 | IN: goals · OUT: 1 файл · VERIFY: тест: goal «LED горит» срабатывает при brightness > 0.3 |
| T6.8 | Тесты сервисов: `test/services/*_test.dart` | test-engineer | testing-patterns | T6.7 | IN: сервисы · OUT: ≥ 4 тест-файла · VERIFY: зелёные |

---

### M7 — Холст схемы (UI)
**Agent:** frontend-specialist · **Depends:** M1 · **DoD:** можно собрать схему мышью: поставить, перетащить, повернуть, соединить проводами.

| ID | Задача | Agent | Skill | Depends | INPUT → OUTPUT → VERIFY |
|---|---|---|---|---|---|
| T7.1 | `state/circuit_provider.dart` + `editor_tool_provider.dart` | frontend-specialist | clean-code | T1.5 | IN: Circuit · OUT: 2 файла · VERIFY: widget-тест: addComponent/removeComponent меняет notify |
| T7.2 | `canvas/canvas_controller.dart` (камера, zoom/pan, snap-to-grid) + `utils/geometry.dart` | frontend-specialist | clean-code | T7.1 | IN: units · OUT: 2 файла · VERIFY: unit: world↔screen round-trip → исходные координаты |
| T7.3 | `grid_painter.dart` + `canvas_painter.dart` (grid, провода-кривые, выделение) | frontend-specialist | frontend-design | T7.2 | IN: токены темы · OUT: 2 файла · VERIFY: golden-скриншот холста со 3 компонентами и 2 проводами |
| T7.4 | `hit_test.dart` (компонент/пин/провод) | frontend-specialist | clean-code | T7.2 | IN: геометрия · OUT: 1 файл · VERIFY: unit: клик по пину D13 находит (uno, D13); клик между ними — ничего |
| T7.5 | `circuit_canvas.dart`: drag&drop из палитры, перетаскивание, поворот, выделение, удаление | frontend-specialist | frontend-design | T7.3, T7.4 | IN: провайдеры · OUT: 1 файл · VERIFY: widget-тест: drag компонента меняет position; rotate меняет rotationDeg |
| T7.6 | `wire_draft_layer.dart` + валидация соединений (нельзя пин↔пин одного типа питания дважды, нельзя дубликат провода) | frontend-specialist | clean-code | T7.5 | IN: правила валидации · OUT: 1 файл + `circuit_provider` правила · VERIFY: unit: дубль провода отклонён, конфликт пинов помечен warning |
| T7.7 | `state/project_provider.dart` (dirty-флаг, новый/открыть/сохранить) | frontend-specialist | clean-code | T7.1, T6.2 | IN: repository · OUT: 1 файл · VERIFY: widget-тест: изменение схемы → dirty=true, save → dirty=false |

---

### M8 — Отрисовка компонентов
**Agent:** frontend-specialist · **Depends:** M7 · **DoD:** все компоненты визуально различимы и реагируют на состояние.

| ID | Задача | Agent | Skill | Depends | INPUT → OUTPUT → VERIFY |
|---|---|---|---|---|---|
| T8.1 | `component_renderer.dart` + `arduino_uno_view.dart` + `breadboard_view.dart` | frontend-specialist | frontend-design | T7.5 | IN: pinned-геометрия пинов · OUT: 3 файла · VERIFY: golden: UNO рисует 20+ подписанных пинов |
| T8.2 | `led_view` (свечение ∝ brightness), `rgb_led_view`, `resistor_view` | frontend-specialist | frontend-design | T8.1 | IN: DeviceSnapshot · OUT: 3 файла · VERIFY: golden при brightness 0 и 1 различаются |
| T8.3 | `push_button_view` (нажатие), `potentiometer_view` (ручка), `photoresistor_view` | frontend-specialist | frontend-design | T8.2 | IN: UI-состояния · OUT: 3 файла · VERIFY: widget-тест: tap по кнопке ставит pressed=true в snapshot |
| T8.4 | `servo_view` (стрелка угла), `buzzer_view`, `lcd_view` (2×16 + backlight) | frontend-specialist | frontend-design | T8.3 | IN: snapshots · OUT: 3 файла · VERIFY: golden LCD с «Hello, World!» |
| T8.5 | `ultrasonic_view`, `dht11_view`, `seven_segment_view` (опц.) | frontend-specialist | frontend-design | T8.4 | IN: snapshots · OUT: 3 файла · VERIFY: golden каждом |
| T8.6 | Подключение живых snapshot'ов (провайдер симуляции → рендеры) | frontend-specialist | clean-code | T8.5, T5.4 | IN: SimulationProvider · OUT: изменения в renderers · VERIFY: widget-тест: после 1 с Blink LED brightness > 0 хотя бы раз |

---

### M9 — Блочный редактор (UI)
**Agent:** frontend-specialist · **Depends:** M4, M7 · **DoD:** программа собирается мышью и генерирует скетч.

| ID | Задача | Agent | Skill | Depends | INPUT → OUTPUT → VERIFY |
|---|---|---|---|---|---|
| T9.1 | `blocks/block_geometry.dart` (метрики по слотам) + `block_widget.dart` | frontend-specialist | frontend-design | T4.2 | IN: BlockDefinition · OUT: 2 файла · VERIFY: golden: block `if` рисуется с 2 слотами (cond + body) |
| T9.2 | `block_field_widgets.dart` (pinDropdown из Circuit, число, текст, цвет) | frontend-specialist | clean-code | T9.1 | IN: Circuit (список пинов) · OUT: 1 файл · VERIFY: widget-тест: dropdown содержит D0..D13, A0..A5, PWM-метку на 3/5/6/9/10/11 |
| T9.3 | `block_palette.dart` (категории, drag-source) | frontend-specialist | frontend-design | T9.2 | IN: block_registry · OUT: 1 файл · VERIFY: widget-тест: 8 категорий, drag стартует |
| T9.4 | `block_snap.dart` (нахождение statement/value-цели, вставка по геометрии) | frontend-specialist | architecture | T9.3 | IN: block_ops · OUT: 1 файл · VERIFY: unit: drop в body `repeat` вставляет в statements['body'] |
| T9.5 | `block_canvas.dart` (скролл/зум, цепочки setup/loop, drag&drop, удаление) | frontend-specialist | frontend-design | T9.4 | IN: BlockProgram · OUT: 1 файл · VERIFY: widget-тест: собрать blink из 5 блоков → blocks.length == 5 |
| T9.6 | `state/block_provider.dart` (undo/redo, dirty) | frontend-specialist | clean-code | T9.5 | IN: block_ops · OUT: 1 файл · VERIFY: unit: undo после удаления восстанавливает блок |
| T9.7 | `sketch_preview.dart` (read-only C++ + подсветка синтаксиса) | frontend-specialist | frontend-design | T9.5, T4.5 | IN: SketchPrinter · OUT: 1 файл · VERIFY: widget-тест: предпросмотр обновляется при изменении блоков, поле read-only |
| T9.8 | `block_highlighter.dart` (подсветка по RuntimeFault.blockId) | frontend-specialist | clean-code | T9.7, T3.8 | IN: fault.blockId · OUT: 1 файл · VERIFY: widget-тест: fault подсвечивает нужный блок |

---

### M10 — Панели, Serial Monitor, адаптивный layout
**Agent:** frontend-specialist · **Depends:** M8, M9 · **DoD:** рабочий экран workspace на desktop/mobile/web.

| ID | Задача | Agent | Skill | Depends | INPUT → OUTPUT → VERIFY |
|---|---|---|---|---|---|
| T10.1 | `component_palette.dart` + `component_inspector.dart` + `property_editors.dart` | frontend-specialist | frontend-design | T8.6 | IN: 13 компонентов · OUT: 3 файла · VERIFY: widget-тест: слайдер pot меняет props.position |
| T10.2 | `simulation_toolbar.dart` (Run/Pause/Stop/Reset/Speed/status) | frontend-specialist | frontend-design | T5.4 | IN: SimulationProvider · OUT: 1 файл · VERIFY: widget-тест: Run → engine.isRunning |
| T10.3 | `serial_monitor.dart` + `state/serial_monitor_provider.dart` (лог + ввод) | frontend-specialist | clean-code | T10.2, T3.2 | IN: SerialLog · OUT: 2 файла · VERIFY: widget-тест: println → строка в списке; отправка строки → в Serial.read |
| T10.4 | `fault_banner.dart` (ошибка + «перейти к блоку») | frontend-specialist | clean-code | T10.2 | IN: fault · OUT: 1 файл · VERIFY: widget-тест: infinite loop показывает баннер, клик зовёт highlight |
| T10.5 | `adaptive_scaffold.dart` + `panel_layout.dart`: desktop 3 колонки, mobile — табы + bottom sheets, web — 2 колонки | frontend-specialist | mobile-design | T10.4 | IN: требование адаптивности · OUT: 2 файла · VERIFY: golden при 1920×1080, 1280×800, 411×731 |
| T10.6 | `workspace_screen.dart` (сборка всего) + `home_screen.dart` | frontend-specialist | frontend-design | T10.5 | IN: все провайдеры · OUT: 2 файла · VERIFY: smoke: сборка схемы из примера Blink и запуск через UI (Playwright/integration_test) |

---

### M11 — Экран примеров/уроков и UX сохранения
**Agent:** frontend-specialist · **Depends:** M6, M10 · **DoD:** примеры грузятся, урок отслеживает цель.

| ID | Задача | Agent | Skill | Depends | INPUT → OUTPUT → VERIFY |
|---|---|---|---|---|---|
| T11.1 | `examples_screen.dart` + `state/examples_provider.dart` (галерея, превью, «Открыть») | frontend-specialist | frontend-design | T6.7, T10.6 | IN: ExamplesService · OUT: 2 файла · VERIFY: widget-тест: 8 карточек, открытие подставляет Project |
| T11.2 | Цели урока в UI: чек-лист задач, авто-галочка при достижении | frontend-specialist | clean-code | T11.1, T6.7 | IN: LessonService · OUT: изменения в workspace + `lesson_panel.dart` · VERIFY: widget-тест: goal выполняется при brightness>0.3 |
| T11.3 | Диалоги Save/Open/Export/Import (file_picker + storage) | frontend-specialist | clean-code | T7.7, T6.2 | IN: ProjectRepository · OUT: диалоги в workspace · VERIFY: интеграционный тест: сохранить → новый проект → открыть → схема совпадает |
| T11.4 | Онбординг-подсказки (tour по палитре/блокам/Run) | frontend-specialist | frontend-design | T11.3 | IN: тексты из assets/lessons · OUT: 1 файл · VERIFY: widget-тест: 3 шага показываются и закрываются |

---

### M12 — Верификация, тесты, сборки
**Agent:** test-engineer (+ frontend-specialist для сборок) · **Depends:** M1–M11 · **DoD:** PASS → PHASE X COMPLETE.

| ID | Задача | Agent | Skill | Depends | INPUT → OUTPUT → VERIFY |
|---|---|---|---|---|---|
| T12.1 | Покрытие движка: дописать недостающие unit-тесты до ≥ 85% в `engine/` | test-engineer | tdd-workflow | M5 | IN: отчёт покрытия · OUT: тесты · VERIFY: `flutter test --coverage`, engine ≥ 85% |
| T12.2 | `test/pipeline_e2e_test.dart`: блоки → IR → C++ → VM → snapshot (для всех 8 примеров) | test-engineer | webapp-testing | T5.6 | IN: примеры · OUT: 1 тест-файл · VERIFY: зелёный (S1, S2) |
| T12.3 | Golden-наборы холста/блоков/панелей стабилизированы | test-engineer | testing-patterns | M10 | IN: UI · OUT: обновлённые golden · VERIFY: `flutter test` зелёный, различия только при реальных правках |
| T12.4 | `flutter analyze` → 0 issues | frontend-specialist | lint-and-validate | M11 | IN: весь код · OUT: чистый анализ · VERIFY: команда возвращает «No issues found!» |
| T12.5 | `flutter build web --release` | frontend-specialist | deployment-procedures | T12.4 | IN: код · OUT: `build/web` · VERIFY: билд успешен, размер < 8 МБ (кроме canvas-kit) |
| T12.6 | `flutter build windows --release` | frontend-specialist | deployment-procedures | T12.4 | IN: код · OUT: `build/windows/x64/runner/Release` · VERIFY: exe запускается, Blink работает |
| T12.7 | `flutter build apk --debug` (если Android SDK доступен) | frontend-specialist | deployment-procedures | T12.4 | IN: код · OUT: apk · VERIFY: apk собран; при отсутствии SDK — отметить как N/A, уведомить |
| T12.8 | Ручной smoke на 3 платформах + чек-лист §6 | test-engineer | webapp-testing | T12.5, T12.6 | IN: сборки · OUT: отчёт · VERIFY: чек-лист §6 полностью пройден |
| T12.9 | Маркер `PHASE X COMPLETE` в PLAN.md | project-planner | plan-writing | T12.8 | IN: отчёт · OUT: финальный PLAN.md · VERIFY: маркер на месте, все `[ ]` → `[x]` |

---

## 6. Verification (Phase X) — критерии приёмки

### 6.1 Обязательные команды (все должны пройти)
```bash
cd C:\develop\arduino_lab

# 1. Статический анализ — 0 issues
flutter analyze

# 2. Тесты (unit + golden + integration) — все зелёные
flutter test

# 3. Покрытие движка
flutter test --coverage          # engine/** ≥ 85%, models/** ≥ 90%, blocks/** ≥ 85%

# 4. Сборка Web
flutter build web --release

# 5. Сборка Windows
flutter build windows --release

# 6. (опц.) Android
flutter build apk --debug
```

### 6.2 Обязательный список unit-тестов движка
| Тест-файл | Кейсы обязательные |
|---|---|
| `test/models/pin_test.dart` | логические номера D0–D13 = 0..13, A0–A5 = 14..19; поворот пина на 90/180/270 |
| `test/models/breadboard_test.dart` | `10a–10e` один net; `10f–10j` один net; `10e–10f` **разные** nets; `top+` целая шина |
| `test/models/circuit_test.dart` | удаление компонента каскадно удаляет провода; запрет дубликата провода |
| `test/engine/netlist_builder_test.dart` | 2 провода в одну точку → один net; цепочка проводов через breadboard → один net |
| `test/engine/mna_solver_test.dart` | линейная система 5×5; делитель 2×1k → 2.5 В ±1% |
| `test/engine/led_model_test.dart` | LED+R220 к 5В → 13–15 мА; LED наоборот → ~0 ток; PWM duty 128 → средний ток ≈ 50% |
| `test/engine/button_pullup_test.dart` | INPUT_PULLUP: отпущено → digitalRead HIGH; нажато (замыкание на GND) → LOW |
| `test/engine/potentiometer_test.dart` | α=0 → analogRead ≈ 0; α=0.5 → ≈ 512 ±2%; α=1 → ≈ 1023 |
| `test/engine/short_circuit_test.dart` | 5V соединён проводом с GND → `warnings` содержит shortCircuit, симуляция не падает |
| `test/engine/vm_interpreter_test.dart` | `delay(500)` → yieldedOnDelay; `while(true){}` → fault infiniteLoop + blockId; вызов user-функции и return |
| `test/engine/scheduler_test.dart` | `tone(pin,440,300)` → нота активна 300 мс виртуального времени, затем молчит |
| `test/engine/serial_test.dart` | `println(42)` → «42\n»; `available()`, `read()`, `readLine()` корректны |
| `test/blocks/sketch_printer_golden_test.dart` | ≥ 20 golden: blink, if/else, for, while, map, constrain, serial, servo, lcd, ultrasonic, dht11 |
| `test/blocks/block_ops_test.dart` | attach/detach/delete сохраняют связность; нет «осиротевших» блоков |
| `test/integration/example_run_test.dart` | все 8 примеров: 5 виртуальных секунд без fault; ожидаемые снапшоты (LED мигает, servo двигался, LCD заполнен) |
| `test/services/serialization_roundtrip_test.dart` | Project → JSON → Project семантически идентичен для всех 8 примеров; `schemaVersion` > SUPPORTED → ошибка |

### 6.3 Ручной smoke-чеклист (по платформам)
- [ ] Desktop (Windows): собрать Blink с нуля мышью → Run → LED мигает; Serial Monitor показывает «Hello» в примере Serial; сохранить в файл → открыть → схема та же.
- [ ] Web: то же + проверить localStorage-сохранение после перезагрузки страницы.
- [ ] Mobile/Android: адаптивная раскладка (табы, bottom sheets), тач-рисование провода, оборудование не «залипает» при перетаскивании.
- [ ] Ошибка: собрать `forever {}` без delay → авто-пауза ≤ 1 c + баннер с переходом к блоку.
- [ ] Ошибка: подать 5V на GND проводом → warning, приложение не падает.
- [ ] Все 8 примеров: открыть, Run, проверить ожидаемый эффект.

### 6.4 Маркер завершения (добавить в PLAN.md после прохождения)
```markdown
## ✅ PHASE X COMPLETE
- flutter analyze: ✅ 0 issues
- flutter test: ✅ all green
- Coverage: models ✅ ≥90% · engine ✅ ≥85% · blocks ✅ ≥85%
- flutter build web --release: ✅
- flutter build windows --release: ✅
- Smoke desktop/web/mobile: ✅
- Date: ____
```

---

## 7. Оценка объёма

| Каталог | Файлов | Оценка строк | Комментарий |
|---|---|---|---|
| `core/` | 5 | ~350 | константы, геометрия-хелперы, JSON-утилиты |
| `models/` (+serialization) | 24 | ~2 200 | 13 компонентов — самый «широкий» слой |
| `engine/net/` | 4 | ~450 | DSU + netlist |
| `engine/solver/` | 5 | ~900 | MNA — математическое ядро, требует тестов |
| `engine/runtime/` | 6 | ~1 300 | builtins + API Arduino |
| `engine/vm/` | 5 | ~1 000 | компилятор + интерпретатор |
| `engine/devices/` | 13 | ~1 500 | 1 device ≈ 80–150 строк |
| `engine/` (root) | 3 | ~450 | SimulationEngine + config + errors |
| `blocks/` (model+codegen) | 17 | ~1 800 | генератор + printer + IR |
| `services/` | 8 | ~800 | хранилища + репозиторий + уроки |
| `state/` | 7 | ~700 | 7 ChangeNotifier'ов |
| `examples/` | 10 | ~900 | данные примеров (схемы+блоки как Dart-код) |
| `ui/canvas/` | 7 | ~1 200 | самый сложный UI-модуль |
| `ui/components/renderers/` | 15 | ~1 600 | 13 отрисовок + диспетчер |
| `ui/blocks/` | 7 | ~1 300 | редактор блоков |
| `ui/widgets/` + `ui/screens/` + `ui/layout/` | 13 | ~1 600 | панели, адаптивность |
| `ui/theme/` + `utils/` + `app.dart`/`main.dart` | 6 | ~600 | тема, токены, вход |
| **Итого `lib/`** | **≈ 155 файлов** | **≈ 18 700 строк** | без тестов |
| **Тесты** | ≈ 22 файла | ≈ 3 500 строк | unit + golden + integration |
| **Всего** | **≈ 177 файлов** | **≈ 22 000 строк** | |

**Распределение по людям:** `backend-specialist` ≈ 55% (engine/blocks/services/examples), `frontend-specialist` ≈ 38% (ui/state/theme), `test-engineer` ≈ 7% (тесты добавляются по ходу).

**Оценка длительности (ориентировочно, при параллельной работе backend/frontend):** M0 (0.5д) → M1 (2д) → M2 (3д) ‖ M4 (2.5д) ‖ M3 (3д) → M5 (2.5д) ‖ M7 (3д) → M8 (3д) ‖ M9 (3д) ‖ M6 (2.5д) → M10 (3д) → M11 (2д) → M12 (2.5д) ≈ **18–22 рабочих дня**.

---

## 8. Риски и ответы

| # | Риск | Вероятность | Влияние | Митигация |
|---|---|---|---|---|
| R1 | MNA расходится на нелинейных (LED) | Средняя | Высокое | Fixed-point с ограничением итераций + демпфирование; тест-кейсы с допусками; fallback: упрощённая модель LED (линейная через Vf) |
| R2 | Кооперативная VM «застревает» на вложенных delay | Средняя | Высокое | YIELD всегда возвращает управление; бюджет инструкций/кадр; тест `while(true)`, `delay(10000)` |
| R3 | Рост объёма блочного редактора (самый сложный UI) | Высокая | Среднее | Начать с 5 категорий и цепочек; value-слоты/вложенность позже в M9; строгая `block_geometry`-модель |
| R4 | Производительность холста при 50+ компонентах | Средняя | Среднее | `RepaintBoundary` на компонент, кэш grid, painter-clipping, `CustomPainter.shouldRepaint` по hash снимков |
| R5 | Неточность DHT11/HC-SR04 (протоколы) | Средняя | Низкое | Имитационные устройства с детерминированным seed в тестах, физически правдоподобный шум |
| R6 | Расхождение C++ preview и семантики VM | Низкая | Среднее | Единый IR (ADR-1) — printer и compiler читают один AST; golden-тесты фиксируют текст |
| R7 | Разные API хранилищ (file vs localStorage) | Низкая | Среднее | `StorageBackend` интерфейс + fake для тестов |
| R8 | Запрет purple/violet в дизайне | Низкая | Низкое | `design_tokens.dart` — проверка хексов + чек-лист фаз верификации |

---

## 9. Definition of Done (общее)

Проект считается готовым, когда одновременно:
1. `flutter analyze` → **0 issues**.
2. `flutter test` → **все тесты зелёные**, включая 8 интеграционных тестов примеров.
3. `flutter build web --release` и `flutter build windows --release` → **успех**.
4. Все 8 примеров работают: схема → блоки → Run → видимый эффект.
5. Save/Load round-trip сохраняет схему и блоки без потерь.
6. Бесконечный цикл без `delay` → авто-пауза ≤ 1 c с переходом к проблемному блоку.
7. Чек-лист §6.3 пройден на desktop/web/mobile.
8. В PLAN.md стоит маркер `## ✅ PHASE X COMPLETE`.

---

## 10. Чек-лист прогресса

- [ ] M0 — Bootstrap (проект, зависимости, тема, структура)
- [ ] M1 — Доменные модели + JSON-схема v1
- [ ] M2 — Электрический движок (netlist + MNA + устройства)
- [ ] M3 — Arduino runtime + стековая VM
- [ ] M4 — Блочная модель + кодогенерация (IR/C++/VM)
- [ ] M5 — SimulationEngine (интеграция end-to-end)
- [ ] M6 — Сервисы + 8 встроенных примеров
- [ ] M7 — Холст схемы (drag&drop, провода, валидация)
- [ ] M8 — Отрисовка 13 компонентов + живое состояние
- [ ] M9 — Блочный редактор + read-only sketch preview
- [ ] M10 — Панели, Serial Monitor, адаптивный layout
- [ ] M11 — Экран примеров/уроков, сохранение/экспорт
- [ ] M12 — Верификация, тесты, сборки web/windows/android
- [ ] Phase X — маркер `PHASE X COMPLETE` установлен
