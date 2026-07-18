class TimeService {
  static int skipDays = 0;

  static DateTime now() {
    if (skipDays > 0) {
      return DateTime.now().add(Duration(days: skipDays));
    }
    return DateTime.now();
  }
}
