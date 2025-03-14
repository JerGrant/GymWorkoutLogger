class UnitConverter {
  // --- Weight Conversions ---
  /// Convert pounds (lbs) to kilograms (kg).
  static double lbsToKg(double lbs) {
    return lbs * 0.45359237;
  }

  /// Convert kilograms (kg) to pounds (lbs).
  static double kgToLbs(double kg) {
    return kg / 0.45359237;
  }

  // --- Distance Conversions ---
  /// Convert miles to kilometers.
  static double milesToKm(double miles) {
    return miles * 1.60934;
  }

  /// Convert kilometers to miles.
  static double kmToMiles(double km) {
    return km / 1.60934;
  }
}
