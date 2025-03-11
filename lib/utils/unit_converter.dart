class UnitConverter {
  static double lbsToKg(double lbs) => lbs * 0.453592;
  static double kgToLbs(double kg) => kg / 0.453592;

  static double convert(double weight, bool isKg) {
    return isKg ? lbsToKg(weight) : kgToLbs(weight);
  }
}
