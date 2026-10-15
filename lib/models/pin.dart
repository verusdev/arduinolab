/// Electrical role of a pin, used by the solver and the UI.
enum PinKind {
  digital,
  pwm,
  analogIn,
  power,
  ground,
  passive,
  i2c,
}

/// A named connection point on a component, positioned in the component's
/// local (unrotated) space with the origin at the top-left corner.
class Pin {
  const Pin(this.id, this.label, this.dx, this.dy, this.kind, [this.logic]);

  final String id;
  final String label;
  final double dx;
  final double dy;
  final PinKind kind;

  /// Arduino logical pin number: D0..D13 -> 0..13, A0..A5 -> 14..19.
  final int? logic;

  bool get isSupply => kind == PinKind.power || kind == PinKind.ground;
  bool get isGround => kind == PinKind.ground;
  bool get isPower => kind == PinKind.power;
}

/// Helpers for translating between board labels and logical pin numbers.
class BoardPins {
  static const int analogBase = 14;
  static const Set<int> pwmPins = {3, 5, 6, 9, 10, 11};

  /// Parses a pin label such as `D13`, `A0` or `7` into a logical number.
  static int? fromLabel(String label) {
    final l = label.trim().toUpperCase();
    if (l.startsWith('D')) {
      final n = int.tryParse(l.substring(1));
      if (n != null && n >= 0 && n <= 13) return n;
    }
    if (l.startsWith('A')) {
      final n = int.tryParse(l.substring(1));
      if (n != null && n >= 0 && n <= 7) return analogBase + n;
    }
    final n = int.tryParse(l);
    if (n != null) return n;
    return null;
  }

  /// Human readable label for a logical pin number.
  static String label(int pin) {
    if (pin >= analogBase && pin <= analogBase + 5) return 'A${pin - analogBase}';
    if (pin >= 0 && pin <= 13) return 'D$pin';
    return '$pin';
  }

  static bool isPwm(int pin) => pwmPins.contains(pin);
  static bool isAnalogInput(int pin) => pin >= analogBase && pin <= analogBase + 5;
}
