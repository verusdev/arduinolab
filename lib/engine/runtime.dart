/// Live state of the simulated Arduino firmware.
class ArduinoRuntime {
  bool started = false;

  /// Virtual time in microseconds.
  int timeUs = 0;

  /// logical pin -> true when configured as OUTPUT.
  final Map<int, bool> isOutput = {};

  /// logical pin -> true when INPUT_PULLUP.
  final Map<int, bool> pullup = {};

  /// logical pin -> 0/1 set by digitalWrite.
  final Map<int, double> digitalValue = {};

  /// logical pin -> 0..255 set by analogWrite.
  final Map<int, double> pwmValue = {};

  /// Serial monitor output (already formatted lines).
  final List<String> serial = [];

  /// LCD character buffer, two rows of 16 chars.
  final List<String> lcdRows = [' ' * 16, ' ' * 16];
  int lcdCol = 0;
  int lcdRow = 0;
  bool lcdInited = false;

  /// Servo angle per signal pin.
  final Map<int, double> servoAngle = {};

  /// Active tone frequency per pin (0 = silent).
  final Map<int, double> toneFreq = {};

  void reset() {
    started = false;
    timeUs = 0;
    isOutput.clear();
    pullup.clear();
    digitalValue.clear();
    pwmValue.clear();
    serial.clear();
    lcdRows[0] = ' ' * 16;
    lcdRows[1] = ' ' * 16;
    lcdCol = 0;
    lcdRow = 0;
    lcdInited = false;
    servoAngle.clear();
    toneFreq.clear();
  }

  bool isPinOutput(int pin) => isOutput[pin] == true;
  bool isPinPullup(int pin) => pullup[pin] == true;

  /// Voltage this pin tries to drive when it is an output, or null when it is
  /// high impedance.
  double? drivenVoltage(int pin) {
    if (!isPinOutput(pin)) return null;
    if (pwmValue.containsKey(pin)) return (pwmValue[pin]! / 255.0) * 5.0;
    return (digitalValue[pin] ?? 0) * 5.0;
  }

  void serialWrite(String text, {bool newline = false}) {
    if (serial.isEmpty) serial.add('');
    serial[serial.length - 1] = '${serial.last}$text';
    if (newline) serial.add('');
  }

  void lcdPrint(String text) {
    if (!lcdInited) lcdInited = true;
    var row = lcdRows[lcdRow].split('');
    var col = lcdCol;
    for (final ch in text.split('')) {
      if (col >= 16) break;
      row[col] = ch;
      col++;
    }
    lcdRows[lcdRow] = row.join();
    lcdCol = col;
  }

  void lcdSetCursor(int col, int row) {
    lcdCol = col.clamp(0, 15);
    lcdRow = row.clamp(0, 1);
  }

  void lcdClear() {
    lcdRows[0] = ' ' * 16;
    lcdRows[1] = ' ' * 16;
    lcdCol = 0;
    lcdRow = 0;
  }
}
