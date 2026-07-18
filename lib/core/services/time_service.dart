class TimeService {
  static int skipDays = 0;

  static DateTime now() {
    if (skipDays > 0) {
      return DateTime.now().add(Duration(days: skipDays));
    }
    return DateTime.now();
  }
  static String formatDueDate(int totalDays) {
    if (totalDays == 0) {
      return "Due today";
    }
    if (totalDays < 0) {
      return "Overdue by ${totalDays.abs()} days";
    }
    if (totalDays < 30) {
      return "Due in $totalDays days";
    }

    int months = totalDays ~/ 30;
    int weeks = (totalDays % 30) ~/ 7;

    if (weeks == 0) {
      return "Due in $months month${months > 1 ? 's' : ''}";
    } else {
      return "Due in $months month${months > 1 ? 's' : ''}, $weeks week${weeks > 1 ? 's' : ''}";
    }
  }
}
